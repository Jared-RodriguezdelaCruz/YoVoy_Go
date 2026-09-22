import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/routes.dart';
import '../../../core/data/transit_network.dart';
import '../../../core/location/location_service.dart';
import '../../../core/models/models.dart';
import '../../../design/tokens/colors.dart';
import '../../../design/tokens/motion.dart';
import '../../../design/tokens/spacing.dart';
import '../../../design/tokens/typography.dart';
import '../../planner/application/trip_request.dart';
import '../application/basemap_style.dart';
import '../application/map_providers.dart';
import '../application/search_index.dart';
import 'accessible_only_chip.dart';
import 'global_freshness_chip.dart';
import 'layers/route_network_layer.dart';
import 'layers/transit_markers_layer.dart';
import 'map_hit_test.dart';
import 'map_search_bar.dart';
import 'map_sheet.dart';

/// El mapa: la pantalla de inicio (sección 8.1 del spec).
///
/// Mapa a pantalla completa, hoja arrastrable en tres alturas, búsqueda
/// flotante, chip de frescura global y botón de ubicación. Las capas, de abajo
/// hacia arriba: fondo vectorial → red de rutas → camiones y paradas.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  /// Zoom al que se acerca el mapa al ubicar al usuario o elegir una parada.
  static const double streetZoom = 16;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _map = MapController();
  final DraggableScrollableController _sheet = DraggableScrollableController();
  final MapHitRegistry _hits = MapHitRegistry();
  double _collapsedSize = 0.15;

  @override
  void dispose() {
    _map.dispose();
    _sheet.dispose();
    super.dispose();
  }

  void _moveSheet(double size) {
    if (!_sheet.isAttached) {
      return;
    }
    _sheet.animateTo(
      size,
      duration: AppMotion.resolve(context, AppMotion.standard),
      curve: AppMotion.curve,
    );
  }

  void _onTap(TapPosition tap, LatLng point) {
    final Offset? at = tap.relative;
    final MapHit? hit = at == null ? null : _hits.hitAt(at);
    final MapSelectionState selection = ref.read(
      mapSelectionStateProvider.notifier,
    );
    switch (hit) {
      case VehicleHit(:final String vehicleId, :final String routeId):
        selection.select(
          VehicleSelected(vehicleId: vehicleId, routeId: routeId),
        );
        _moveSheet(SheetStops.half);
      case StopHit(:final String stopId):
        selection.select(StopSelected(stopId));
        _moveSheet(SheetStops.half);
      case ClusterHit(:final LatLng center):
        _map.move(center, _map.camera.zoom + 2);
      case null:
        // Tocar el mapa vacío devuelve la pantalla a su inicio.
        selection.clear();
        _moveSheet(_collapsedSize);
    }
  }

  void _onSearchPick(SearchHit hit) {
    final MapSelectionState selection = ref.read(
      mapSelectionStateProvider.notifier,
    );
    final TransitNetwork? network = ref.read(transitNetworkProvider).value;

    switch (hit.kind) {
      case SearchKind.stop:
        selection.select(StopSelected(hit.id));
        final Stop? stop = network?.stop(hit.id);
        if (stop != null) {
          _map.move(stop.position, MapScreen.streetZoom);
        }
        _moveSheet(SheetStops.half);
      case SearchKind.route:
      case SearchKind.destination:
        final String routeId = hit.routeIds.isEmpty
            ? hit.id
            : hit.routeIds.first;
        selection.select(RouteSelected(routeId));
        _fitRoute(network, routeId);
        _moveSheet(SheetStops.half);
    }
  }

  void _fitRoute(TransitNetwork? network, String routeId) {
    final List<LatLng> points = <LatLng>[
      for (final Shape shape in network?.shapesForRoute(routeId) ?? <Shape>[])
        ...shape.points,
    ];
    if (points.length < 2) {
      return;
    }
    final double sheetHeight =
        MediaQuery.sizeOf(context).height * SheetStops.half;
    _map.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        // Abajo queda la hoja a media altura: la ruta se encuadra en lo que
        // sí se ve.
        padding: EdgeInsets.fromLTRB(32, 140, 32, sheetHeight + 24),
      ),
    );
  }

  Future<void> _locate() async {
    ref.invalidate(userLocationProvider);
    final UserLocation location = await ref.read(userLocationProvider.future);
    if (!mounted) {
      return;
    }
    _map.move(location.position, MapScreen.streetZoom);

    final LocationIssue? issue = location.issue;
    if (issue == null) {
      return;
    }
    // El botón nunca falla en silencio: dice por qué y qué hacer.
    final String message = switch (issue) {
      LocationIssue.serviceDisabled => 'La ubicación del teléfono está apagada. El mapa se queda en el centro.',
      LocationIssue.denied =>
        'Sin permiso de ubicación. El mapa se queda en el centro.',
      LocationIssue.deniedForever =>
        'La ubicación está bloqueada para Yo Voy Go. Actívala en los ajustes.',
      LocationIssue.unavailable =>
        'El teléfono no respondió con tu ubicación. Vuelve a intentarlo.',
    };
    final bool fixable =
        issue == LocationIssue.serviceDisabled ||
        issue == LocationIssue.deniedForever;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: fixable
              ? SnackBarAction(
                  label: 'Abrir ajustes',
                  onPressed: () =>
                      ref.read(locationServiceProvider).openSettings(issue),
                )
              : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final Brightness brightness = Theme.of(context).brightness;
    final vt.Style? basemap = ref.watch(basemapStyleProvider(brightness)).value;
    final UserLocation? location = ref.watch(userLocationProvider).value;

    // Elegir algo en otra parte (la hoja, la búsqueda) también lo muestra.
    ref.listen(mapSelectionStateProvider, (
      MapSelection? previous,
      MapSelection next,
    ) {
      if (next is NothingSelected && previous is! NothingSelected) {
        _moveSheet(_collapsedSize);
      }
    });

    return Scaffold(
      backgroundColor: colors.surface,
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          _collapsedSize = SheetStops.collapsedFor(constraints.maxHeight);

          return Stack(
            children: <Widget>[
              FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: location?.position ?? aguascalientesCenter,
                  initialZoom: 14,
                  minZoom: 10,
                  maxZoom: 18,
                  backgroundColor: colors.surface,
                  onTap: _onTap,
                  // Sin rotación: un mapa de transporte girado desorienta, y
                  // la capa de marcadores asume norte arriba.
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
                    ),
                  const RouteNetworkLayer(),
                  if (location != null && !location.isFallback)
                    CircleLayer(
                      circles: <CircleMarker>[
                        CircleMarker(
                          point: location.position,
                          radius: 7,
                          color: colors.brand,
                          borderColor: colors.surface,
                          borderStrokeWidth: 3,
                        ),
                      ],
                    ),
                  TransitMarkersLayer(hits: _hits),
                ],
              ),
              _FloatingControls(
                sheet: _sheet,
                collapsedSize: _collapsedSize,
                height: constraints.maxHeight,
                onLocate: _locate,
              ),
              MapSheet(
                controller: _sheet,
                collapsedSize: _collapsedSize,
                fullSize: SheetStops.fullFor(
                  constraints.maxHeight,
                  topInset: MediaQuery.paddingOf(context).top,
                ),
              ),
              // Encima de la hoja: los resultados de la búsqueda se abren
              // hacia abajo y no pueden quedar tapados por ella.
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Spacing.lg,
                    Spacing.sm,
                    Spacing.lg,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: MapSearchBar(
                              onPick: _onSearchPick,
                              trailing: const GlobalFreshnessChip(),
                            ),
                          ),
                          if (kDebugMode) const _DebugMenu(),
                        ],
                      ),
                      _MapChips(sheet: _sheet),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// El botón de ubicación y la atribución, flotando justo encima de la hoja.
