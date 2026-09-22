import 'package:flutter/foundation.dart';

/// Los parámetros con los que el simulador se porta mal.
///
/// Son los de la sección 4.2 del spec, uno por uno. Existen como objeto y no
/// como constantes para que el panel de `/debug/simulator` pueda moverlos en
/// vivo: **un mock de datos perfectos produce una UI que se rompe en
/// producción**, así que hay que poder empujar la app a su peor caso a mano.
@immutable
class SimulatorConfig {
  const SimulatorConfig({
    this.seed = 20260920,
    this.reportInterval = const Duration(seconds: 30),
    this.minSpeedKmh = 20,
    this.maxSpeedKmh = 40,
    this.minDwell = const Duration(seconds: 15),
    this.maxDwell = const Duration(seconds: 30),
    this.gpsNoiseMinMeters = 5,
    this.gpsNoiseMaxMeters = 20,
    this.signalLossRate = 0.10,
    this.minSignalLoss = const Duration(minutes: 1),
    this.maxSignalLoss = const Duration(minutes: 3),
    this.missingBearingRate = 0.15,
    this.missingOccupancyRate = 0.25,
    this.minLatency = const Duration(milliseconds: 200),
    this.maxLatency = const Duration(milliseconds: 1500),
    this.errorRate = 0.05,
  });

  /// El simulador sin ninguna falla.
  ///
  /// No es "el modo bueno": es el modo con el que se prueba otra cosa. Una UI
  /// que solo se ve bien así está mal.
  static const SimulatorConfig perfect = SimulatorConfig(
    gpsNoiseMinMeters: 0,
    gpsNoiseMaxMeters: 0,
    signalLossRate: 0,
    missingBearingRate: 0,
    missingOccupancyRate: 0,
    minLatency: Duration.zero,
    maxLatency: Duration.zero,
    errorRate: 0,
  );

  /// El peor caso razonable, el de la lista de cierre del roadmap.
  static const SimulatorConfig hostile = SimulatorConfig(
    signalLossRate: 0.35,
    missingBearingRate: 0.40,
    missingOccupancyRate: 0.60,
    minLatency: Duration(milliseconds: 1200),
    maxLatency: Duration(seconds: 4),
    errorRate: 0.20,
  );

  /// Semilla del generador. Con la misma semilla el simulador es determinista,
  /// que es lo que permite que un test afirme una posición exacta.
  final int seed;

  /// Cada cuánto reporta un vehículo. **30 s**, que es la cadencia real del
  /// sistema: obliga a la UI a interpolar en vez de recibir la verdad cada
  /// frame.
  final Duration reportInterval;

  final double minSpeedKmh;
  final double maxSpeedKmh;

  /// Lo que se detiene en cada parada.
  final Duration minDwell;
  final Duration maxDwell;

  /// Desplazamiento perpendicular al trazo, en metros.
  final double gpsNoiseMinMeters;
  final double gpsNoiseMaxMeters;

  /// Proporción de vehículos que desaparecen un rato y reaparecen adelantados.
  final double signalLossRate;
  final Duration minSignalLoss;
  final Duration maxSignalLoss;

  /// Proporción de reportes que llegan sin `bearing`. El marcador degrada a
  /// círculo, no a una flecha apuntando al norte.
  final double missingBearingRate;

  /// Proporción de reportes que llegan sin ocupación. Los feeds reales la
  /// omiten seguido, y la UI tiene que verse bien sin ella.
  final double missingOccupancyRate;

  final Duration minLatency;
  final Duration maxLatency;

  /// Proporción de llamadas que lanzan excepción.
  final double errorRate;

  SimulatorConfig copyWith({
    int? seed,
    Duration? reportInterval,
    double? minSpeedKmh,
    double? maxSpeedKmh,
    Duration? minDwell,
    Duration? maxDwell,
    double? gpsNoiseMinMeters,
    double? gpsNoiseMaxMeters,
    double? signalLossRate,
    Duration? minSignalLoss,
    Duration? maxSignalLoss,
    double? missingBearingRate,
    double? missingOccupancyRate,
    Duration? minLatency,
    Duration? maxLatency,
    double? errorRate,
  }) {
    return SimulatorConfig(
      seed: seed ?? this.seed,
      reportInterval: reportInterval ?? this.reportInterval,
      minSpeedKmh: minSpeedKmh ?? this.minSpeedKmh,
      maxSpeedKmh: maxSpeedKmh ?? this.maxSpeedKmh,
      minDwell: minDwell ?? this.minDwell,
      maxDwell: maxDwell ?? this.maxDwell,
      gpsNoiseMinMeters: gpsNoiseMinMeters ?? this.gpsNoiseMinMeters,
      gpsNoiseMaxMeters: gpsNoiseMaxMeters ?? this.gpsNoiseMaxMeters,
      signalLossRate: signalLossRate ?? this.signalLossRate,
      minSignalLoss: minSignalLoss ?? this.minSignalLoss,
      maxSignalLoss: maxSignalLoss ?? this.maxSignalLoss,
      missingBearingRate: missingBearingRate ?? this.missingBearingRate,
      missingOccupancyRate: missingOccupancyRate ?? this.missingOccupancyRate,
      minLatency: minLatency ?? this.minLatency,
      maxLatency: maxLatency ?? this.maxLatency,
      errorRate: errorRate ?? this.errorRate,
    );
  }
}

/// La excepción que lanza el repositorio simulado.
///
/// Tiene tipo propio para que la UI pueda distinguir "falló la red" de "el
/// código tiene un bug", que se ven igual en un `catch` genérico.
class TransitDataException implements Exception {
  const TransitDataException(this.message);

  final String message;

  @override
  String toString() => 'TransitDataException: $message';
}
