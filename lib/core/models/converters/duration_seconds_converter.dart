import 'package:json_annotation/json_annotation.dart';

/// [Duration] ↔ entero de segundos.
///
/// Es la unidad con la que GTFS-Realtime reporta retrasos y la que usan los
/// campos de duración del dataset.
class DurationSecondsConverter implements JsonConverter<Duration, int> {
  const DurationSecondsConverter();

  @override
  Duration fromJson(int json) => Duration(seconds: json);

  @override
  int toJson(Duration object) => object.inSeconds;
}

/// La misma duración, cuando el campo puede faltar.
///
/// Un ETA nulo es un estado válido y frecuente, no un error de datos.
class NullableDurationSecondsConverter
    implements JsonConverter<Duration?, int?> {
  const NullableDurationSecondsConverter();

  @override
  Duration? fromJson(int? json) =>
      json == null ? null : Duration(seconds: json);

  @override
  int? toJson(Duration? object) => object?.inSeconds;
}
