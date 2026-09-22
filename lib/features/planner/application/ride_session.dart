import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/clock/clock_provider.dart';
import '../../../core/config/freshness.dart';
import '../../../core/data/transit_network.dart';
import '../../../core/models/models.dart';
import '../../../core/transit/live_providers.dart';
import '../../../core/transit/vehicle_interpolator.dart';
import '../../route/application/vehicle_placement.dart';
import '../../stop/application/stop_board.dart';
import 'leg_timing.dart';
import 'planner_providers.dart';
import 'trip_request.dart';

part 'ride_session.g.dart';

// El modo viaje, la feature 5 de `FEATURES.md`: vas a bordo en una ruta que no
// conoces y no sabes cuándo bajarte.
//
// Lo alimenta **el camión en el que vas**, no el GPS del teléfono. Al tocar
// "Ya me subí" se fija el vehículo de esa ruta que está en la parada, y el
// conteo sale de su reporte. El GPS es lo que más batería gasta, y el feed ya
// está abierto.

/// El tramo de un viaje de camión, puesto sobre las paradas de su viaje.
@immutable
class LegPath {
  const LegPath({
    required this.tripId,
    required this.tripStops,
    required this.board,
    required this.alight,
  });

  final String tripId;

  /// Todas las paradas del viaje, para colocar al camión.
  final List<Stop> tripStops;

  /// Dónde se sube y dónde se baja, como índices de [tripStops].
  final int board;
  final int alight;

  int get stopCount => alight - board;

  Stop get alightStop => tripStops[alight];
}

/// Busca el viaje de la ruta de [leg] que pasa por su subida **antes** que
/// por su bajada. Así se sabe el sentido. Con [preferTripId] se prueba ese
/// primero, que es el del camión que ya se eligió.
LegPath? legPath(TransitNetwork network, Leg leg, {String? preferTripId}) {
  final String? routeId = leg.route?.id;
  final String? from = leg.fromStopId;
  final String? to = leg.toStopId;
  if (routeId == null || from == null || to == null) {
    return null;
  }
  final List<Trip> trips = <Trip>[
    ...network.tripsForRoute(routeId).where((Trip t) => t.id == preferTripId),
    ...network.tripsForRoute(routeId).where((Trip t) => t.id != preferTripId),
  ];
  for (final Trip trip in trips) {
    final List<Stop> stops = network.stopsForTrip(trip.id);
    final int board = stops.indexWhere((Stop s) => s.id == from);
    if (board < 0) {
      continue;
    }
    final int alight = stops.indexWhere((Stop s) => s.id == to, board + 1);
    if (alight > board) {
      return LegPath(
        tripId: trip.id,
        tripStops: stops,
        board: board,
        alight: alight,
      );
    }
  }
  return null;
}

/// El camión al que el usuario se acaba de subir: de la ruta y el sentido de
/// [leg], con señal, y en la parada o llegando a ella.
///
/// `null` si no hay ninguno. En ese caso la pantalla lo dice y no deja
/// empezar: seguir a un camión inventado sería peor que no seguir a ninguno.
PlacedVehicle? pickBoardedVehicle({
  required TransitNetwork network,
  required Leg leg,
  required List<VehiclePosition> fleet,
  required DateTime now,
}) {
  PlacedVehicle? best;
  int bestRank = -1;
  for (final VehiclePosition vehicle in fleet) {
    if (vehicle.routeId != leg.route?.id ||
        Freshness.classify(vehicle.ageAt(now)) == DataFreshness.unknown) {
      continue;
    }
    final LegPath? path = legPath(network, leg, preferTripId: vehicle.tripId);
    if (path == null || path.tripId != vehicle.tripId) {
      continue;
    }
    final PlacedVehicle placed = placeVehicles(
      stops: path.tripStops,
      vehicles: <VehiclePosition>[vehicle],
      now: now,
    ).single;
    // En la parada gana a "llegando": es al que te puedes subir ya.
    final int rank = switch (placed.afterIndex - path.board) {
      0 => 2,
      -1 => 1,
      _ => -1,
    };
    if (rank < 0) {
      continue;
    }
    if (rank > bestRank ||
        (rank == bestRank && best != null && placed.age < best.age)) {
      best = placed;
      bestRank = rank;
    }
  }
  return best;
}

/// Lo que se le avisa al usuario mientras va a bordo.
enum RideAlert {
  /// Faltan dos paradas.
  prepare,

  /// La que sigue es la tuya.
  next,

  /// Estás en tu parada.
  here,
}

/// Cómo va el tramo a bordo.
@immutable
class RideStatus {
  const RideStatus({
    required this.path,
    required this.stopsLeft,
    required this.dataAge,
    required this.strip,
  });

  final LegPath path;

  /// Cuántas paradas faltan para bajarse. `null` si el camión se perdió del
  /// feed: entonces no se sabe, y no se adivina.
  final int? stopsLeft;

  /// Qué tan viejo es el último reporte del camión. `null` si ya no está.
  final Duration? dataAge;

  /// La tira con lo que falta. `null` si ya no hay nada que dibujar.
  final ApproachStrip? strip;

  /// Sin reporte útil: el camión se fue del feed o su dato ya no sirve.
  bool get signalLost =>
      dataAge == null || Freshness.classify(dataAge!) == DataFreshness.unknown;

  RideAlert? get alert => switch (stopsLeft) {
    null => null,
    <= 0 => RideAlert.here,
    1 => RideAlert.next,
    2 => RideAlert.prepare,
    _ => null,
  };
}

