import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../clock/clock_provider.dart';
import 'history_store.dart';
import 'observation.dart';

part 'history_providers.g.dart';

@Riverpod(keepAlive: true)
HistoryStore historyStore(Ref ref) => const SharedPreferencesHistoryStore();

/// Lo que la app prometió y cómo le fue.
///
/// `keepAlive`: es el historial del usuario, no una suscripción. Se lee del
/// disco una vez y se queda.
@Riverpod(keepAlive: true)
class ArrivalHistory extends _$ArrivalHistory {
  @override
  Future<List<ArrivalObservation>> build() =>
      ref.watch(historyStoreProvider).loadArrivals();

  /// Agrega lo observado. La nota de confiabilidad se recalcula sola.
  Future<void> record(List<ArrivalObservation> observations) async {
    if (observations.isEmpty) {
      return;
    }
    final List<ArrivalObservation> next = <ArrivalObservation>[
      ...await future,
      ...observations,
    ];
    state = AsyncData<List<ArrivalObservation>>(next);
    await ref.read(historyStoreProvider).saveArrivals(next);
  }
}

/// Lo que el usuario suele hacer, para "a esta hora sueles tomar".
@Riverpod(keepAlive: true)
class UsageLog extends _$UsageLog {
  @override
  Future<List<UseEvent>> build() => ref.watch(historyStoreProvider).loadUses();

  /// Registra que el usuario usó [stopId]. Lo llaman el detalle de parada, el
  /// modo paradero y el modo viaje.
  Future<void> record({
    required String stopId,
    required UseKind kind,
    String? routeId,
  }) async {
    final UseEvent event = UseEvent(
      stopId: stopId,
      routeId: routeId,
      kind: kind,
      at: ref.read(clockProvider)(),
    );
    final List<UseEvent> next = <UseEvent>[...await future, event];
    state = AsyncData<List<UseEvent>>(next);
    await ref.read(historyStoreProvider).saveUses(next);
  }
}

/// Las paradas que el usuario pidió no volver a ver sugeridas.
@Riverpod(keepAlive: true)
class HiddenSuggestions extends _$HiddenSuggestions {
  @override
  Future<Set<String>> build() => ref.watch(historyStoreProvider).loadHidden();

  Future<void> hide(String stopId) async {
    final Set<String> next = <String>{...await future, stopId};
    state = AsyncData<Set<String>>(next);
    await ref.read(historyStoreProvider).saveHidden(next);
  }
}

/// El botón de "borrar historial" de ajustes.
///
/// Se invalida cada notificador además de borrar el disco, para que la app se
/// olvide en el momento y no en el siguiente arranque.
@Riverpod(keepAlive: true)
class HistoryMaintenance extends _$HistoryMaintenance {
  @override
  void build() {}

  Future<void> clear() async {
    await ref.read(historyStoreProvider).clear();
    ref
      ..invalidate(arrivalHistoryProvider)
      ..invalidate(usageLogProvider)
      ..invalidate(hiddenSuggestionsProvider);
  }
}

/// Las paradas que se sugieren ahora mismo, ya sin las ocultas.
///
/// Vacía mientras el historial carga y vacía cuando no alcanza para sugerir:
/// la hoja del mapa no pinta la sección y nadie ve un hueco.
@riverpod
List<String> learnedStopIds(Ref ref) {
  final List<UseEvent> uses =
      ref.watch(usageLogProvider).value ?? const <UseEvent>[];
  final Set<String> hidden =
      ref.watch(hiddenSuggestionsProvider).value ?? const <String>{};
  return learnedStops(
    uses: uses,
    now: ref.watch(clockProvider)(),
    hidden: hidden,
  );
}
