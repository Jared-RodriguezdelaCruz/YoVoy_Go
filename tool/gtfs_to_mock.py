#!/usr/bin/env python3
"""Convierte el GTFS oficial de Aguascalientes en los JSON de `assets/mock/`.

Se corre desde la raíz del proyecto:

    python tool/gtfs_to_mock.py

Entrada:  tool/gtfs/mex-ags-ags.zip   (ver tool/gtfs/SOURCE.md)
Salida:   assets/mock/*.json + DATASET.md + LICENSE.txt

Dos reglas que este script respeta y que conviene no romper:

1. **Determinista.** Semilla fija, llaves ordenadas, sin `set` sin ordenar en
   la salida. Correrlo dos veces seguidas no debe cambiar un solo byte.
2. **Declara lo que inventa.** Todo campo que no viene del feed queda anotado
   en `DATASET.md`. El dataset alimenta un simulador; que sea simulado no es
   excusa para que parezca oficial.

Sin dependencias: solo biblioteca estándar. Es herramienta de build, no código
de la app, y meter paquetes nuevos en `dev_dependencies` está marcado como
riesgo en el ROADMAP.
"""

from __future__ import annotations

import csv
import datetime as dt
import io
import json
import math
import os
import random
import unicodedata
import zipfile
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GTFS_ZIP = os.path.join(ROOT, "tool", "gtfs", "mex-ags-ags.zip")
OUT_DIR = os.path.join(ROOT, "assets", "mock")

# --- Constantes de conversión -------------------------------------------------

SEED = 20260920

# El feed declara vigencia 20230101–20251231: vencida. Con esas fechas
# `Calendar.runsOn(hoy)` da false y la app diría que no hay servicio nunca.
CALENDAR_START = "20260101"
CALENDAR_END = "20271231"

# Tarifa con tarjeta, consultada el 20 de septiembre de 2026. Las tarifas
# cambian; el dato vive aquí y no escondido en el código.
FARE_CARD = 10.50

# Descuento por transbordo con la Tarjeta YoVoy: el segundo abordaje paga 50 %
# y el tercero 25 %, si se hace dentro de los 90 minutos del primero. El cuarto
# y los siguientes vuelven a tarifa completa.
TRANSFER_DISCOUNTS = (1.0, 0.5, 0.25)

# Rutas que se dejan sin servicio a propósito: la pantalla "esta ruta no tiene
# servicio ahora" necesita un caso real que la dispare (§4.2 del spec).
INACTIVE_ROUTES = ("R_50B", "R_52")

# Velocidad a pie de los tramos de caminata de los itinerarios, m/s.
WALK_SPEED = 1.2

# Siglas que el feed escribe en Title Case y quedan mal en pantalla.
ACRONYMS = {
    "xxi": "XXI",
    "uaa": "UAA",
    "uta": "UTA",
    "utma": "UTMA",
    "upa": "UPA",
    "unitec": "UNITEC",
    "cbtis": "CBTIS",
    "imss": "IMSS",
    "issste": "ISSSTE",
    "dif": "DIF",
    "isssspea": "ISSSSPEA",
    "cch": "CCH",
    "ii": "II",
    "iii": "III",
    "iv": "IV",
}

# Conectores que en español van en minúscula salvo al inicio.
CONNECTORS = {"de", "del", "la", "las", "los", "el", "y", "e", "en", "a", "al"}


# --- Utilidades ---------------------------------------------------------------


def read_table(zf: zipfile.ZipFile, name: str) -> list[dict[str, str]]:
    """Lee una tabla del zip y recorta los espacios de cada celda.

    No es cosmético: el feed trae `" P684"` con un espacio adelante en dos
    filas de `stop_times.txt`, y ese id no empata con ninguna parada. Sin el
    recorte, dos viajes de la R-30 quedan con una parada colgando.
    """
    with zf.open(name) as raw:
        rows = list(csv.DictReader(io.TextIOWrapper(raw, "utf-8-sig")))
    return [
        {
            key.strip(): (value.strip() if isinstance(value, str) else value)
            for key, value in row.items()
        }
        for row in rows
    ]


