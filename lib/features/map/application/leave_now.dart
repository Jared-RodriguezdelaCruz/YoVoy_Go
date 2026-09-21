import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../../core/config/freshness.dart';
import '../../../core/models/models.dart';

/// "¿Ya me voy?", la feature 1 de `FEATURES.md`.
///
/// Nadie quiere saber a qué hora llega el camión: quiere saber si ya tiene que
/// salir. Esto hace la resta que hoy el usuario hace de cabeza, y **se niega a
/// hacerla** cuando el dato no la sostiene.
sealed class LeaveNowAdvice {
  const LeaveNowAdvice({
    required this.stopName,
    required this.routeShortName,
    required this.walk,
  });

  final String stopName;
  final String routeShortName;

  /// Lo que se tarda en llegar a pie a la parada.
  final Duration walk;

  /// La línea grande de la tarjeta.
  String get headline;

  /// De dónde sale el cálculo, en chico. Siempre visible: un consejo sin su
  /// cuenta no se puede verificar.
  String get detail;

  String get _walkPart => '${_minutes(walk)} min a pie a $stopName';

  /// ¿Esta tarjeta puede usar una cuenta regresiva? Solo con dato en vivo.
  bool get isCountdown => this is LeaveIn || this is LeaveRightNow;
}

/// Alcanzas con margen.
final class LeaveIn extends LeaveNowAdvice {
  const LeaveIn({
    required super.stopName,
    required super.routeShortName,
    required super.walk,
    required this.leaveIn,
    required this.eta,
  });

  final Duration leaveIn;
  final Duration eta;

  /// Hacia abajo, a propósito: redondear hacia arriba le diría a la gente que
  /// salga tarde.
  @override
  String get headline => 'Sal en ${leaveIn.inMinutes} min';

  @override
  String get detail =>
      '$_walkPart · $routeShortName llega en ${_minutes(eta)} min';
}

/// Justo: si sales ahora, alcanzas.
final class LeaveRightNow extends LeaveNowAdvice {
  const LeaveRightNow({
    required super.stopName,
    required super.routeShortName,
    required super.walk,
    required this.eta,
  });

  final Duration eta;

  @override
  String get headline => 'Sal ya';

  @override
  String get detail =>
      '$_walkPart · $routeShortName llega en ${_minutes(eta)} min';
}

/// Ya no alcanzas este. Se dice cuál sigue, si se sabe.
final class TooLate extends LeaveNowAdvice {
  const TooLate({
    required super.stopName,
    required super.routeShortName,
    required super.walk,
    this.nextEta,
  });

  final Duration? nextEta;

  @override
  String get headline {
    final Duration? next = nextEta;
    return next == null
        ? 'Vas tarde'
        : 'Vas tarde. El siguiente, en ${_minutes(next)} min';
  }

  @override
  String get detail => _walkPart;
}

/// Solo hay horario: se da una hora de reloj, **nunca** una cuenta regresiva.
final class LeaveBySchedule extends LeaveNowAdvice {
  const LeaveBySchedule({
    required super.stopName,
    required super.routeShortName,
    required super.walk,
    required this.leaveAt,
  });

  final DateTime leaveAt;

  @override
  String get headline =>
      'Sal ${DateFormat('H:mm').format(leaveAt)} para el horario';

  @override
  String get detail => '$_walkPart · $routeShortName según horario';
}

/// Sin dato: no hay cuenta que hacer, y se dice así.
final class NoSignal extends LeaveNowAdvice {
  const NoSignal({
    required super.stopName,
    required super.routeShortName,
    required super.walk,
  });

  @override
  String get headline => 'Sin señal de la $routeShortName';

  @override
  String get detail => _walkPart;
}

/// La cuenta.
abstract final class LeaveNow {
  /// 4.5 km/h, la velocidad a pie que fija `FEATURES.md`.
  static const double walkMetersPerSecond = 4.5 / 3.6;

  /// Las calles no van en línea recta. Un 30 % de más sobre la distancia en
  /// línea recta es el rodeo típico de una retícula urbana.
  static const double detourFactor = 1.3;

  /// Holgura por omisión. Será configurable en ajustes (fase 8).
  static const Duration defaultMargin = Duration(minutes: 1);

  /// Cuánto se camina [straightMeters] en línea recta, con el rodeo.
  static Duration walkTime(double straightMeters) => Duration(
    seconds: (straightMeters * detourFactor / walkMetersPerSecond).round(),
  );

  static LeaveNowAdvice advise({
    required String stopName,
    required Arrival arrival,
    required Duration walk,
    required DateTime now,
    Arrival? following,
    Duration margin = defaultMargin,
  }) {
    final String route = arrival.routeShortName;
    final Duration? eta = arrival.eta;

    // La regla que hace confiable esta tarjeta: con dato vencido o sin ETA no
    // hay resta que valga.
    if (eta == null ||
        arrival.confidence == EtaConfidence.unknown ||
        Freshness.classify(arrival.dataAge) == DataFreshness.unknown) {
      return NoSignal(stopName: stopName, routeShortName: route, walk: walk);
    }

    final Duration slack = eta - walk;

    if (arrival.confidence == EtaConfidence.scheduled) {
      final Duration lead = slack - margin;
      return LeaveBySchedule(
        stopName: stopName,
        routeShortName: route,
        walk: walk,
        leaveAt: now.add(lead.isNegative ? Duration.zero : lead),
      );
    }

    if (slack.isNegative) {
      final Duration? next = following != null && following.showsNumericEta
          ? following.eta
          : null;
      return TooLate(
        stopName: stopName,
        routeShortName: route,
        walk: walk,
        nextEta: next,
      );
    }

    final Duration leaveIn = slack - margin;
    if (leaveIn < const Duration(minutes: 1)) {
      return LeaveRightNow(
        stopName: stopName,
        routeShortName: route,
        walk: walk,
        eta: eta,
      );
    }
    return LeaveIn(
      stopName: stopName,
      routeShortName: route,
      walk: walk,
      leaveIn: leaveIn,
      eta: eta,
    );
  }
}

/// Minutos redondeados hacia arriba, nunca cero: "0 min a pie" no ayuda.
int _minutes(Duration duration) {
  final int seconds = duration.inSeconds;
  if (seconds <= 60) {
    return 1;
  }
  return (seconds / 60).ceil();
}

@visibleForTesting
int roundedMinutes(Duration duration) => _minutes(duration);
