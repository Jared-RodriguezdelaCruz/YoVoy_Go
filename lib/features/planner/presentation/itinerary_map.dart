import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/cache/tile_cache.dart';
import '../../../core/location/location_service.dart';
import '../../../core/models/models.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/colors.dart';
import '../../../design/tokens/route_palette.dart';
import '../../../design/tokens/spacing.dart';
import '../../../design/tokens/typography.dart';
import '../../map/application/basemap_style.dart';

/// Todo el viaje sobre la ciudad: la caminata punteada, cada camión en el
/// color de su ruta, y el origen y el destino marcados.
///
/// Es el mismo grabado del mapa de ruta (`RouteMinimap`): se mueve y se
/// acerca, no se gira, y el encuadre se hace cuando el mapa ya sabe cuánto
/// mide.
class ItineraryMap extends ConsumerStatefulWidget {
  const ItineraryMap({required this.itinerary, super.key});

  final Itinerary itinerary;

  @override
  ConsumerState<ItineraryMap> createState() => _ItineraryMapState();
}

class _ItineraryMapState extends ConsumerState<ItineraryMap> {
  final MapController _map = MapController();

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  List<LatLng> get _points => <LatLng>[
    for (final Leg leg in widget.itinerary.legs) ...leg.geometry,
  ];

  void _fit() {
    final List<LatLng> points = _points;
    if (points.length < 2) {
      return;
    }
    _map.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.all(Spacing.xl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final vt.Style? basemap = ref
        .watch(basemapStyleProvider(Theme.of(context).brightness))
        .value;
    final List<Leg> legs = widget.itinerary.legs;
    final List<LatLng> points = _points;

    return ClipRRect(
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
                initialCenter: points.firstOrNull ?? aguascalientesCenter,
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
                PolylineLayer(
                  polylines: <Polyline>[
                    for (final Leg leg in legs)
                      if (leg.geometry.length >= 2)
                        leg.isWalk || leg.route == null
                            ? Polyline(
                                points: leg.geometry,
                                color: colors.textSecondary,
                                strokeWidth: 3,
                                pattern: const StrokePattern.dotted(),
                              )
                            : Polyline(
                                points: leg.geometry,
                                color: RoutePalette.colorForRoute(
                                  routeId: leg.route!.id,
                                  gtfsColor: leg.route!.color,
                                ),
                                strokeWidth: RouteLine.strokeWidthForZoom(13),
                                borderColor: colors.surface,
                                borderStrokeWidth: 2,
                              ),
                  ],
                ),
                if (points.length >= 2)
                  CircleLayer(
                    circles: <CircleMarker>[
                      CircleMarker(
                        point: points.first,
                        radius: 7,
                        color: colors.surface,
                        borderColor: colors.brand,
                        borderStrokeWidth: 3,
                      ),
                      CircleMarker(
                        point: points.last,
                        radius: 7,
                        color: colors.brand,
                        borderColor: colors.surface,
                        borderStrokeWidth: 3,
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
                  color: colors.surface.withValues(alpha: 0.85),
                  borderRadius: AppRadius.chipRadius,
                ),
                child: Text(
                  '© OpenMapTiles © OpenStreetMap',
                  style: AppTypography.caption.copyWith(
                    color: colors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