def tidy(text: str) -> str:
    """Normaliza un nombre del feed: siglas en mayúsculas, conectores abajo.

    `Siglo Xxi` -> `Siglo XXI`, `Centro (Calle Rivero Y Gutiérrez)` ->
    `Centro (Calle Rivero y Gutiérrez)`. Es cosmético y está declarado como
    derivado en DATASET.md: el nombre original del feed no se pierde, se
    recupera corriendo el script otra vez.
    """
    out: list[str] = []
    for index, word in enumerate(text.split()):
        prefix = ""
        core = word
        suffix = ""
        while core and not core[0].isalnum():
            prefix += core[0]
            core = core[1:]
        while core and not core[-1].isalnum():
            suffix = core[-1] + suffix
            core = core[:-1]
        key = strip_accents(core).lower()
        if key in ACRONYMS:
            core = ACRONYMS[key]
        elif index > 0 and not prefix and key in CONNECTORS:
            core = key
        out.append(prefix + core + suffix)
    return " ".join(out)


def strip_accents(text: str) -> str:
    return "".join(
        ch
        for ch in unicodedata.normalize("NFD", text)
        if unicodedata.category(ch) != "Mn"
    )


def meters(a: tuple[float, float], b: tuple[float, float]) -> float:
    """Distancia plana en metros. A escala de ciudad el error es despreciable."""
    lat_mid = math.radians((a[0] + b[0]) / 2)
    x = (b[1] - a[1]) * math.cos(lat_mid) * 111_320
    y = (b[0] - a[0]) * 110_574
    return math.hypot(x, y)


def epoch(moment: dt.datetime) -> int:
    return int(moment.replace(tzinfo=dt.timezone.utc).timestamp())


def gtfs_seconds(value: str) -> int:
    hours, minutes, seconds = (int(part) for part in value.split(":"))
    return hours * 3600 + minutes * 60 + seconds


def write_json(name: str, payload: object, *, compact: bool = False) -> None:
    path = os.path.join(OUT_DIR, name)
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        if compact:
            json.dump(payload, handle, ensure_ascii=False, separators=(",", ":"))
        else:
            json.dump(payload, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    print(f"  {name:22} {os.path.getsize(path):>9,} bytes")


def write_text(name: str, text: str) -> None:
    path = os.path.join(OUT_DIR, name)
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)
    print(f"  {name:22} {os.path.getsize(path):>9,} bytes")