/// El estado de un tramo a bordo de [vehicle].
///
/// Con la señal perdida el conteo se queda donde lo dejó el último reporte,
/// con su edad: no se inventa avance. Si el camión ya no está ni en la
/// memoria del mapa, el conteo es `null`.
RideStatus rideStatus({
  required LegPath path,
  required VehiclePosition? vehicle,
  required DateTime now,
}) {
  if (vehicle == null) {
    return RideStatus(path: path, stopsLeft: null, dataAge: null, strip: null);
  }
  final PlacedVehicle placed = placeVehicles(
    stops: path.tripStops,
    vehicles: <VehiclePosition>[vehicle],
    now: now,
  ).single;
  final int left = path.alight - placed.afterIndex;
  return RideStatus(
    path: path,
    stopsLeft: left < 0 ? 0 : left,
    dataAge: placed.age,
    strip: approachStrip(
      tripStops: path.tripStops,
      stopId: path.alightStop.id,
      vehicle: vehicle,
      now: now,
      maxStops: 6,
    ),
  );
}

/// El estado del viaje que se lleva en la sesión.
@immutable
class RideState {
  const RideState({
    this.legIndex = 0,
    this.vehicleId,
    this.fired = const <RideAlert>{},
  });

  /// El tramo en curso.
  final int legIndex;

  /// El camión en el que va el usuario, en el tramo en curso.
  final String? vehicleId;

  /// Los avisos que ya sonaron en este tramo.
  final Set<RideAlert> fired;
}

/// Lleva el viaje de tramo en tramo.
@riverpod
class RideController extends _$RideController {
  @override
  RideState build(TripRequest request, int option) => const RideState();

  /// "Ya me subí".
  void board(String vehicleId) =>
      state = RideState(legIndex: state.legIndex, vehicleId: vehicleId);

  /// Pasa al siguiente tramo: llegué a la parada, ya bajé.
  void advance() => state = RideState(legIndex: state.legIndex + 1);

  /// `true` la primera vez que se pide [alert] en este tramo. Así cada aviso
  /// vibra una sola vez aunque el conteo se quede quieto varios reportes.
  bool claim(RideAlert alert) {
    if (state.fired.contains(alert)) {
      return false;
    }
    state = RideState(
      legIndex: state.legIndex,
      vehicleId: state.vehicleId,
      fired: <RideAlert>{...state.fired, alert},
    );
    return true;
  }
}

/// Lo que pinta el modo viaje en cada momento.
@immutable
sealed class RideView {
  const RideView({required this.itinerary, required this.legIndex});

  final Itinerary itinerary;
  final int legIndex;

  Leg get leg => itinerary.legs[legIndex];

  bool get isLastLeg => legIndex == itinerary.legs.length - 1;
}

/// Caminando: a la parada, entre paradas o al destino.
final class RideWalking extends RideView {
  const RideWalking({required super.itinerary, required super.legIndex});
}

/// En la parada, esperando el camión.
final class RideWaiting extends RideView {
  const RideWaiting({
    required super.itinerary,
    required super.legIndex,
    required this.arrival,
    required this.candidate,
  });

  /// El próximo camión de esta ruta aquí, si los arribos respondieron.
  final Arrival? arrival;

  /// El camión que se fijaría al tocar "Ya me subí".
  final PlacedVehicle? candidate;
}

/// A bordo.
final class RideOnBoard extends RideView {
  const RideOnBoard({
    required super.itinerary,
    required super.legIndex,
    required this.status,
  });

  final RideStatus? status;
}

/// Llegaste.
final class RideFinished extends RideView {
  const RideFinished({required super.itinerary, required super.legIndex});
}

@riverpod
Future<RideView> rideView(Ref ref, TripRequest request, int option) async {
  // Todo lo que se escucha va antes del primer `await`: mientras este
  // provider se recalcula, lo que aún no volvió a escuchar se queda sin nadie,
  // y un provider `autoDispose` sin nadie se desecha. El viaje volvería al
  // paso 1 y la flota olvidaría sus camiones.
  final RideState ride = ref.watch(rideControllerProvider(request, option));
  final VehicleInterpolator tracker = ref.watch(vehicleTrackerProvider);
  ref.watch(vehicleFeedProvider);
  final DateTime now = ref.watch(clockProvider)();

  final (TripPlan _, Itinerary itinerary) = await ref.watch(
    tripOptionProvider(request, option).future,
  );
  if (ride.legIndex >= itinerary.legs.length) {
    return RideFinished(
      itinerary: itinerary,
      legIndex: itinerary.legs.length - 1,
    );
  }
  final Leg leg = itinerary.legs[ride.legIndex];
  if (leg.isWalk) {
    return RideWalking(itinerary: itinerary, legIndex: ride.legIndex);
  }
  final TransitNetwork network = await ref.watch(transitNetworkProvider.future);

  final String? vehicleId = ride.vehicleId;
  if (vehicleId == null) {
    final String? stopId = leg.fromStopId;
    final List<Arrival> arrivals = stopId == null
        ? const <Arrival>[]
        : await ref.watch(stopArrivalsProvider(stopId).future);
    return RideWaiting(
      itinerary: itinerary,
      legIndex: ride.legIndex,
      arrival: switch (leg.route) {
        final TransitRoute route => boardingArrival(arrivals, route.id),
        null => null,
      },
      candidate: pickBoardedVehicle(
        network: network,
        leg: leg,
        fleet: <VehiclePosition>[
          for (final VehicleFrame frame in tracker.frameAt(
            now,
            interpolate: false,
          ))
            frame.vehicle,
        ],
        now: now,
      ),
    );
  }

  final VehiclePosition? vehicle = tracker.vehicleOf(vehicleId);
  final LegPath? path = legPath(network, leg, preferTripId: vehicle?.tripId);
  return RideOnBoard(
    itinerary: itinerary,
    legIndex: ride.legIndex,
    status: path == null
        ? null
        : rideStatus(path: path, vehicle: vehicle, now: now),
  );
}
