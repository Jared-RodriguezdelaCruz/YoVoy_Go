import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/cache/tile_cache.dart';
import '../../../core/config/freshness.dart';
import '../../../core/location/location_service.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/colors.dart';
import '../../../design/tokens/spacing.dart';
import '../../../design/tokens/typography.dart';
import '../../map/application/basemap_style.dart';
import '../application/vehicle_placement.dart';

/// El trazo de un sentido sobre la ciudad, con sus camiones.
///
/// Es el mismo grabado del mapa de inicio, pero aquí solo existe una ruta y
/// va encendida: su grosor, su halo y su color completo. Se puede mover y
/// acercar; no se puede girar.
///
/// El encuadre se calcula al construirse. Para cambiar de sentido, quien lo
/// usa le da otra `key`.
class RouteMinimap extends ConsumerStatefulWidget {
  const RouteMinimap({
    required this.path,
    required this.color,
    required this.vehicles,
    super.key,
  });

  final List<LatLng> path;
  final Color color;
  final List<PlacedVehicle> vehicles;

  @override
  ConsumerState<RouteMinimap> createState() => _RouteMinimapState();
}

class _RouteMinimapState extends ConsumerState<RouteMinimap> {
  final MapController _map = MapController();

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  /// El encuadre se hace cuando el mapa ya sabe cuánto mide: con
  /// `initialCameraFit` el trazo se salía del recuadro.
  void _fit() {
    if (widget.path.length < 2) {
      return;
    }
    _map.fitCamera(
      CameraFit.coordinates(
        coordinates: widget.path,
        padding: const EdgeInsets.all(Spacing.xl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<LatLng> path = widget.path;
    final AppColors colors = context.colors;
    final vt.Style? basemap = ref
        .watch(basemapStyleProvider(Theme.of(context).brightness))
        .value;

    return Semantics(
      container: true,
      // El mapa se arrastra y se acerca, así que el árbol de semántica lo ve
      // como algo que se toca; sin nombre, el lector de pantalla anuncia un
      // control mudo. Lo que hay adentro —el trazo y los camiones— no se lee
      // en voz alta: la escalera de paradas de abajo dice lo mismo con
      // palabras.
      label: 'Mapa del recorrido de la ruta',
      child: ClipRRect(
        borderRadius: AppRadius.cardRadius,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardRadius,
            border: Border.all(
              color: colors.outline,
              width: AppSizes.outlineWidth,
            ),
          ),
          child: Stack(
            children: <Widget>[
              FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: path.firstOrNull ?? aguascalientesCenter,
                  initialZoom: 13,
                  onMapReady: _fit,
                  minZoom: 10,
                  maxZoom: 18,
                  backgroundColor: colors.surface,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: <Widget>[
                  if (basemap != null)
                    vt.VectorTileLayer(
                      theme: basemap.theme,
                      tileProviders: basemap.providers,
                      rasterSources: basemap.rasterSources,
                      sprites: basemap.sprites,
                      cachePath: tileCacheFolder,
                    ),
                  if (path.length >= 2)
                    PolylineLayer(
                      polylines: <Polyline>[
                        Polyline(
                          points: path,
                          color: widget.color,
                          strokeWidth: RouteLine.strokeWidthForZoom(13),
                          borderColor: colors.surface,
                          borderStrokeWidth: 2,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: <Marker>[
                      for (final PlacedVehicle placed in widget.vehicles)
                        Marker(
                          point: placed.vehicle.position,
                          width: 26,
                          height: 26,
                          child: _marker(colors, placed),
                        ),
                    ],
                  ),
                ],
              ),
              Positioned(
                left: Spacing.sm,
                bottom: Spacing.sm,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: AppRadius.chipRadius,
                  ),
                  child: Text(
                    '© OpenMapTiles © OpenStreetMap',
                    style: AppTypography.caption.copyWith(
                      color: colors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _marker(AppColors colors, PlacedVehicle placed) {
    final DataFreshness freshness = Freshness.classify(placed.age);
    // Sin dato, gris y sin flecha: no se inventa hacia dónde va.
    final bool known = freshness != DataFreshness.unknown;
    return ExcludeSemantics(
      child: VehicleMarker(
        color: known ? widget.color : colors.unknown,
        bearing: known ? placed.vehicle.bearing : null,
        size: 26,
        isStale: freshness == DataFreshness.stale,
      ),
    );
  }
}