# --- Conversión ---------------------------------------------------------------


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    rng = random.Random(SEED)

    with zipfile.ZipFile(GTFS_ZIP) as zf:
        feed = {
            name: read_table(zf, f"{name}.txt")
            for name in (
                "agency",
                "routes",
                "trips",
                "stops",
                "stop_times",
                "shapes",
                "calendar",
                "frequencies",
                "feed_info",
            )
        }

    print(f"leído {os.path.basename(GTFS_ZIP)}:")
    for name, rows in feed.items():
        print(f"  {name:22} {len(rows):>9,} filas")
    print("escrito en assets/mock/:")

    # -- agency --------------------------------------------------------------
    agencies = [
        {
            "agency_id": row["agency_id"],
            "agency_name": row["agency_name"],
            "agency_url": row["agency_url"],
            "agency_timezone": row["agency_timezone"],
        }
        for row in feed["agency"]
    ]
    write_json("agency.json", agencies)

    # -- índices de trabajo ---------------------------------------------------
    trips_by_route: dict[str, list[dict[str, str]]] = defaultdict(list)
    for row in feed["trips"]:
        trips_by_route[row["route_id"]].append(row)

    times_by_trip: dict[str, list[dict[str, str]]] = defaultdict(list)
    for row in feed["stop_times"]:
        times_by_trip[row["trip_id"]].append(row)
    for rows in times_by_trip.values():
        rows.sort(key=lambda row: int(row["stop_sequence"]))

    shape_points: dict[str, list[tuple[float, float]]] = defaultdict(list)
    for row in feed["shapes"]:
        shape_points[row["shape_id"]].append(
            (
                int(row["shape_pt_sequence"]),
                round(float(row["shape_pt_lat"]), 5),
                round(float(row["shape_pt_lon"]), 5),
            )
        )
    shapes: dict[str, list[tuple[float, float]]] = {}
    for shape_id, rows in shape_points.items():
        rows.sort(key=lambda item: item[0])
        shapes[shape_id] = [(lat, lon) for _, lat, lon in rows]

    headway_by_trip = {
        row["trip_id"]: int(row["headway_secs"]) for row in feed["frequencies"]
    }

    # -- routes ---------------------------------------------------------------
    # `route_long_name` en el feed es "R-01": no dice nada. Se deriva de las
    # terminales del viaje de ida, que es lo que la gente reconoce.
    routes = []
    for row in sorted(feed["routes"], key=lambda r: r["route_id"]):
        route_id = row["route_id"]
        long_name = tidy(row["route_long_name"])
        for trip in trips_by_route.get(route_id, []):
            label = trip.get("trip_short_name", "").strip()
            if " - " in label:
                origin, destination = (tidy(part) for part in label.split(" - ", 1))
                long_name = f"{origin} — {destination}"
                break
            if label:
                long_name = tidy(label)
        routes.append(
            {
                "route_id": route_id,
                "route_short_name": row["route_short_name"],
                "route_long_name": long_name,
                "route_type": int(row["route_type"]),
                "route_color": row["route_color"] or None,
                "route_text_color": row["route_text_color"] or None,
            }
        )
    write_json("routes.json", routes)

    # -- stops ----------------------------------------------------------------
    # El feed no trae `stop_code` ni `wheelchair_boarding`. Los dos se simulan
    # con semilla fija y quedan declarados en DATASET.md.
    stops = []
    for row in sorted(feed["stops"], key=lambda r: r["stop_id"]):
        digits = "".join(ch for ch in row["stop_id"] if ch.isdigit())
        letters = "".join(ch for ch in row["stop_id"] if ch.isalpha()).upper()
        roll = rng.random()
        if roll < 0.35:
            boarding = 1  # accesible
        elif roll < 0.45:
            boarding = 2  # no accesible
        else:
            boarding = 0  # sin verificar, que es el default del estándar
        stops.append(
            {
                "stop_id": row["stop_id"],
                "stop_name": tidy(row["stop_name"]),
                "stop_lat": round(float(row["stop_lat"]), 6),
                "stop_lon": round(float(row["stop_lon"]), 6),
                "stop_code": f"{letters or 'P'}-{digits.zfill(3)}",
                "wheelchair_boarding": boarding,
            }
        )
    write_json("stops.json", stops)
    stops_by_id = {stop["stop_id"]: stop for stop in stops}

    # -- shapes ---------------------------------------------------------------
    write_json(
        "shapes.json",
        [
            {
                "shape_id": shape_id,
                "points": [{"lat": lat, "lon": lon} for lat, lon in shapes[shape_id]],
            }
            for shape_id in sorted(shapes)
        ],
        compact=True,
    )

    # -- trips ----------------------------------------------------------------
    # El feed no trae `trip_headsign`. `trip_short_name` es "Origen - Destino",
    # así que el letrero del camión es la segunda mitad.
    trips = []
    for row in sorted(feed["trips"], key=lambda r: r["trip_id"]):
        label = row.get("trip_short_name", "").strip()
        headsign = tidy(label.split(" - ", 1)[1] if " - " in label else label)
        trips.append(
            {
                "trip_id": row["trip_id"],
                "route_id": row["route_id"],
                "service_id": row["service_id"],
                "trip_headsign": headsign or row["route_id"],
                "direction_id": int(row["direction_id"]),
                "shape_id": row["shape_id"] or None,
            }
        )
    write_json("trips.json", trips)

    # -- stop_times -----------------------------------------------------------
    stop_times = [
        {
            "trip_id": row["trip_id"],
            "stop_id": row["stop_id"],
            "stop_sequence": int(row["stop_sequence"]),
            "arrival_time": row["arrival_time"],
            "departure_time": row["departure_time"],
        }
        for trip_id in sorted(times_by_trip)
        for row in times_by_trip[trip_id]
    ]
    write_json("stop_times.json", stop_times, compact=True)

    # -- calendar -------------------------------------------------------------
    days_order = (
        "monday",
        "tuesday",
        "wednesday",
        "thursday",
        "friday",
        "saturday",
        "sunday",
    )
    calendars = [
        {
            "service_id": row["service_id"],
            "days": [day for day in days_order if row[day] == "1"],
            "start_date": CALENDAR_START,
            "end_date": CALENDAR_END,
        }
        for row in sorted(feed["calendar"], key=lambda r: r["service_id"])
    ]
    write_json("calendar.json", calendars)

    # -- frequencies ----------------------------------------------------------
    frequencies = [
        {
            "trip_id": row["trip_id"],
            "start_time": row["start_time"],
            "end_time": row["end_time"],
            "headway_secs": int(row["headway_secs"]),
            "exact_times": row.get("exact_times", "0") == "1",
        }
        for row in sorted(feed["frequencies"], key=lambda r: r["trip_id"])
    ]
    write_json("frequencies.json", frequencies)

    # -- service.json ---------------------------------------------------------
    # La flota la construye el simulador (fase 4b), pero el reparto se decide
    # aquí: vehículos = tiempo de vuelta ÷ headway. Es la flota que esa
    # frecuencia exige, no un número redondo.
    service = []
    for route in routes:
        route_id = route["route_id"]
        route_trips = [
            trip
            for trip in trips_by_route.get(route_id, [])
            if trip["service_id"] == "ES"
        ]
        cycle = 0
        headway = 0
        for trip in route_trips:
            rows = times_by_trip.get(trip["trip_id"], [])
            if len(rows) < 2:
                continue
            cycle += gtfs_seconds(rows[-1]["arrival_time"]) - gtfs_seconds(
                rows[0]["departure_time"]
            )
            headway = max(headway, headway_by_trip.get(trip["trip_id"], 0))
        active = route_id not in INACTIVE_ROUTES
        vehicles = 0
        if active and headway:
            vehicles = max(1, math.ceil(cycle / headway))
        service.append(
            {
                "route_id": route_id,
                "active": active,
                "vehicles": vehicles,
                "cycle_seconds": cycle,
                "headway_seconds": headway,
            }
        )
    write_json(
        "service.json",
        {
            "note": (
                "Reparto de la flota simulada. vehicles = ceil(cycle_seconds / "
                "headway_seconds). Las rutas con active=false no tienen ningún "
                "vehículo a propósito: la pantalla 'esta ruta no tiene servicio "
                "ahora' necesita un caso que la dispare."
            ),
            "routes": service,
        },
    )

    # -- alerts.json ----------------------------------------------------------
    # Escritas a mano contra ids reales del feed. Dos, como pide el spec: una
    # vigente y una vencida, para que se pueda probar que la vencida no se
    # pinta.
    # La parada de la alerta de feria se busca por nombre: si el feed cambia
    # de ids, la alerta sigue apuntando a algo que existe.
    feria_stop = next(
        (stop["stop_id"] for stop in stops if "San Marcos" in stop["stop_name"]),
        stops[0]["stop_id"],
    )
    alerts = [
        {
            "id": "alerta_obra_lopez_mateos",
            "header": "Desvío en López Mateos por obra",
            "description": (
                "La ruta no entra a López Mateos entre Aguascalientes y Chávez "
                "hasta nuevo aviso. Toma la parada de Héroes."
            ),
            "affected_route_ids": ["R_03", "R_09"],
            "affected_stop_ids": [],
            "cause": "CONSTRUCTION",
            "effect": "DETOUR",
            "active_period": {
                "start": epoch(dt.datetime(2026, 9, 1, 6, 0)),
                "end": None,
            },
        },
        {
            "id": "alerta_parada_movida_san_marcos",
            "header": "Parada movida por la Feria de San Marcos",
            "description": (
                "Durante la feria la parada se recorrió una cuadra al norte. "
                "Ya volvió a su lugar."
            ),
            "affected_route_ids": ["R_37"],
            "affected_stop_ids": [feria_stop],
            "cause": "HOLIDAY",
            "effect": "STOP_MOVED",
            "active_period": {
                "start": epoch(dt.datetime(2026, 4, 18, 6, 0)),
                "end": epoch(dt.datetime(2026, 5, 10, 23, 59)),
            },
        },
    ]
    write_json("alerts.json", alerts)

    # -- itineraries.json -----------------------------------------------------
    write_json("itineraries.json", build_itineraries(routes, trips, times_by_trip, shapes, stops_by_id))

    # -- documentación --------------------------------------------------------
    write_text("LICENSE.txt", LICENSE_TEXT)
    write_text(
        "DATASET.md",
        dataset_doc(
            counts={
                "rutas": len(routes),
                "paradas": len(stops),
                "trazos": len(shapes),
                "puntos de trazo": sum(len(points) for points in shapes.values()),
                "viajes": len(trips),
                "stop_times": len(stop_times),
                "frecuencias": len(frequencies),
                "servicios": len(calendars),
                "alertas": len(alerts),
            },
            inactive=INACTIVE_ROUTES,
        ),
    )


