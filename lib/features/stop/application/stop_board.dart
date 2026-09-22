import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/clock/clock_provider.dart';
import '../../../core/data/not_found.dart';
import '../../../core/data/transit_network.dart';
import '../../../core/models/models.dart';
import '../../../core/transit/live_providers.dart';
import '../../../core/transit/vehicle_interpolator.dart';
import '../../route/application/vehicle_placement.dart';
import 'stop_providers.dart';

part 'stop_board.g.dart';

/// El tramo que le falta al camión para llegar: de la parada por la que va
/// hasta esta. Es lo que dibuja la tira del modo paradero.
@immutable
class ApproachStrip {
  const ApproachStrip({
    required this.stopNames,
    required this.progress,
    required this.dataAge,
  });

  /// Al menos dos: donde va el camión y esta parada, que es la última.
  final List<String> stopNames;

  /// Dónde va el camión sobre la tira, de 0 a 1.
  final double progress;

  /// Qué tan viejo es su reporte.
  final Duration dataAge;
}

/// Arma la tira de acercamiento de [vehicle] hacia [stopId].
///
/// Muestra a lo más [maxStops] paradas: en modo paradero importa lo que falta,
/// no el recorrido entero. Si el camión ya está en la parada, se dibuja al
/// final de la tira: es el "llegando". Devuelve `null` si ya pasó o si la
/// parada no está en su viaje: una tira que no termina aquí no responde nada.
ApproachStrip? approachStrip({
  required List<Stop> tripStops,
  required String stopId,
  required VehiclePosition vehicle,
  required DateTime now,
  int maxStops = 5,
}) {
  assert(maxStops >= 2, 'una tira necesita al menos dos paradas');
  final int target = tripStops.indexWhere((Stop s) => s.id == stopId);
  if (target <= 0) {
    return null;
  }
  final PlacedVehicle placed = placeVehicles(
    stops: tripStops,
    vehicles: <VehiclePosition>[vehicle],
    now: now,
  ).single;
  final int after = placed.afterIndex;
  if (after > target) {
    return null;
  }
  final int earliest = target - (maxStops - 1) < 0
      ? 0
      : target - (maxStops - 1);
  final int start = after > earliest && after < target ? after : earliest;
  final int span = target - start;
  if (after == target) {
    return ApproachStrip(
      stopNames: <String>[
        for (int i = start; i <= target; i++) tripStops[i].name,
      ],
      progress: 1,
      dataAge: placed.age,
    );
  }
  return ApproachStrip(
    stopNames: <String>[
      for (int i = start; i <= target; i++) tripStops[i].name,
    ],
    // Entre la parada por la que pasó y la siguiente, como en la tira de pie.
    // Si va antes del inicio de la tira, se dibuja en su arranque.
    progress: (((after - start) + 0.5) / span).clamp(0.0, 1.0),
    dataAge: placed.age,
  );
}

/// Lo que muestra el modo paradero.
@immutable
class StopBoard {
  const StopBoard({
    required this.stop,
    required this.lead,
    required this.following,
    required this.route,
    required this.strip,
  });

  final Stop stop;

  /// El camión protagonista: el primero con número en vivo, o si ninguno lo
  /// tiene, el primero de la lista. `null` si no pasa nada por aquí.
  final Arrival? lead;

  /// Los dos que siguen, en una línea chica.
  final List<Arrival> following;

  final TransitRoute? route;

  /// `null` cuando el protagonista es un horario o su camión ya no se ve.
  final ApproachStrip? strip;
}

/// Elige al protagonista de una lista de arribos ya ordenada.
///
/// Un horario ordena como "10 min" (media frecuencia), pero no es una
/// promesa: si hay un camión en vivo, el protagonista es ese.
Arrival? leadArrival(List<Arrival> arrivals) =>
    arrivals
        .where(
          (Arrival a) =>
              a.confidence == EtaConfidence.live && a.showsNumericEta,
        )
        .firstOrNull ??
    arrivals.firstOrNull;

@Riverpod(retry: retryUnlessNotFound)
Future<StopBoard> stopBoard(Ref ref, String stopId) async {
  // La flota primero: con cada lote la tira se vuelve a armar.
  final VehicleInterpolator tracker = ref.watch(vehicleTrackerProvider);
  ref.watch(vehicleFeedProvider);
  final DateTime now = ref.watch(clockProvider)();

  final Stop stop = await ref.watch(stopDetailProvider(stopId).future);
  final TransitNetwork network = await ref.watch(transitNetworkProvider.future);
  final List<Arrival> arrivals = await ref.watch(
    stopArrivalsProvider(stopId).future,
  );

  final Arrival? lead = leadArrival(arrivals);
  final VehiclePosition? vehicle = switch (lead?.vehicleId) {
    final String id => tracker.vehicleOf(id),
    null => null,
  };

  return StopBoard(
    stop: stop,
    lead: lead,
    following: arrivals
        .where((Arrival a) => !identical(a, lead))
        .take(2)
        .toList(growable: false),
    route: lead == null ? null : network.route(lead.routeId),
    strip: vehicle == null
        ? null
        : approachStrip(
            tripStops: network.stopsForTrip(vehicle.tripId),
            stopId: stopId,
            vehicle: vehicle,
            now: now,
          ),
  );
}
