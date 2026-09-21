import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/clock/clock_provider.dart';
import '../../../core/data/transit_repository.dart';
import '../../../core/data/transit_repository_provider.dart';
import '../../../core/lifecycle/app_lifecycle_provider.dart';
import '../../../core/location/location_service.dart';
import '../../../core/models/models.dart';
import 'leave_now.dart';
import 'search_index.dart';
import 'vehicle_interpolator.dart';

part 'map_providers.g.dart';

/// La red estática: rutas, viajes, trazos y paradas. Se pide una vez.
@Riverpod(keepAlive: true)
Future<TransitNetwork> transitNetwork(Ref ref) async {
  final TransitRepository repository = await ref.watch(
    transitRepositoryProvider.future,
  );
  return repository.getNetwork();
}

/// Las posiciones de toda la flota, cada 30 s.
///
/// **Con la app en segundo plano el stream se suelta** (sección 7, regla 8):
/// el provider se reconstruye, el generador anterior se cancela y con él la
/// suscripción al repositorio. Al volver, se suscribe de nuevo y la primera
/// emisión es inmediata.
@riverpod
Stream<List<VehiclePosition>> vehicleFeed(Ref ref) async* {
  if (!ref.watch(appInForegroundProvider)) {
    return;
  }
  final TransitRepository repository = await ref.watch(
    transitRepositoryProvider.future,
  );
  yield* repository.watchVehicles();
}

/// La flota ya lista para dibujarse: guarda de dónde viene y a dónde va cada
/// camión entre reportes.
///
/// Es un objeto mutable a propósito: lo leen la capa del mapa a 60 fps y la
/// hoja una vez por segundo, y ninguna de las dos debe reconstruirse cuando
/// llega un lote. Cada una lee cuando pinta.
@riverpod
VehicleInterpolator vehicleTracker(Ref ref) {
  final VehicleInterpolator tracker = VehicleInterpolator();
  final DateTime Function() now = ref.watch(clockProvider);
  ref.listen(vehicleFeedProvider, (
    AsyncValue<List<VehiclePosition>>? previous,
    AsyncValue<List<VehiclePosition>> next,
  ) {
    if (next case AsyncData<List<VehiclePosition>>(:final value)) {
      tracker.update(value, now());
    }
  }, fireImmediately: true);
  return tracker;
}

/// Lo que el usuario está mirando en el mapa.
sealed class MapSelection {
  const MapSelection();
}

final class NothingSelected extends MapSelection {
  const NothingSelected();
}

final class StopSelected extends MapSelection {
  const StopSelected(this.stopId);

  final String stopId;

  @override
  bool operator ==(Object other) =>
      other is StopSelected && other.stopId == stopId;

  @override
  int get hashCode => stopId.hashCode;
}

final class VehicleSelected extends MapSelection {
  const VehicleSelected({required this.vehicleId, required this.routeId});

  final String vehicleId;
  final String routeId;

  @override
  bool operator ==(Object other) =>
      other is VehicleSelected && other.vehicleId == vehicleId;

  @override
  int get hashCode => vehicleId.hashCode;
}

final class RouteSelected extends MapSelection {
  const RouteSelected(this.routeId);

  final String routeId;

  @override
  bool operator ==(Object other) =>
      other is RouteSelected && other.routeId == routeId;

  @override
  int get hashCode => routeId.hashCode;
}

extension MapSelectionRoute on MapSelection {
  /// La ruta que se enciende en el mapa, si hay una.
  String? get litRouteId => switch (this) {
    VehicleSelected(:final String routeId) => routeId,
    RouteSelected(:final String routeId) => routeId,
    _ => null,
  };
}

@riverpod
class MapSelectionState extends _$MapSelectionState {
  @override
  MapSelection build() => const NothingSelected();

  void select(MapSelection selection) => state = selection;

  void clear() => state = const NothingSelected();
}

/// Una parada cercana y a cuánto está, en línea recta.
@immutable
class NearbyStop {
  const NearbyStop({required this.stop, required this.meters});

  final Stop stop;
  final double meters;

  /// Lo que se tarda caminando, con el rodeo de las calles.
  Duration get walk => LeaveNow.walkTime(meters);
}

/// Radio de "cerca": unos ocho minutos a pie.
const double nearbyRadiusMeters = 600;

@riverpod
Future<List<NearbyStop>> nearbyStops(Ref ref) async {
  final UserLocation location = await ref.watch(userLocationProvider.future);
  final TransitRepository repository = await ref.watch(
    transitRepositoryProvider.future,
  );
  final List<Stop> stops = await repository.getStopsNear(
    location.position,
    radiusMeters: nearbyRadiusMeters,
  );
  const Distance distance = Distance();
  return <NearbyStop>[
    for (final Stop stop in stops.take(6))
      NearbyStop(
        stop: stop,
        meters: distance.as(LengthUnit.Meter, location.position, stop.position),
      ),
  ];
}

/// Cada cuánto se refrescan los arribos de una parada: la cadencia del feed.
const Duration arrivalsRefresh = Duration(seconds: 30);

/// Los arribos de una parada, refrescados cada 30 s mientras la app se vea.
@riverpod
Future<List<Arrival>> stopArrivals(Ref ref, String stopId) async {
  if (ref.watch(appInForegroundProvider)) {
    final Timer timer = Timer(arrivalsRefresh, ref.invalidateSelf);
    ref.onDispose(timer.cancel);
  }
  final TransitRepository repository = await ref.watch(
    transitRepositoryProvider.future,
  );
  return repository.getArrivals(stopId);
}

/// "¿Ya me voy?" para la parada más cercana. `null` si no hay parada cerca o
/// no pasa nada por ella.
@riverpod
Future<LeaveNowAdvice?> leaveNow(Ref ref) async {
  final List<NearbyStop> nearby = await ref.watch(nearbyStopsProvider.future);
  if (nearby.isEmpty) {
    return null;
  }
  final NearbyStop closest = nearby.first;
  final List<Arrival> arrivals = await ref.watch(
    stopArrivalsProvider(closest.stop.id).future,
  );
  if (arrivals.isEmpty) {
    return null;
  }
  // El primer camión que **sí** se alcanza caminando, de cualquier ruta. Que
  // el primero de la lista pase en 2 min no sirve si la parada está a 3.
  final Arrival? reachable = arrivals
      .where((Arrival a) => a.showsNumericEta && a.eta! >= closest.walk)
      .firstOrNull;
  final Arrival next = reachable ?? arrivals.first;
  return LeaveNow.advise(
    stopName: closest.stop.name,
    arrival: next,
    following: arrivals
        .skip(1)
        .where((Arrival a) => a.routeId == next.routeId)
        .firstOrNull,
    walk: closest.walk,
    now: ref.watch(clockProvider)(),
  );
}

@Riverpod(keepAlive: true)
Future<SearchIndex> searchIndex(Ref ref) async =>
    SearchIndex(await ref.watch(transitNetworkProvider.future));

@riverpod
class SearchQuery extends _$SearchQuery {
  @override
  String build() => '';

  void set(String query) => state = query;
}

@riverpod
List<SearchGroup> searchResults(Ref ref) {
  final String query = ref.watch(searchQueryProvider);
  final SearchIndex? index = ref.watch(searchIndexProvider).value;
  if (index == null || query.trim().isEmpty) {
    return const <SearchGroup>[];
  }
  return index.search(query);
}
