import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/clock/clock_provider.dart';
import '../../../core/data/not_found.dart';
import '../../../core/data/transit_network.dart';
import '../../../core/models/models.dart';
import '../../../core/transit/live_providers.dart';
import '../../../core/transit/vehicle_interpolator.dart';
import 'vehicle_placement.dart';

part 'route_providers.g.dart';

/// Se pidió una ruta que la red no tiene.
class RouteNotFound extends NotFound {
  const RouteNotFound(super.id);
}

/// Un sentido de la ruta, nombrado por su destino.
///
/// En la calle nadie sabe cuál es "la ida": se sabe a dónde va el camión.
@immutable
class RouteDirection {
  const RouteDirection({
    required this.directionId,
    required this.headsign,
    required this.tripId,
    this.shapeId,
  });

  final int directionId;
  final String headsign;

  /// El viaje que representa al sentido: de él salen las paradas.
  final String tripId;
  final String? shapeId;
}

/// Los sentidos de una ruta, en el orden de `direction_id`. Casi todas tienen
/// dos; dos rutas del dataset tienen uno.
@Riverpod(retry: retryUnlessNotFound)
Future<List<RouteDirection>> routeDirections(Ref ref, String routeId) async {
  final TransitNetwork network = await ref.watch(transitNetworkProvider.future);
  if (network.route(routeId) == null) {
    throw RouteNotFound(routeId);
  }
  final Map<int, RouteDirection> byDirection = <int, RouteDirection>{};
  for (final Trip trip in network.tripsForRoute(routeId)) {
    byDirection.putIfAbsent(
      trip.directionId,
      () => RouteDirection(
        directionId: trip.directionId,
        headsign: trip.headsign,
        tripId: trip.id,
        shapeId: trip.shapeId,
      ),
    );
  }
  return byDirection.values.toList()..sort(
    (RouteDirection a, RouteDirection b) =>
        a.directionId.compareTo(b.directionId),
  );
}

/// El sentido que el usuario está mirando. `null` hasta que elija: la
/// pantalla muestra entonces el primero.
@riverpod
class SelectedDirection extends _$SelectedDirection {
  @override
  int? build(String routeId) => null;

  void select(int directionId) => state = directionId;
}

/// Todo lo que pinta la pantalla de ruta para un sentido.
@immutable
class RouteDetail {
  const RouteDetail({
    required this.route,
    required this.direction,
    required this.stops,
    required this.path,
    required this.vehicles,
  });

  final TransitRoute route;
  final RouteDirection direction;
  final List<Stop> stops;

  /// El trazo del sentido. Vacío si el GTFS no lo trae.
  final List<LatLng> path;

  /// Los camiones de este sentido que siguen en la memoria del mapa,
  /// incluidos los que perdieron señal hace menos de 10 minutos: se marcan,
  /// no se borran.
  final List<PlacedVehicle> vehicles;
}

/// La ruta en un sentido, con sus camiones colocados entre paradas.
///
/// Se recalcula con cada lote de la flota.
@Riverpod(retry: retryUnlessNotFound)
Future<RouteDetail> routeDetail(
  Ref ref,
  String routeId,
  int directionId,
) async {
  final TransitNetwork network = await ref.watch(transitNetworkProvider.future);
  final TransitRoute route =
      network.route(routeId) ?? (throw RouteNotFound(routeId));
  final List<RouteDirection> directions = await ref.watch(
    routeDirectionsProvider(routeId).future,
  );
  final RouteDirection direction = directions.firstWhere(
    (RouteDirection d) => d.directionId == directionId,
    orElse: () =>
        directions.isNotEmpty ? directions.first : throw RouteNotFound(routeId),
  );

  // El rastreador primero, para que su suscripción al feed vaya antes que la
  // nuestra y ya tenga el lote cuando esto se recalcule.
  final VehicleInterpolator tracker = ref.watch(vehicleTrackerProvider);
  ref.watch(vehicleFeedProvider);
  final DateTime now = ref.watch(clockProvider)();

  final List<VehiclePosition> vehicles = <VehiclePosition>[
    for (final VehicleFrame frame in tracker.frameAt(now, interpolate: false))
      if (frame.vehicle.routeId == routeId &&
          network.trip(frame.vehicle.tripId)?.directionId ==
              direction.directionId)
        frame.vehicle,
  ];
  final List<Stop> stops = network.stopsForTrip(direction.tripId);

  return RouteDetail(
    route: route,
    direction: direction,
    stops: stops,
    path: switch (direction.shapeId) {
      final String id => network.shape(id)?.points ?? const <LatLng>[],
      null => const <LatLng>[],
    },
    vehicles: placeVehicles(stops: stops, vehicles: vehicles, now: now),
  );
}
