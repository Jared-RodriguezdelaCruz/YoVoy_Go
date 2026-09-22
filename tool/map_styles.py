"""Genera los estilos MapLibre del mapa de fondo: assets/map/style_{dark,light}.json.

    python tool/map_styles.py

Por qué un script y no dos JSON a mano: los dos temas tienen exactamente las
mismas capas y solo cambian los colores. Escritos a mano, tarde o temprano uno
gana una capa que el otro no tiene.

Los colores salen de lib/design/tokens/colors.dart. Si cambias un token, cambia
aquí también: test/features/map/map_style_test.dart compara los dos y falla si
se separan.

La regla del mapa (sección 7 del spec): el mapa es fondo y las rutas son el
contenido. Por eso no hay POIs, ni íconos, ni números de casa, ni nombres de
calles menores. Las únicas etiquetas son las colonias y las calles mayores.

Tiles: OpenFreeMap (esquema OpenMapTiles), sin llave. Atribución obligatoria:
"© OpenMapTiles © OpenStreetMap".
"""

import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "map"

SOURCE = "openmaptiles"

THEMES = {
    "dark": {
        "land": "#0E1016",          # surface
        "water": "#0B0F1E",         # sunken, corrido hacia el índigo
        "park": "#10141A",          # un paso arriba del suelo
        "building": "#12141C",
        "road_minor": "#191C27",
        "road_major": "#2A2E3D",    # outline
        "road_casing": "#0E1016",   # surface: en oscuro la calle no lleva borde visible
        "rail": "#1E2230",
        "label": "#A2A7BD",         # textSecondary
        "label_halo": "#0E1016",    # surface
    },
    "light": {
        "land": "#F5F6FA",          # surface
        "water": "#DADDEB",
        "park": "#E9EDEA",
        "building": "#ECEEF4",
        "road_minor": "#FFFFFF",
        "road_major": "#FFFFFF",
        "road_casing": "#E7E9F2",   # surfaceSunken
        "rail": "#D5D8E4",
        "label": "#565C70",         # textSecondary
        "label_halo": "#F5F6FA",    # surface
    },
}

MINOR = ["minor", "service"]
MAJOR = ["secondary", "tertiary"]
ARTERIAL = ["primary", "trunk", "motorway"]


def width(stops):
    """Ancho de línea interpolado por zoom, con la curva que usa MapLibre."""
    expression = ["interpolate", ["exponential", 1.4], ["zoom"]]
    for zoom, value in stops:
        expression += [zoom, value]
    return expression


def road(layer_id, classes, color, widths, minzoom, casing=None):
    layers = []
    base_filter = ["all", ["==", "$type", "LineString"], ["in", "class", *classes]]
    if casing is not None:
        layers.append({
            "id": f"{layer_id}-casing",
            "type": "line",
            "source": SOURCE,
            "source-layer": "transportation",
            "minzoom": minzoom,
            "filter": base_filter,
            "layout": {"line-cap": "round", "line-join": "round"},
            "paint": {
                "line-color": casing,
                "line-width": width([(z, w + 2) for z, w in widths]),
            },
        })
    layers.append({
        "id": layer_id,
        "type": "line",
        "source": SOURCE,
        "source-layer": "transportation",
        "minzoom": minzoom,
        "filter": base_filter,
        "layout": {"line-cap": "round", "line-join": "round"},
        "paint": {"line-color": color, "line-width": width(widths)},
    })
    return layers


def style(name, c):
    casing = c["road_casing"] if name == "light" else None
    layers = [
        {"id": "background", "type": "background",
         "paint": {"background-color": c["land"]}},
        {"id": "park", "type": "fill", "source": SOURCE, "source-layer": "park",
         "paint": {"fill-color": c["park"]}},
        {"id": "landcover-grass", "type": "fill", "source": SOURCE,
         "source-layer": "landcover", "filter": ["in", "class", "grass", "wood"],
         "paint": {"fill-color": c["park"]}},
        {"id": "water", "type": "fill", "source": SOURCE, "source-layer": "water",
         "paint": {"fill-color": c["water"]}},
        {"id": "waterway", "type": "line", "source": SOURCE,
         "source-layer": "waterway", "minzoom": 12,
         "paint": {"line-color": c["water"], "line-width": width([(12, 0.5), (18, 3)])}},
        {"id": "building", "type": "fill", "source": SOURCE,
         "source-layer": "building", "minzoom": 16,
         "paint": {"fill-color": c["building"]}},
        {"id": "rail", "type": "line", "source": SOURCE,
         "source-layer": "transportation", "minzoom": 13,
         "filter": ["in", "class", "rail", "transit"],
         "paint": {"line-color": c["rail"], "line-width": 1,
                   "line-dasharray": [3, 3]}},
    ]
    layers += road("road-minor", MINOR, c["road_minor"],
                   [(13, 0.5), (16, 4), (18, 12)], 13, casing)
    layers += road("road-major", MAJOR, c["road_major"],
                   [(10, 0.5), (14, 3), (18, 18)], 10, casing)
    layers += road("road-arterial", ARTERIAL, c["road_major"],
                   [(8, 0.8), (14, 5), (18, 24)], 8, casing)
    layers += [
        {"id": "label-road", "type": "symbol", "source": SOURCE,
         "source-layer": "transportation_name", "minzoom": 14,
         "filter": ["in", "class", *MAJOR, *ARTERIAL],
         "layout": {"symbol-placement": "line", "text-field": "{name}",
                    "text-font": ["Noto Sans Regular"], "text-size": 11,
                    "text-max-angle": 30},
         "paint": {"text-color": c["label"], "text-opacity": 0.7,
                   "text-halo-color": c["label_halo"], "text-halo-width": 1.5}},
        {"id": "label-neighbourhood", "type": "symbol", "source": SOURCE,
         "source-layer": "place", "minzoom": 13,
         "filter": ["in", "class", "suburb", "neighbourhood", "quarter"],
         "layout": {"text-field": "{name}", "text-font": ["Noto Sans Medium"],
                    "text-size": 11, "text-transform": "uppercase",
                    "text-letter-spacing": 0.08, "text-max-width": 8},
         "paint": {"text-color": c["label"], "text-opacity": 0.7,
                   "text-halo-color": c["label_halo"], "text-halo-width": 1.5}},
        {"id": "label-city", "type": "symbol", "source": SOURCE,
         "source-layer": "place", "maxzoom": 13,
         "filter": ["in", "class", "city", "town"],
         "layout": {"text-field": "{name}", "text-font": ["Noto Sans Medium"],
                    "text-size": 13},
         "paint": {"text-color": c["label"], "text-opacity": 0.7,
                   "text-halo-color": c["label_halo"], "text-halo-width": 1.5}},
    ]
    return {
        "version": 8,
        "name": f"Yo Voy Go — {name}",
        "sources": {
            SOURCE: {
                "type": "vector",
                "url": "https://tiles.openfreemap.org/planet",
                "attribution": "© OpenMapTiles © OpenStreetMap",
            },
        },
        "layers": layers,
    }


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, colors in THEMES.items():
        path = OUT / f"style_{name}.json"
        path.write_text(
            json.dumps(style(name, colors), ensure_ascii=False, indent=1) + "\n",
            encoding="utf-8",
        )
        print(f"{path.relative_to(ROOT)}: {len(style(name, colors)['layers'])} capas")


if __name__ == "__main__":
    main()
    
