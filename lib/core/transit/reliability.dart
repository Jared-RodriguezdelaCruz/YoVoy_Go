import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../history/history_providers.dart';
import '../history/observation.dart';

part 'reliability.g.dart';

/// Qué tan puntual ha sido una ruta en una parada, según lo que vio **este
/// teléfono**.
///
/// Las diferencias son "llegó menos prometió": positivo es tarde. No es un
/// promedio porque un camión que una vez llegó 40 min tarde no debe hacer que
/// todos los demás parezcan tarde.
@immutable
class ReliabilityStat {
  const ReliabilityStat({
    required this.observations,
    required this.medianDelay,
    required this.p10,
    required this.p90,
  });

  final int observations;
  final Duration medianDelay;
  final Duration p10;
  final Duration p90;
}

/// Cómo se dice la confiabilidad, o si mejor no se dice.
abstract final class ReliabilityCopy {
  /// Con menos observaciones que esto, la nota calla.
  static const int minObservations = 5;

  /// Por encima de este ancho entre el p10 y el p90 no se da un solo número:
  /// se admite que la ruta es irregular.
  static const Duration irregularSpread = Duration(minutes: 6);

  /// "suele llegar 3 min tarde · según 14 observaciones tuyas", o `null`.
  ///
  /// El silencio es preferible a un dato débil presentado como fuerte.
  static String? describe(ReliabilityStat? stat) {
    if (stat == null || stat.observations < minObservations) {
      return null;
    }
    final String source = 'según ${stat.observations} observaciones tuyas';
    if (stat.p90 - stat.p10 > irregularSpread) {
      final int low = (stat.p10.inSeconds / 60).round();
      final int high = (stat.p90.inSeconds / 60).round();
      // "entre 2 y 11 min tarde" cuando los dos extremos son tarde; si uno es
      // adelanto, cada extremo lleva su palabra.
      final String range = low > 0
          ? 'entre $low y $high min tarde'
          : 'entre ${_offset(stat.p10)} y ${_offset(stat.p90)}';
      return 'irregular, $range · $source';
    }
    final int minutes = (stat.medianDelay.inSeconds / 60).round();
    final String usual = minutes == 0
        ? 'suele llegar a tiempo'
        : 'suele llegar ${_offset(stat.medianDelay)}';
    return '$usual · $source';
  }

  /// "3 min tarde" · "2 min antes" · "a tiempo".
  static String _offset(Duration delay) {
    final int minutes = (delay.inSeconds / 60).round();
    if (minutes == 0) {
      return 'a tiempo';
    }
    return minutes > 0 ? '$minutes min tarde' : '${-minutes} min antes';
  }
}

/// El resumen de una lista de diferencias, o `null` si no hay ninguna.
///
/// Mediana y percentiles por rango más cercano, no promedio: un camión que una
/// vez llegó 40 min tarde no debe hacer que todos los demás parezcan tarde.
/// Quién calla con pocas observaciones es [ReliabilityCopy], no esto.
ReliabilityStat? statFrom(List<Duration> delays) {
  if (delays.isEmpty) {
    return null;
  }
  final List<Duration> sorted = <Duration>[...delays]..sort();
  // Rango más cercano: el p90 de nueve observaciones es la novena, no un
  // promedio entre dos. Así el peor caso se ve en vez de suavizarse.
  Duration percentile(double fraction) {
    final int rank = (fraction * sorted.length).ceil() - 1;
    return sorted[rank.clamp(0, sorted.length - 1)];
  }

  return ReliabilityStat(
    observations: sorted.length,
    medianDelay: percentile(0.5),
    p10: percentile(0.1),
    p90: percentile(0.9),
  );
}

/// De dónde sale lo observado. Lo llena el historial local de la fase 8, que
/// no sale del teléfono.
abstract interface class ReliabilityHistory {
  Future<ReliabilityStat?> statFor({
    required String routeId,
    required String stopId,
  });
}

/// Sin historial: la app calla. Es lo que ven los tests que no traen uno.
class EmptyReliabilityHistory implements ReliabilityHistory {
  const EmptyReliabilityHistory();

  @override
  Future<ReliabilityStat?> statFor({
    required String routeId,
    required String stopId,
  }) async => null;
}

/// Lo que este teléfono vio, agrupado por ruta y parada.
///
/// La franja horaria se guarda en cada observación pero **no** parte el
/// cálculo: con cinco observaciones mínimas, partir por franja dejaría a la
/// nota callada para siempre. La franja está ahí para cuando el historial dé
/// para tanto.
class LocalReliabilityHistory implements ReliabilityHistory {
  const LocalReliabilityHistory(this.observations);

  final List<ArrivalObservation> observations;

  @override
  Future<ReliabilityStat?> statFor({
    required String routeId,
    required String stopId,
  }) async => statFrom(<Duration>[
    for (final ArrivalObservation observation in observations)
      if (observation.routeId == routeId && observation.stopId == stopId)
        observation.delay,
  ]);
}

@Riverpod(keepAlive: true)
ReliabilityHistory reliabilityHistory(Ref ref) => LocalReliabilityHistory(
  // Mientras el disco responde no hay nota, que es lo mismo que decir "todavía
  // no sé": se enciende sola cuando el historial llega.
  ref.watch(arrivalHistoryProvider).value ?? const <ArrivalObservation>[],
);

/// La nota lista para pintarse, o `null` si no hay nada que valga la pena
/// decir.
@riverpod
Future<String?> reliabilityNote(
  Ref ref, {
  required String routeId,
  required String stopId,
}) async {
  final ReliabilityHistory history = ref.watch(reliabilityHistoryProvider);
  return ReliabilityCopy.describe(
    await history.statFor(routeId: routeId, stopId: stopId),
  );
}