# --- Itinerarios precocinados -------------------------------------------------


def build_itineraries(routes, trips, times_by_trip, shapes, stops_by_id) -> dict:
    """Los cuatro pares origen–destino de la sección 4.3 del spec.

    Se construyen contra el feed real: viaje directo, con un transbordo, con
    dos transbordos y **el caso sin resultados**, que existe como dato y no
    como ausencia de dato para que se pueda probar.
    """
    routes_by_id = {route["route_id"]: route for route in routes}
    trip_by_id = {trip["trip_id"]: trip for trip in trips}

    # Solo los viajes de ida entre semana: es el conjunto que un planificador
    # simple usaría, y mantiene la búsqueda determinista.
    outbound = {}
    for trip in trips:
        if trip["service_id"] == "ES" and trip["direction_id"] == 0:
            outbound.setdefault(trip["route_id"], trip["trip_id"])

    routes_of_stop = defaultdict(set)
    for route_id, trip_id in outbound.items():
        for row in times_by_trip.get(trip_id, []):
            routes_of_stop[row["stop_id"]].add(route_id)

    def sequence(trip_id):
        return times_by_trip.get(trip_id, [])

    def position_of(trip_id, stop_id):
        for index, row in enumerate(sequence(trip_id)):
            if row["stop_id"] == stop_id:
                return index
        return None

    def slice_shape(trip_id, from_stop, to_stop):
        shape_id = trip_by_id[trip_id]["shape_id"]
        points = shapes.get(shape_id, [])
        if not points:
            return []

        def nearest(stop):
            target = (stop["stop_lat"], stop["stop_lon"])
            return min(range(len(points)), key=lambda i: meters(points[i], target))

        start, end = nearest(from_stop), nearest(to_stop)
        if start > end:
            start, end = end, start
        return [{"lat": lat, "lon": lon} for lat, lon in points[start : end + 1]]

    def bus_leg(trip_id, from_index, to_index):
        rows = sequence(trip_id)
        from_stop = stops_by_id[rows[from_index]["stop_id"]]
        to_stop = stops_by_id[rows[to_index]["stop_id"]]
        duration = gtfs_seconds(rows[to_index]["arrival_time"]) - gtfs_seconds(
            rows[from_index]["departure_time"]
        )
        return {
            "type": "bus",
            "from": from_stop["stop_name"],
            "to": to_stop["stop_name"],
            "duration": duration,
            "route": routes_by_id[trip_by_id[trip_id]["route_id"]],
            "from_stop_id": from_stop["stop_id"],
            "to_stop_id": to_stop["stop_id"],
            "geometry": slice_shape(trip_id, from_stop, to_stop),
        }

    def walk_leg(origin, origin_name, stop, *, to_stop):
        point = (stop["stop_lat"], stop["stop_lon"])
        distance = meters(origin, point)
        geometry = [
            {"lat": origin[0], "lon": origin[1]},
            {"lat": point[0], "lon": point[1]},
        ]
        return {
            "type": "walk",
            "from": origin_name if to_stop else stop["stop_name"],
            "to": stop["stop_name"] if to_stop else origin_name,
            "duration": max(60, round(distance / WALK_SPEED)),
            "from_stop_id": None if to_stop else stop["stop_id"],
            "to_stop_id": stop["stop_id"] if to_stop else None,
            "geometry": geometry if to_stop else list(reversed(geometry)),
        }, distance

    def chain(start_route, transfers):
        """Encadena viajes que comparten parada. Determinista por orden."""
        trip_id = outbound.get(start_route)
        if trip_id is None:
            return None
        hops = []
        board = 2
        used = {start_route}
        for _ in range(transfers):
            found = None
            for index in range(board + 10, len(sequence(trip_id))):
                stop_id = sequence(trip_id)[index]["stop_id"]
                for candidate in sorted(routes_of_stop[stop_id] - used):
                    next_trip = outbound[candidate]
                    position = position_of(next_trip, stop_id)
                    if position is None or len(sequence(next_trip)) - position < 12:
                        continue
                    found = (index, candidate, next_trip, position)
                    break
                if found:
                    break
            if not found:
                return None
            index, candidate, next_trip, position = found
            hops.append((trip_id, board, index))
            used.add(candidate)
            trip_id, board = next_trip, position
        last = min(board + 14, len(sequence(trip_id)) - 1)
        hops.append((trip_id, board, last))
        return hops

    def fare_for(boardings: int) -> float:
        total = 0.0
        for index in range(boardings):
            share = (
                TRANSFER_DISCOUNTS[index]
                if index < len(TRANSFER_DISCOUNTS)
                else 1.0
            )
            total += FARE_CARD * share
        return round(total, 2)

    def itinerary_from(hops, spread):
        first_stop = stops_by_id[sequence(hops[0][0])[hops[0][1]]["stop_id"]]
        last_stop = stops_by_id[sequence(hops[-1][0])[hops[-1][2]]["stop_id"]]
        # El origen y el destino no caen encima de la parada: la gente camina.
        origin = (
            round(first_stop["stop_lat"] + 0.0012 + 0.0009 * spread, 6),
            round(first_stop["stop_lon"] - 0.0006 - 0.0007 * spread, 6),
        )
        target = (
            round(last_stop["stop_lat"] - 0.0009 - 0.0005 * spread, 6),
            round(last_stop["stop_lon"] + 0.0004 + 0.0008 * spread, 6),
        )

        legs = []
        first_walk, walked = walk_leg(origin, "Tu ubicación", first_stop, to_stop=True)
        legs.append(first_walk)
        for trip_id, from_index, to_index in hops:
            legs.append(bus_leg(trip_id, from_index, to_index))
        last_walk, more = walk_leg(target, "Tu destino", last_stop, to_stop=False)
        legs.append(last_walk)
        walked += more

        return origin, target, {
            "legs": legs,
            "total_duration": sum(leg["duration"] for leg in legs),
            "walking_distance": round(walked, 1),
            "transfer_count": len(hops) - 1,
            "fare": fare_for(len(hops)),
        }

    pairs = []
    plans = (
        ("directo", "R_09", 0),
        ("un_transbordo", "R_02", 1),
        ("dos_transbordos", "R_07", 2),
    )
    for spread, (name, route_id, transfers) in enumerate(plans):
        hops = chain(route_id, transfers)
        if hops is None:
            raise SystemExit(f"no se pudo armar el itinerario '{name}' desde {route_id}")
        origin, target, itinerary = itinerary_from(hops, spread)
        pairs.append(
            {
                "id": name,
                "from": {"lat": origin[0], "lon": origin[1]},
                "to": {"lat": target[0], "lon": target[1]},
                "match_radius_meters": 500,
                "itineraries": [itinerary],
            }
        )

    # El cuarto par: un punto al que no llega nada. La pantalla de "no encontré
    # ruta" es tan importante como la de resultados (§4.3).
    pairs.append(
        {
            "id": "sin_resultados",
            "from": {"lat": 21.8605, "lon": -102.3350},
            "to": {"lat": 21.7420, "lon": -102.5180},
            "match_radius_meters": 2000,
            "itineraries": [],
        }
    )

    return {
        "note": (
            "Pares origen–destino precocinados. planTrip hace matching por "
            "proximidad contra 'from' y 'to' dentro de match_radius_meters; si "
            "el origen o el destino no cae cerca de ninguno, devuelve lista "
            "vacía."
        ),
        "pairs": pairs,
    }