///
/// Siguen a la hoja cuando se arrastra, y se esconden cuando pasa de la
/// mitad: con la hoja casi a pantalla completa ya no hay mapa que ubicar.
class _FloatingControls extends StatelessWidget {
  const _FloatingControls({
    required this.sheet,
    required this.collapsedSize,
    required this.height,
    required this.onLocate,
  });

  final DraggableScrollableController sheet;
  final double collapsedSize;
  final double height;
  final VoidCallback onLocate;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return Positioned.fill(
      child: AnimatedBuilder(
        animation: sheet,
        builder: (BuildContext context, Widget? child) {
          final double size = sheet.isAttached ? sheet.size : collapsedSize;
          return Stack(
            children: <Widget>[
              if (size <= SheetStops.half + 0.05)
                Positioned(
                  left: Spacing.lg,
                  right: Spacing.lg,
                  bottom: size * height + Spacing.md,
                  child: child!,
                ),
            ],
          );
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            // OpenStreetMap y OpenMapTiles piden atribución visible. Va sobre
            // la superficie para que se lea encima de cualquier calle.
            Expanded(
              child: Align(
                alignment: Alignment.bottomLeft,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            const SizedBox(width: Spacing.md),
            FloatingActionButton(
              heroTag: 'locate',
              tooltip: 'Ir a mi ubicación',
              backgroundColor: colors.surfaceRaised,
              foregroundColor: colors.brand,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.cardRadius,
                side: BorderSide(color: colors.outline),
              ),
              onPressed: onLocate,
              child: const Icon(Icons.my_location),
            ),
          ],
        ),
      ),
    );
  }
}

