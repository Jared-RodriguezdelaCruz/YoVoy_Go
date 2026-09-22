import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/data/transit_network.dart';
import '../../../core/models/models.dart';

/// Hasta dónde se considera "cerca" caminando. Es el mismo radio con el que
/// el generador del dataset busca alternativas.
const double nearbyMeters = 600;

/// Una ruta que pasa cerca del origen, con su parada más cercana.
@immutable
class NearbyRoute {
  const NearbyRoute({
    required this.route,
    required this.stop,
    required this.meters,
  });

  final TransitRoute route;
  final Stop stop;
  final double meters;
}

/// Lo más cerca que se llega del destino con un solo camión.
@immutable
class ClosestReach {
  const ClosestReach({
    required this.route,
    required this.board,
    required this.alight,
    required this.remainingMeters,
  });

  final TransitRoute route;
  final Stop board;
  final Stop alight;

  /// Lo que queda de [alight] al destino, en línea recta.
  final double remainingMeters;
}

/// La salida útil de "no encontré ruta" (§8.4 del spec).
@immutable
class NoRouteHelp {
  const NoRouteHelp({required this.nearOrigin, required this.reach});

  /// Las rutas que sí pasan cerca del origen, de la más cercana a la más
  /// lejana.
  final List<NearbyRoute> nearOrigin;

  /// `null` si ningún camión acerca de verdad al destino.
  final ClosestReach? reach;
}

const Distance _distance = Distance();

double _meters(LatLng a, LatLng b) => _distance.as(LengthUnit.Meter, a, b);

/// Arma la salida útil con la red real. No es un motor de ruteo: mira un
/// solo camión, subiendo cerca del origen, y dice hasta dónde llega.
///
/// [reach] solo aparece si deja al usuario a menos de 3/4 de la distancia
/// original: sugerir un camión que casi no acerca sería ruido.
NoRouteHelp noRouteHelp(
  TransitNetwork network, {
  required LatLng from,
  required LatLng to,
  int maxRoutes = 5,
}) {
  final Map<String, NearbyRoute> byRoute = <String, NearbyRoute>{};
  for (final Stop stop in network.stops) {
    final double meters = _meters(from, stop.position);
    if (meters > nearbyMeters) {
      continue;
    }
    for (final String routeId in network.routesForStop(stop.id)) {
      final NearbyRoute? current = byRoute[routeId];
      final TransitRoute? route = network.route(routeId);
      if (route != null && (current == null || meters < current.meters)) {
        byRoute[routeId] = NearbyRoute(
          route: route,
          stop: stop,
          meters: meters,
        );
      }
    }
  }
  final List<NearbyRoute> nearOrigin = byRoute.values.toList()
    ..sort((NearbyRoute a, NearbyRoute b) {
      final int byMeters = a.meters.compareTo(b.meters);
      return byMeters != 0
          ? byMeters
          : a.route.shortName.compareTo(b.route.shortName);
    });

  ClosestReach? best;
  for (final NearbyRoute nearby in nearOrigin) {
    for (final Trip trip in network.tripsForRoute(nearby.route.id)) {
      final List<Stop> stops = network.stopsForTrip(trip.id);
      // Se sube en la parada de este viaje más cercana al origen.
      int board = -1;
      double boardMeters = double.infinity;
      for (int i = 0; i < stops.length; i++) {
        final double meters = _meters(from, stops[i].position);
        if (meters <= nearbyMeters && meters < boardMeters) {
          board = i;
          boardMeters = meters;
        }
      }
      if (board < 0) {
        continue;
      }
      for (int i = board + 1; i < stops.length; i++) {
        final double remaining = _meters(stops[i].position, to);
        if (best == null || remaining < best.remainingMeters) {
          best = ClosestReach(
            route: nearby.route,
            board: stops[board],
            alight: stops[i],
            remainingMeters: remaining,
          );
        }
      }
    }
  }

  final double direct = _meters(from, to);
  return NoRouteHelp(
    nearOrigin: nearOrigin.take(maxRoutes).toList(growable: false),
    reach: best != null && best.remainingMeters < direct * 0.75 ? best : null,
  );
}

/// "300 m" o "1.2 km", como se dice una distancia caminando.
String distanceLabel(double meters) {
  if (meters < 1000) {
    final int rounded = (meters / 50).round() * 50;
    return '${rounded < 50 ? 50 : rounded} m';
  }
  return '${(meters / 1000).toStringAsFixed(1)} km';
}
