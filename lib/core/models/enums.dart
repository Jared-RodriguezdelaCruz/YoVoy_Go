/// Enumeraciones compartidas del modelo de datos.
///
/// Como en la sección 3 del spec (modelo de datos): los valores vienen de GTFS
/// y GTFS-Realtime, no se inventan. El JSON usa `snake_case`; el mapeo vive en
/// cada `@JsonValue`.
library;

import 'package:json_annotation/json_annotation.dart';

/// De dónde sale un ETA.
///
/// No confundir con `DataFreshness` de
/// `lib/core/config/freshness.dart`, que describe qué tan *viejo* es el dato.
/// Este describe su *origen*. Son ejes distintos: un horario programado puede
/// ser reciente, y una posición en vivo puede ser vieja.
enum EtaConfidence {
  /// Calculado desde la posición real de un vehículo.
  @JsonValue('live')
  live,

  /// Tomado del horario planificado, sin vehículo que lo confirme.
  @JsonValue('scheduled')
  scheduled,

  /// No hay base para dar un número. Es un estado válido y frecuente.
  @JsonValue('unknown')
  unknown,
}

/// Ocupación reportada por el vehículo.
///
/// Subconjunto de `OccupancyStatus` de GTFS-Realtime: los seis valores que la
/// UI sabe distinguir. Los grados intermedios del estándar se colapsan al más
/// cercano al leer el feed.
enum OccupancyStatus {
  @JsonValue('EMPTY')
  empty,
  @JsonValue('MANY_SEATS_AVAILABLE')
  manySeatsAvailable,
  @JsonValue('FEW_SEATS_AVAILABLE')
  fewSeatsAvailable,
  @JsonValue('STANDING_ROOM_ONLY')
  standingRoomOnly,
  @JsonValue('CRUSHED_STANDING_ROOM_ONLY')
  crushedStandingRoomOnly,
  @JsonValue('FULL')
  full,
}

/// Día de la semana de `calendar.txt`.
enum Weekday {
  @JsonValue('monday')
  monday,
  @JsonValue('tuesday')
  tuesday,
  @JsonValue('wednesday')
  wednesday,
  @JsonValue('thursday')
  thursday,
  @JsonValue('friday')
  friday,
  @JsonValue('saturday')
  saturday,
  @JsonValue('sunday')
  sunday,
}

/// Tipo de tramo de un itinerario, como en la sección 4.3 del spec.
enum LegType {
  @JsonValue('walk')
  walk,
  @JsonValue('bus')
  bus,
}

/// Accesibilidad de una parada, calcada de `wheelchair_boarding` de GTFS.
///
/// El valor `unknown` es el default del estándar y no significa "no
/// accesible": significa que nadie lo verificó. La UI los distingue.
enum WheelchairBoarding {
  @JsonValue(0)
  unknown,
  @JsonValue(1)
  accessible,
  @JsonValue(2)
  notAccessible,
}

/// Causa de una alerta de servicio (`Alert.Cause` de GTFS-Realtime).
enum AlertCause {
  @JsonValue('UNKNOWN_CAUSE')
  unknownCause,
  @JsonValue('TECHNICAL_PROBLEM')
  technicalProblem,
  @JsonValue('DEMONSTRATION')
  demonstration,
  @JsonValue('ACCIDENT')
  accident,
  @JsonValue('HOLIDAY')
  holiday,
  @JsonValue('WEATHER')
  weather,
  @JsonValue('MAINTENANCE')
  maintenance,
  @JsonValue('CONSTRUCTION')
  construction,
  @JsonValue('POLICE_ACTIVITY')
  policeActivity,
  @JsonValue('MEDICAL_EMERGENCY')
  medicalEmergency,
}

/// Efecto de una alerta de servicio (`Alert.Effect` de GTFS-Realtime).
enum AlertEffect {
  @JsonValue('NO_SERVICE')
  noService,
  @JsonValue('REDUCED_SERVICE')
  reducedService,
  @JsonValue('SIGNIFICANT_DELAYS')
  significantDelays,
  @JsonValue('DETOUR')
  detour,
  @JsonValue('ADDITIONAL_SERVICE')
  additionalService,
  @JsonValue('MODIFIED_SERVICE')
  modifiedService,
  @JsonValue('STOP_MOVED')
  stopMoved,
  @JsonValue('OTHER_EFFECT')
  otherEffect,
  @JsonValue('UNKNOWN_EFFECT')
  unknownEffect,
}
