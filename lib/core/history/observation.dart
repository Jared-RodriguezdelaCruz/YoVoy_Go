/// Lo que este teléfono ha visto, sin nada que salga de él.
///
/// Dos historias distintas comparten archivo porque nacen del mismo principio
/// y se borran juntas: lo que la app prometió y cómo le fue (la confiabilidad
/// observada, feature 4 de `FEATURES.md`), y lo que el usuario suele hacer a
/// cierta hora (mis rutas aprendidas, feature 2).
///
/// Todo aquí es función pura con la hora recibida: quien la llama decide qué
/// hora es, y los tests la fijan.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../config/freshness.dart';
import '../models/models.dart';

/// Qué clase de día es. El martes y el jueves se parecen; el domingo no se
/// parece a ninguno de los dos.
enum DayKind {
  weekday('L'),
  saturday('S'),
  sunday('D');

  const DayKind(this.code);

  /// Una letra, porque esto se guarda en disco miles de veces.
  final String code;

  static DayKind of(DateTime at) => switch (at.weekday) {
    DateTime.saturday => DayKind.saturday,
    DateTime.sunday => DayKind.sunday,
    _ => DayKind.weekday,
  };

  static DayKind? fromCode(String code) =>
      DayKind.values.where((DayKind kind) => kind.code == code).firstOrNull;
}

/// Una franja de dos horas de cierta clase de día: "martes a las 7" y "jueves
/// a las 7:40" caen en la misma.
///
/// Dos horas es el grano más fino que aguanta el historial de un teléfono: con
/// franjas de media hora nunca se juntarían las cinco observaciones que pide
/// `ReliabilityCopy.minObservations` para abrir la boca.
@immutable
class TimeBand {
  const TimeBand({required this.dayKind, required this.slot});

  factory TimeBand.of(DateTime at) =>
      TimeBand(dayKind: DayKind.of(at), slot: at.hour ~/ hoursPerSlot);

  /// Cuántas horas abarca una franja.
  static const int hoursPerSlot = 2;

  /// Cuántas franjas tiene un día.
  static const int slotsPerDay = 24 ~/ hoursPerSlot;

  final DayKind dayKind;

  /// De 0 (medianoche a las 2) a 11 (10 de la noche a medianoche).
  final int slot;

  /// Cómo se guarda: `L3` es "día laboral, de 6 a 8".
  String get code => '${dayKind.code}$slot';

  static TimeBand? parse(String code) {
    if (code.length < 2) {
      return null;
    }
    final DayKind? kind = DayKind.fromCode(code[0]);
    final int? slot = int.tryParse(code.substring(1));
    if (kind == null || slot == null || slot < 0 || slot >= slotsPerDay) {
      return null;
    }
    return TimeBand(dayKind: kind, slot: slot);
  }

  /// Si [other] es la franja de al lado. Quien sale a las 7:55 un día y a las
  /// 8:05 el otro hace lo mismo, aunque el reloj lo parta en dos.
  bool isNeighbour(TimeBand other) {
    final int distance = (slot - other.slot).abs();
    return distance == 1 || distance == slotsPerDay - 1;
  }

  @override
  bool operator ==(Object other) =>
      other is TimeBand && other.dayKind == dayKind && other.slot == slot;

  @override
  int get hashCode => Object.hash(dayKind, slot);

  @override
  String toString() => 'TimeBand($code)';
}

/// Qué hizo el usuario. No todo pesa igual: abrir una parada es curiosidad,
/// subirse a un camión es un viaje.
enum UseKind {
  detail('d', 1),
  board('b', 1.5),
  ride('r', 2);

  const UseKind(this.code, this.weight);

  final String code;

  /// Cuánto suma este evento al puntaje de lo aprendido.
  final double weight;

  static UseKind? fromCode(String code) =>
      UseKind.values.where((UseKind kind) => kind.code == code).firstOrNull;
}

/// "El usuario usó esta parada a esta hora."
@immutable
class UseEvent {
  const UseEvent({
    required this.stopId,
    required this.kind,
    required this.at,
    this.routeId,
  });

  final String stopId;
  final String? routeId;
  final UseKind kind;
  final DateTime at;

  TimeBand get band => TimeBand.of(at);

  String encode() => <String>[
    stopId,
    routeId ?? '',
    kind.code,
    '${at.millisecondsSinceEpoch}',
  ].join('|');

  static UseEvent? decode(String line) {
    final List<String> parts = line.split('|');
    if (parts.length != 4) {
      return null;
    }
    final UseKind? kind = UseKind.fromCode(parts[2]);
    final int? millis = int.tryParse(parts[3]);
    if (parts[0].isEmpty || kind == null || millis == null) {
      return null;
    }
    return UseEvent(
      stopId: parts[0],
      routeId: parts[1].isEmpty ? null : parts[1],
      kind: kind,
      at: DateTime.fromMillisecondsSinceEpoch(millis),
    );
  }
}

