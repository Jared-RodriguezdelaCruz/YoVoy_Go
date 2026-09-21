import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/clock/clock_provider.dart';
import '../../../../core/config/freshness.dart';
import '../../../../core/data/transit_network.dart';
import '../../../../core/models/models.dart';
import '../../../../design/components/vehicle_marker.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/motion.dart';
import '../../../../design/tokens/route_palette.dart';
import '../../../../design/tokens/typography.dart';
import '../../application/map_providers.dart';
import '../../application/screen_clusterer.dart';
import '../../application/vehicle_interpolator.dart';
import '../map_hit_test.dart';

/// Los camiones y las paradas, dibujados con **un solo** `CustomPainter`.
///
/// Las reglas de la sección 7 del spec viven aquí:
///
/// - **Un solo `Ticker`** mueve a toda la flota. No hay un widget ni un
///   `AnimationController` por camión: con 40 en pantalla eso cuesta frames.
/// - **Se filtra por viewport antes de dibujar**, y arriba de 30 visibles se
///   agrupan.
/// - **`RepaintBoundary`** alrededor: el mapa de abajo no se repinta porque un
///   camión avanzó un píxel.
///
/// Las paradas aparecen desde z15. Más lejos son 1 507 puntos que no se
/// distinguen y tapan las rutas.
class TransitMarkersLayer extends ConsumerStatefulWidget {
  const TransitMarkersLayer({required this.hits, super.key});

  /// Donde la capa anota lo que dibujó, para el `onTap` del mapa.
  final MapHitRegistry hits;

  /// Desde qué zoom se dibujan las paradas.
  static const double stopsMinZoom = 15;

  /// Radio del marcador de camión.
  static const double vehicleRadius = 13;

  @override
  ConsumerState<TransitMarkersLayer> createState() =>
      _TransitMarkersLayerState();
}

class _TransitMarkersLayerState extends ConsumerState<TransitMarkersLayer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  late final ValueNotifier<DateTime> _clock = ValueNotifier<DateTime>(
    ref.read(clockProvider)(),
  );

  void _onTick(Duration _) => _clock.value = ref.read(clockProvider)();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Con "reducir movimiento" los camiones saltan de reporte en reporte y el
    // `Ticker` no corre: basta con repintar una vez por segundo para la edad.
    if (AppMotion.allowsLooping(context)) {
      if (!_ticker.isActive) {
        _ticker.start();
      }
    } else if (_ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final VehicleInterpolator tracker = ref.watch(vehicleTrackerProvider);
    final TransitNetwork? network = ref.watch(transitNetworkProvider).value;
    final MapSelection selection = ref.watch(mapSelectionStateProvider);
    final MapCamera camera = MapCamera.of(context);
    final AppColors colors = context.colors;
    final bool animate = AppMotion.allowsLooping(context);

    // Sin `Ticker`, algo tiene que repintar cuando llega un lote.
    if (!animate) {
      ref.listen(vehicleFeedProvider, (_, _) => _onTick(Duration.zero));
    }

    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _TransitMarkersPainter(
          clock: _clock,
          tracker: tracker,
          network: network,
          camera: camera,
          selection: selection,
          colors: colors,
          hits: widget.hits,
          interpolate: animate,
        ),
      ),
    );
  }
}

class _TransitMarkersPainter extends CustomPainter {
  _TransitMarkersPainter({
    required this.clock,
    required this.tracker,
    required this.network,
    required this.camera,
    required this.selection,
    required this.colors,
    required this.hits,
    required this.interpolate,
  }) : super(repaint: clock);

  final ValueNotifier<DateTime> clock;
  final VehicleInterpolator tracker;
  final TransitNetwork? network;
  final MapCamera camera;
  final MapSelection selection;
  final AppColors colors;
  final MapHitRegistry hits;
  final bool interpolate;

  /// Los números de los grupos, que se repiten mucho: se arman una vez.
  static final Map<(int, int), TextPainter> _countLabels =
      <(int, int), TextPainter>{};

  @override
  void paint(Canvas canvas, Size size) {
    hits.clear();
    final LatLngBounds bounds = _padded(camera.visibleBounds);

    if (camera.zoom >= TransitMarkersLayer.stopsMinZoom) {
      _paintStops(canvas, bounds);
    }
    _paintVehicles(canvas, bounds);
  }

  void _paintStops(Canvas canvas, LatLngBounds bounds) {
    final TransitNetwork? net = network;
    if (net == null) {
      return;
    }
    final String? selectedStop = switch (selection) {
      StopSelected(:final String stopId) => stopId,
      _ => null,
    };

    final Paint fill = Paint()..color = colors.surfaceRaised;
    final Paint ring = Paint()
      ..color = colors.textSecondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final Paint selectedFill = Paint()..color = colors.brand;
    final Paint selectedRing = Paint()
      ..color = colors.surface
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (final Stop stop in net.stops) {
      if (!bounds.contains(stop.position)) {
        continue;
      }
      final Offset point = camera.latLngToScreenOffset(stop.position);
      if (stop.id == selectedStop) {
        canvas
          ..drawCircle(point, 8, selectedFill)
          ..drawCircle(point, 8, selectedRing);
      } else {
        canvas
          ..drawCircle(point, 4.5, fill)
          ..drawCircle(point, 4.5, ring);
      }
      hits.add(StopHit(point, stopId: stop.id));
    }
  }

