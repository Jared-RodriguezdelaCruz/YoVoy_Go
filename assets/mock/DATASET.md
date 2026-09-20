# Procedencia del dataset

Generado por `tool/gtfs_to_mock.py` a partir de `tool/gtfs/mex-ags-ags.zip`.
**No se edita a mano:** cualquier cambio se hace en el script y se regenera.

Licencia y atribución: [`LICENSE.txt`](LICENSE.txt). Origen y versión del feed:
[`../../tool/gtfs/SOURCE.md`](../../tool/gtfs/SOURCE.md).

## Qué hay

| | |
|---|---|
| rutas | 48 |
| paradas | 1,507 |
| trazos | 92 |
| puntos de trazo | 41,252 |
| viajes | 184 |
| stop_times | 8,388 |
| frecuencias | 184 |
| servicios | 2 |
| alertas | 2 |

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
| Vigencia de `calendar.json` | Abierta a 20260101–20271231 | El feed declara 20230101–20251231, vencida. Con las fechas originales `Calendar.runsOn(hoy)` da `false` siempre y la app diría que no hay servicio nunca |
| `fare` | 10.50 el primer abordaje, 50 % el segundo y 25 % el tercero, que es el descuento por transbordo de la Tarjeta YoVoy dentro de 90 minutos. Consultado el 20 de septiembre de 2026 | El feed no trae `fare_attributes.txt` |

### Rutas sin servicio a propósito

`R_50B`, `R_52` quedan con `active: false` en
`service.json` y sin ningún vehículo. La pantalla «esta ruta no tiene servicio
ahora» necesita un caso real que la dispare (§4.2 del spec), y con el feed
completo tiene que ser la excepción, no la norma.

## Regenerar

```bash
python tool/gtfs_to_mock.py
flutter test test/core/models/mock_dataset_test.dart
```

El script es determinista: dos corridas seguidas producen el mismo byte.