/// "La app dijo que el camión llegaba a tal hora, y pasó a tal otra."
///
/// [delay] es "pasó menos prometido": positivo es tarde, igual que en
/// `ReliabilityStat`.
@immutable
class ArrivalObservation {
  const ArrivalObservation({
    required this.routeId,
    required this.stopId,
    required this.band,
    required this.delay,
    required this.at,
  });

  final String routeId;
  final String stopId;
  final TimeBand band;
  final Duration delay;
  final DateTime at;

  String encode() => <String>[
    routeId,
    stopId,
    band.code,
    '${delay.inSeconds}',
    '${at.millisecondsSinceEpoch}',
  ].join('|');

  static ArrivalObservation? decode(String line) {
    final List<String> parts = line.split('|');
    if (parts.length != 5) {
      return null;
    }
    final TimeBand? band = TimeBand.parse(parts[2]);
    final int? seconds = int.tryParse(parts[3]);
    final int? millis = int.tryParse(parts[4]);
    if (parts[0].isEmpty ||
        parts[1].isEmpty ||
        band == null ||
        seconds == null ||
        millis == null) {
      return null;
    }
    return ArrivalObservation(
      routeId: parts[0],
      stopId: parts[1],
      band: band,
      delay: Duration(seconds: seconds),
      at: DateTime.fromMillisecondsSinceEpoch(millis),
    );
  }
}

/// Una promesa viva: la app dijo que este camión llegaba a [promisedAt] y
/// todavía no se sabe si cumplió.
@immutable
class Promise {
  const Promise({
    required this.vehicleId,
    required this.routeId,
    required this.promisedAt,
    required this.madeAt,
    required this.lastSeenAt,
  });

  final String vehicleId;
  final String routeId;

  /// La hora que la app prometió. **No se reescribe**: si se actualizara con
  /// cada refresco, la promesa siempre se cumpliría y la nota sería un adorno.
  final DateTime promisedAt;

  final DateTime madeAt;

  /// La última vez que se vio reportar a este camión. Sin él, la promesa
  /// caduca sin observación: eso es señal perdida, no un camión tarde.
  final DateTime lastSeenAt;

  Promise seenAt(DateTime now) => Promise(
    vehicleId: vehicleId,
    routeId: routeId,
    promisedAt: promisedAt,
    madeAt: madeAt,
    lastSeenAt: now,
  );
}

/// Lo que se sabe de un camión respecto de **una** parada, en este instante.
@immutable
class StopSighting {
  const StopSighting({
    required this.vehicleId,
    required this.passed,
    required this.age,
  });

  final String vehicleId;

  /// Si su última posición ya rebasó la parada.
  final bool passed;

  /// Qué tan viejo es ese reporte.
  final Duration age;

  /// Un reporte de más de [Freshness.staleMax] no fecha nada.
  bool get isFresh => Freshness.classify(age) != DataFreshness.unknown;
}

/// Qué se sabe de [vehicle] respecto de [stopId], o `null` si no hay cómo
/// saberlo.
///
/// Sin `current_stop_sequence` no se juzga a nadie: la parada más cercana en
/// línea recta alcanza para dibujar un camión en el mapa, pero no para decidir
/// que ya pasó y fechar una observación que se guarda.
StopSighting? sightingOf({
  required VehiclePosition vehicle,
  required List<Stop> tripStops,
  required String stopId,
  required DateTime now,
}) {
  final int sequence = vehicle.currentStopSequence ?? -1;
  final int target = tripStops.indexWhere((Stop stop) => stop.id == stopId);
  if (sequence < 1 || target < 0) {
    return null;
  }
  return StopSighting(
    vehicleId: vehicle.vehicleId,
    // `current_stop_sequence` cuenta desde 1: la parada por la que va.
    passed: (sequence - 1) > target,
    age: vehicle.ageAt(now),
  );
}

/// Debajo de este adelanto no se promete nada: decir "llega en 30 segundos" y
/// acertar no demuestra puntualidad.
const Duration minPromiseLead = Duration(minutes: 2);

/// Sin reportes por este tiempo, la promesa se tira sin observación.
const Duration promiseForgetAfter = Freshness.staleMax;