# --- Documentación generada ---------------------------------------------------


LICENSE_TEXT = """Datos de transporte de Aguascalientes
=====================================

Los archivos JSON de este directorio son una obra derivada del GTFS estático
del transporte público concesionado de Aguascalientes.

Fuente original
    Gobierno del Estado de Aguascalientes
    Coordinación General de Movilidad (CMOV)
    https://www.aguascalientes.gob.mx/cmov

Distribuido por
    Hub de Datos de Transporte Público — Codeando México
    https://hdtp.codeandomexico.org/datos/mex-ags-ags

Licencia de la fuente y de esta obra derivada
    Creative Commons Atribución-CompartirIgual 4.0 Internacional (CC BY-SA 4.0)
    https://creativecommons.org/licenses/by-sa/4.0/deed.es

La licencia CompartirIgual alcanza a estos datos, no al código de la app.

Atribución que debe aparecer en la app
    Datos de transporte: Gobierno del Estado de Aguascalientes (CMOV), vía el
    Hub de Datos de Transporte Público de Codeando México. CC BY-SA 4.0.

Yo Voy Go es una app independiente. No tiene afiliación con la Coordinación
General de Movilidad ni con el operador del sistema, y no integra la Tarjeta
YoVoy. Atribuir una fuente de datos no es afiliarse a ella.
"""


