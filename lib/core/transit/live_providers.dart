import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../clock/clock_provider.dart';
import '../data/transit_repository.dart';
import '../data/transit_repository_provider.dart';
import '../lifecycle/app_lifecycle_provider.dart';
import '../models/models.dart';
import 'vehicle_interpolator.dart';

part 'live_providers.g.dart';

// Los providers que comparten el mapa, la parada y la ruta. Nacieron en la
// fase 5 dentro del mapa; en la fase 6 dos pantallas más los necesitaron.

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

/// Las alertas de servicio vigentes. Se suelta en segundo plano, como la
/// flota.
@riverpod
Stream<List<ServiceAlert>> activeAlerts(Ref ref) async* {
  if (!ref.watch(appInForegroundProvider)) {
    return;
  }
  final TransitRepository repository = await ref.watch(
    transitRepositoryProvider.future,
  );
  yield* repository.watchAlerts();
}