/// Las promesas que la app hace con [arrivals], sumadas a las que ya había.
///
/// Solo prometen los arribos en vivo con número y con camión: un horario dice
/// "cada 20 min", que no es una promesa que se pueda incumplir. Una promesa ya
/// hecha se conserva tal cual.
Map<String, Promise> promisesFrom({
  required List<Arrival> arrivals,
  required Map<String, Promise> known,
  required DateTime now,
}) {
  final Map<String, Promise> next = <String, Promise>{...known};
  for (final Arrival arrival in arrivals) {
    final String? vehicleId = arrival.vehicleId;
    final Duration? eta = arrival.eta;
    if (vehicleId == null ||
        eta == null ||
        eta < minPromiseLead ||
        arrival.confidence != EtaConfidence.live ||
        !arrival.showsNumericEta ||
        next.containsKey(vehicleId)) {
      continue;
    }
    next[vehicleId] = Promise(
      vehicleId: vehicleId,
      routeId: arrival.routeId,
      promisedAt: now.add(eta),
      madeAt: now,
      lastSeenAt: now,
    );
  }
  return next;
}

/// Cierra las promesas que ya se pueden juzgar.
///
/// Devuelve lo observado y las promesas que siguen vivas. Una promesa se cierra
/// cuando su camión **pasó** la parada con un reporte fresco; se tira cuando
/// lleva [promiseForgetAfter] sin reportar. Nunca se inventa una observación
/// con un dato viejo: es el mismo criterio del ETA numérico.
({List<ArrivalObservation> observations, Map<String, Promise> pending})
settlePromises({
  required Map<String, Promise> promises,
  required List<StopSighting> sightings,
  required String stopId,
  required DateTime now,
}) {
  final Map<String, StopSighting> byVehicle = <String, StopSighting>{
    for (final StopSighting sighting in sightings) sighting.vehicleId: sighting,
  };
  final List<ArrivalObservation> observations = <ArrivalObservation>[];
  final Map<String, Promise> pending = <String, Promise>{};

  for (final Promise promise in promises.values) {
    final StopSighting? sighting = byVehicle[promise.vehicleId];
    if (sighting == null || !sighting.isFresh) {
      if (now.difference(promise.lastSeenAt) < promiseForgetAfter) {
        pending[promise.vehicleId] = promise;
      }
      continue;
    }
    if (!sighting.passed) {
      pending[promise.vehicleId] = promise.seenAt(now);
      continue;
    }
    observations.add(
      ArrivalObservation(
        routeId: promise.routeId,
        stopId: stopId,
        band: TimeBand.of(promise.promisedAt),
        delay: now.difference(promise.promisedAt),
        at: now,
      ),
    );
  }

  return (observations: observations, pending: pending);
}

/// Cuánto pesa hoy algo que pasó hace [age]: la mitad cada dos semanas.
///
/// Lo de hace un mes cuenta un cuarto de lo de hoy. Sin decaimiento, una racha
/// vieja seguiría mandando en la hoja para siempre.
double recencyWeight(Duration age) =>
    math.pow(0.5, age.inMinutes / learnedHalfLife.inMinutes).toDouble();

/// Vida media del historial de uso.
const Duration learnedHalfLife = Duration(days: 14);

/// Debajo de este puntaje no se sugiere nada. Equivale a un par de usos
/// recientes en la misma franja: con menos, sería adivinar en voz alta.
const double learnedThreshold = 1.8;

/// El puntaje de una parada para [now], según lo que se hizo en ella.
double learnedScore({
  required List<UseEvent> uses,
  required DateTime now,
  required String stopId,
}) {
  final TimeBand band = TimeBand.of(now);
  double score = 0;
  for (final UseEvent use in uses) {
    if (use.stopId != stopId || use.at.isAfter(now)) {
      continue;
    }
    final TimeBand used = use.band;
    final double byBand = used.slot == band.slot
        ? 1
        : used.isNeighbour(band)
        ? 0.5
        : 0.15;
    final double byDay = used.dayKind == band.dayKind ? 1 : 0.4;
    score +=
        use.kind.weight *
        byBand *
        byDay *
        recencyWeight(now.difference(use.at));
  }
  return score;
}

/// Las paradas que el usuario suele tomar a esta hora, de mayor a menor.
///
/// Devuelve a lo más [max] y nunca las [hidden]: lo aprendido se puede callar
/// con un toque. Con poco historial devuelve una lista vacía, y la hoja del
/// mapa no muestra la sección: el silencio es preferible a adivinar.
List<String> learnedStops({
  required List<UseEvent> uses,
  required DateTime now,
  Set<String> hidden = const <String>{},
  int max = 3,
}) {
  final Map<String, double> scores = <String, double>{};
  for (final String stopId in uses.map((UseEvent use) => use.stopId).toSet()) {
    if (hidden.contains(stopId)) {
      continue;
    }
    final double score = learnedScore(uses: uses, now: now, stopId: stopId);
    if (score >= learnedThreshold) {
      scores[stopId] = score;
    }
  }
  final List<String> ranked = scores.keys.toList()
    ..sort((String a, String b) => scores[b]!.compareTo(scores[a]!));
  return ranked.take(max).toList(growable: false);
}