  void _paintVehicles(Canvas canvas, LatLngBounds bounds) {
    final DateTime now = clock.value;
    final String? litRoute = selection.litRouteId;
    final String? selectedVehicle = switch (selection) {
      VehicleSelected(:final String vehicleId) => vehicleId,
      _ => null,
    };

    final List<({VehicleFrame item, Offset point})> visible =
        <({VehicleFrame item, Offset point})>[];
    VehicleFrame? chosen;
    for (final VehicleFrame frame in tracker.frameAt(
      now,
      interpolate: interpolate,
    )) {
      if (!bounds.contains(frame.position)) {
        continue;
      }
      if (frame.vehicle.vehicleId == selectedVehicle) {
        // El elegido nunca se agrupa: el usuario lo está siguiendo.
        chosen = frame;
        continue;
      }
      visible.add((
        item: frame,
        point: camera.latLngToScreenOffset(frame.position),
      ));
    }

    for (final ScreenCluster<VehicleFrame> cluster
        in ScreenClusterer.cluster<VehicleFrame>(visible)) {
      if (cluster.isSingle) {
        _paintVehicle(
          canvas,
          cluster.members.single,
          cluster.center,
          dimmed:
              litRoute != null &&
              cluster.members.single.vehicle.routeId != litRoute,
        );
      } else {
        _paintCluster(canvas, cluster, dimmed: litRoute != null);
      }
    }

    final VehicleFrame? mine = chosen;
    if (mine != null) {
      final Offset point = camera.latLngToScreenOffset(mine.position);
      // Un anillo de marca alrededor del camión elegido.
      canvas.drawCircle(
        point,
        TransitMarkersLayer.vehicleRadius + 5,
        Paint()..color = colors.brand.withValues(alpha: 0.35),
      );
      _paintVehicle(canvas, mine, point, dimmed: false);
    }
  }

  void _paintVehicle(
    Canvas canvas,
    VehicleFrame frame,
    Offset point, {
    required bool dimmed,
  }) {
    final VehiclePosition vehicle = frame.vehicle;
    final DataFreshness freshness = Freshness.classify(frame.age);
    final TransitRoute? route = network?.route(vehicle.routeId);

    Color color = RoutePalette.colorForRoute(
      routeId: vehicle.routeId,
      gtfsColor: route?.color,
    );
    double? bearing = vehicle.bearing;
    switch (freshness) {
      case DataFreshness.live:
        break;
      case DataFreshness.stale:
        // El mismo apagado que `VehicleMarker(isStale: true)`.
        color = color.withValues(alpha: 0.55);
      case DataFreshness.unknown:
        // Sin señal: gris y sin flecha. Sigue en su último lugar conocido,
        // pero ya no promete hacia dónde va.
        color = colors.unknown;
        bearing = null;
    }
    if (dimmed) {
      color = color.withValues(alpha: color.a * 0.4);
    }

    VehicleMarker.paintMarker(
      canvas,
      center: point,
      radius: TransitMarkersLayer.vehicleRadius,
      color: color,
      haloColor: colors.surface,
      contentColor: RoutePalette.onColor(color.withValues(alpha: 1)),
      bearing: bearing,
    );
    hits.add(
      VehicleHit(point, vehicleId: vehicle.vehicleId, routeId: vehicle.routeId),
    );
  }

  /// Un grupo es un resumen, no un protagonista: va en los tonos de la
  /// superficie y deja el color a los camiones sueltos. Con una ruta
  /// encendida baja todavía más, como el resto de lo que no se está mirando.
  void _paintCluster(
    Canvas canvas,
    ScreenCluster<VehicleFrame> cluster, {
    required bool dimmed,
  }) {
    final int count = cluster.members.length;
    final double radius = count < 10 ? 14 : 17;
    final double alpha = dimmed ? 0.4 : 1;

    canvas
      ..drawCircle(
        cluster.center,
        radius + 2,
        Paint()..color = colors.surface.withValues(alpha: alpha),
      )
      ..drawCircle(
        cluster.center,
        radius,
        Paint()..color = colors.surfaceRaised.withValues(alpha: alpha),
      )
      ..drawCircle(
        cluster.center,
        radius,
        Paint()
          ..color = colors.textSecondary.withValues(alpha: 0.6 * alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

    final Color ink = colors.textPrimary.withValues(alpha: alpha);
    final TextPainter label = _countLabels.putIfAbsent(
      (count, ink.toARGB32()),
      () => TextPainter(
        text: TextSpan(
          text: '$count',
          style: AppTypography.caption.copyWith(
            color: ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(),
    );
    label.paint(
      canvas,
      cluster.center - Offset(label.width / 2, label.height / 2),
    );

    final LatLng center = camera.screenOffsetToLatLng(cluster.center);
    hits.add(ClusterHit(cluster.center, center: center));
  }

  /// El viewport con un margen, para que un camión en el borde no aparezca de
  /// golpe a medio dibujar.
  static LatLngBounds _padded(LatLngBounds bounds) {
    final double dLat = (bounds.north - bounds.south) * 0.05;
    final double dLon = (bounds.east - bounds.west) * 0.05;
    return LatLngBounds(
      LatLng(bounds.south - dLat, bounds.west - dLon),
      LatLng(bounds.north + dLat, bounds.east + dLon),
    );
  }

  @override
  bool shouldRepaint(_TransitMarkersPainter oldDelegate) =>
      oldDelegate.camera != camera ||
      oldDelegate.selection != selection ||
      oldDelegate.network != network ||
      oldDelegate.colors != colors ||
      oldDelegate.tracker != tracker ||
      oldDelegate.interpolate != interpolate;
}
