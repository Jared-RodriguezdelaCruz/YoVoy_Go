import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/transit_network.dart';
import '../../../../core/models/models.dart';
import '../../../../design/components/route_line.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/route_palette.dart';
import '../../application/map_providers.dart';

/// La red de rutas: un grabado apagado, con una sola ruta encendida.
///
/// Cuarenta y ocho rutas a color pleno son un plato de espagueti. En reposo la
/// red va delgada y al 30 %: se ve que la ciudad tiene rutas, pero ninguna
/// grita. Al tocar un camión o buscar una ruta, **esa ruta se enciende** —su
/// grosor según el zoom, su halo, su color completo— y las demás bajan al
/// 15 %. La luz marca lo que estás mirando, igual que en `RouteStrip`.
///
/// La simplificación por zoom (Douglas-Peucker) y el recorte por viewport los
/// hace `PolylineLayer` de flutter_map, que ya los trae.
class RouteNetworkLayer extends ConsumerStatefulWidget {
  const RouteNetworkLayer({super.key});

  /// Opacidad de la red en reposo.
  static const double restingAlpha = 0.30;

  /// Opacidad de la red cuando hay una ruta encendida.
  static const double dimmedAlpha = 0.15;

  @override
  ConsumerState<RouteNetworkLayer> createState() => _RouteNetworkLayerState();
}

class _RouteNetworkLayerState extends ConsumerState<RouteNetworkLayer> {
  // Las polilíneas se reconstruyen por **banda** de zoom, no en cada cuadro
  // del pellizco: un `Polyline` nuevo obliga a `PolylineLayer` a reproyectar
  // los 41 000 puntos, y eso a 60 fps no cabe.
  final Map<(int, String?, Brightness), List<Polyline>> _dimCache =
      <(int, String?, Brightness), List<Polyline>>{};
  final Map<(int, String, Brightness), List<Polyline>> _litCache =
      <(int, String, Brightness), List<Polyline>>{};
  TransitNetwork? _cachedFor;

  @override
  Widget build(BuildContext context) {
    final TransitNetwork? network = ref.watch(transitNetworkProvider).value;
    if (network == null) {
      return const SizedBox.shrink();
    }
    if (!identical(network, _cachedFor)) {
      _dimCache.clear();
      _litCache.clear();
      _cachedFor = network;
    }

    final String? lit = ref.watch(
      mapSelectionStateProvider.select((MapSelection s) => s.litRouteId),
    );
    final AppColors colors = context.colors;
    final Brightness brightness = Theme.of(context).brightness;
    final int band = MapCamera.of(context).zoom.round();

    final List<Polyline> dim = _dimCache.putIfAbsent((
      band,
      lit,
      brightness,
    ), () => _network(network, band, lit));

    return Stack(
      children: <Widget>[
        PolylineLayer(polylines: dim),
        if (lit != null)
          PolylineLayer(
            polylines: _litCache.putIfAbsent((
              band,
              lit,
              brightness,
            ), () => _litRoute(network, lit, band, colors)),
          ),
      ],
    );
  }

  List<Polyline> _network(TransitNetwork network, int band, String? lit) {
    final double alpha = lit == null
        ? RouteNetworkLayer.restingAlpha
        : RouteNetworkLayer.dimmedAlpha;
    // Delgada a propósito: el grabado se ve, no se lee.
    final double width = (RouteLine.strokeWidthForZoom(band.toDouble()) * 0.4)
        .clamp(1.5, 3.0);

    return <Polyline>[
      for (final TransitRoute route in network.routes)
        if (route.id != lit)
          for (final Shape shape in network.shapesForRoute(route.id))
            if (shape.points.length >= 2)
              Polyline(
                points: shape.points,
                strokeWidth: width,
                color: _colorOf(route).withValues(alpha: alpha),
              ),
    ];
  }

  List<Polyline> _litRoute(
    TransitNetwork network,
    String routeId,
    int band,
    AppColors colors,
  ) {
    final TransitRoute? route = network.route(routeId);
    if (route == null) {
      return const <Polyline>[];
    }
    final double width = RouteLine.strokeWidthForZoom(band.toDouble());
    return <Polyline>[
      for (final Shape shape in network.shapesForRoute(routeId))
        if (shape.points.length >= 2)
          Polyline(
            points: shape.points,
            strokeWidth: width,
            color: _colorOf(route),
            // El halo del trazo, igual que `RouteLine`: lo que lo mantiene
            // legible cuando cruza una calle clara.
            borderStrokeWidth: 2,
            borderColor: colors.surface,
          ),
    ];
  }

  static Color _colorOf(TransitRoute route) =>
      RoutePalette.colorForRoute(routeId: route.id, gtfsColor: route.color);
}
