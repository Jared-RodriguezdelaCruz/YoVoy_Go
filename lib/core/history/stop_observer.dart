import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../clock/clock_provider.dart';
import '../data/transit_network.dart';
import '../models/models.dart';
import '../transit/live_providers.dart';
import '../transit/vehicle_interpolator.dart';
import 'history_providers.dart';
import 'observation.dart';

part 'stop_observer.g.dart';

/// Vigila una parada abierta y anota si los camiones cumplieron.
///
/// Mientras el usuario mira una parada, la app ya está pidiendo sus arribos y
/// la flota: observar no cuesta una petición más. Cuando un camión prometido
/// rebasa la parada, la diferencia se guarda; si desaparece del feed, la
/// promesa se tira sin inventar nada.
///
/// Solo observa lo que está a la vista: en segundo plano el feed se suelta
/// (§7) y aquí no pasa nada. Es lento a propósito —cinco observaciones por
/// ruta y parada tardan— y por eso el panel del simulador puede sembrar un
/// historial de prueba en debug.
@riverpod
class StopObserver extends _$StopObserver {
  Map<String, Promise> _promises = <String, Promise>{};

  /// Cuántas observaciones lleva anotadas esta sesión. Es lo que miran los
  /// tests; la pantalla no lo usa.
  @override
  int build(String stopId) {
    // Se escucha, no se espera: el efecto va en el callback, que es donde
    // Riverpod permite tocar otro provider.
    ref.listen(stopArrivalsProvider(stopId), (
      AsyncValue<List<Arrival>>? previous,
      AsyncValue<List<Arrival>> next,
    ) {
      _tick(stopId);
    }, fireImmediately: true);
    ref.listen(vehicleFeedProvider, (
      AsyncValue<List<VehiclePosition>>? previous,
      AsyncValue<List<VehiclePosition>> next,
    ) {
      _tick(stopId);
    }, fireImmediately: true);
    ref.onDispose(_promises.clear);
    return 0;
  }

  void _tick(String stopId) {
    final TransitNetwork? network = ref.read(transitNetworkProvider).value;
    if (network == null) {
      return;
    }
    final DateTime now = ref.read(clockProvider)();
    final VehicleInterpolator tracker = ref.read(vehicleTrackerProvider);
    final List<Arrival> arrivals =
        ref.read(stopArrivalsProvider(stopId)).value ?? const <Arrival>[];

    _promises = promisesFrom(arrivals: arrivals, known: _promises, now: now);

    final List<StopSighting> sightings = <StopSighting>[
      for (final Promise promise in _promises.values)
        if (tracker.vehicleOf(promise.vehicleId) case final VehiclePosition v)
          if (sightingOf(
                vehicle: v,
                tripStops: network.stopsForTrip(v.tripId),
                stopId: stopId,
                now: now,
              )
              case final StopSighting sighting)
            sighting,
    ];

    final ({
      List<ArrivalObservation> observations,
      Map<String, Promise> pending,
    })
    settled = settlePromises(
      promises: _promises,
      sightings: sightings,
      stopId: stopId,
      now: now,
    );
    _promises = settled.pending;

    if (settled.observations.isNotEmpty) {
      state = state + settled.observations.length;
      unawaited(
        ref.read(arrivalHistoryProvider.notifier).record(settled.observations),
      );
    }
  }
}
