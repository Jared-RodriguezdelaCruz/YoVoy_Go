import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

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

/// De dónde sale lo observado. La fase 8 lo guarda en el teléfono; hasta
/// entonces no hay historial y la app calla.
abstract interface class ReliabilityHistory {
  Future<ReliabilityStat?> statFor({
    required String routeId,
    required String stopId,
  });
}

/// El historial de hoy: vacío.
class EmptyReliabilityHistory implements ReliabilityHistory {
  const EmptyReliabilityHistory();

  @override
  Future<ReliabilityStat?> statFor({
    required String routeId,
    required String stopId,
  }) async => null;
}

@Riverpod(keepAlive: true)
ReliabilityHistory reliabilityHistory(Ref ref) =>
    const EmptyReliabilityHistory();

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