def dataset_doc(counts: dict[str, int], inactive: tuple[str, ...]) -> str:
    rows = "\n".join(f"| {name} | {value:,} |" for name, value in counts.items())
    return f"""# Procedencia del dataset

Generado por `tool/gtfs_to_mock.py` a partir de `tool/gtfs/mex-ags-ags.zip`.
**No se edita a mano:** cualquier cambio se hace en el script y se regenera.

Licencia y atribución: [`LICENSE.txt`](LICENSE.txt). Origen y versión del feed:
[`../../tool/gtfs/SOURCE.md`](../../tool/gtfs/SOURCE.md).

## Qué hay

| | |
|---|---|
{rows}

## Qué es real y qué no

Esto alimenta un simulador. Que sea simulado no es excusa para que parezca
oficial, así que cada campo dice de dónde viene.

### Del feed, sin tocar

`route_id` · `route_short_name` · `route_color` · `route_text_color` ·
`route_type` · `stop_id` · `stop_lat` · `stop_lon` · `trip_id` · `route_id` ·
`service_id` · `direction_id` · `shape_id` · todos los puntos de `shapes.json` ·
todo `stop_times.json` · todo `frequencies.json` · los días de `calendar.json` ·
la agencia.

Las coordenadas de los trazos se redondean a cinco decimales (~1 m) y las de
las paradas a seis. Nada más.

### Derivado del feed

| Campo | Cómo |
|---|---|
| `route_long_name` | El feed dice `R-01`, que no informa. Se arma con las terminales del viaje de ida: `Vicente Guerrero — Margaritas` |
| `trip_headsign` | El feed no lo trae. `trip_short_name` es `Origen - Destino`; el letrero es el destino |
| ids con espacios | El feed trae `" P684"` con un espacio adelante en dos filas de `stop_times.txt`: quedaría una parada colgando en dos viajes de la R-30. Se recorta cada celda al leerla |
| `stop_name` | El del feed, con las siglas en mayúsculas (`Siglo Xxi` → `Siglo XXI`) y los conectores en minúscula (`Rivero Y Gutiérrez` → `Rivero y Gutiérrez`) |
| `service.json` | `vehicles = ceil(cycle_seconds / headway_seconds)`, con el ciclo sacado de los `stop_times` y el headway de `frequencies.txt` |

### Inventado

| Campo | Cómo | Por qué |
|---|---|---|
| `stop_code` | `P-001`, derivado del `stop_id` | El poste real tiene código y §8.2 del spec lo muestra; el feed no lo publica |
| `wheelchair_boarding` | Semilla fija: ~35 % accesible, ~10 % no accesible, el resto sin verificar | Sin esto el filtro de accesibilidad no tiene nada que filtrar. `unknown` queda como mayoría, que es el estado real del mundo |
| `alerts.json` | Dos alertas escritas a mano sobre rutas reales | GTFS-Realtime no viene en el feed estático |
| `itineraries.json` | Cuatro pares armados sobre viajes y trazos reales | La v1 no tiene motor de ruteo (§4.3) |
| Vigencia de `calendar.json` | Abierta a {CALENDAR_START}–{CALENDAR_END} | El feed declara 20230101–20251231, vencida. Con las fechas originales `Calendar.runsOn(hoy)` da `false` siempre y la app diría que no hay servicio nunca |
| `fare` | {FARE_CARD:.2f} el primer abordaje, 50 % el segundo y 25 % el tercero, que es el descuento por transbordo de la Tarjeta YoVoy dentro de 90 minutos. Consultado el 20 de septiembre de 2026 | El feed no trae `fare_attributes.txt` |

### Rutas sin servicio a propósito

{", ".join(f"`{route}`" for route in inactive)} quedan con `active: false` en
`service.json` y sin ningún vehículo. La pantalla «esta ruta no tiene servicio
ahora» necesita un caso real que la dispare (§4.2 del spec), y con el feed
completo tiene que ser la excepción, no la norma.

## Regenerar

```bash
python tool/gtfs_to_mock.py
flutter test test/core/models/mock_dataset_test.dart
```

El script es determinista: dos corridas seguidas producen el mismo byte.
"""


if __name__ == "__main__":
    main()