/// Los chips bajo la búsqueda: "Cómo llego" y "Solo accesibles".
///
/// Se esconden mientras se busca, para no quedar encima de los resultados, y
/// cuando la hoja pasa de la mitad, para no quedar encima de ella: igual que
/// el botón de ubicación.
class _MapChips extends ConsumerWidget {
  const _MapChips({required this.sheet});

  final DraggableScrollableController sheet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(searchQueryProvider).trim().isNotEmpty) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: sheet,
      builder: (BuildContext context, Widget? child) {
        final bool covered =
            sheet.isAttached && sheet.size > SheetStops.half + 0.05;
        return covered ? const SizedBox.shrink() : child!;
      },
      child: const Padding(
        padding: EdgeInsets.only(top: Spacing.sm),
        child: Wrap(
          spacing: Spacing.sm,
          runSpacing: Spacing.xs,
          children: <Widget>[_PlanChip(), AccessibleOnlyChip()],
        ),
      ),
    );
  }
}

/// "Cómo llego": el planificador, saliendo de donde estás.
class _PlanChip extends StatelessWidget {
  const _PlanChip();

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return ActionChip(
      avatar: Icon(Icons.directions, size: 18, color: colors.brand),
      label: const Text('Cómo llego'),
      labelStyle: AppTypography.label.copyWith(color: colors.textPrimary),
      tooltip: 'Planear un viaje desde tu ubicación',
      backgroundColor: colors.surfaceRaised,
      side: BorderSide(color: colors.outline),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.chipRadius),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      onPressed: () => context.pushNamed(
        AppRoute.planner.name,
        queryParameters: const TripRequest(from: HerePlace()).toQuery(),
      ),
    );
  }
}

/// Los caminos a la galería y al simulador, solo en debug.
class _DebugMenu extends StatelessWidget {
  const _DebugMenu();

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(left: Spacing.sm),
      child: PopupMenuButton<AppRoute>(
        tooltip: 'Herramientas de desarrollo',
        icon: Icon(Icons.bug_report_outlined, color: colors.textSecondary),
        style: IconButton.styleFrom(
          backgroundColor: colors.surfaceRaised,
          minimumSize: const Size.square(AppSizes.minTouchTarget + Spacing.xs),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.cardRadius,
            side: BorderSide(color: colors.outline),
          ),
        ),
        onSelected: (AppRoute route) => context.pushNamed(route.name),
        itemBuilder: (BuildContext context) => <PopupMenuEntry<AppRoute>>[
          const PopupMenuItem<AppRoute>(
            value: AppRoute.gallery,
            child: Text('Ver el design system'),
          ),
          const PopupMenuItem<AppRoute>(
            value: AppRoute.simulator,
            child: Text('Ver el simulador'),
          ),
        ],
      ),
    );
  }
}
