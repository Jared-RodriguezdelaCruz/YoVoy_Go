import 'package:json_annotation/json_annotation.dart';

/// Hora de GTFS (`"HH:MM:SS"`) ↔ [Duration] desde el inicio del día de
/// servicio.
///
/// GTFS admite horas mayores o iguales a 24 —`"25:30:00"` es la 1:30 de la
/// madrugada siguiente, dentro del mismo día de servicio— y eso revienta
/// cualquier parseo que asuma un reloj de 24 horas. Por eso no se modela como
/// `DateTime` ni como `TimeOfDay`: se modela como desplazamiento.
class GtfsTimeConverter implements JsonConverter<Duration, String> {
  const GtfsTimeConverter();

  @override
  Duration fromJson(String json) {
    final List<String> parts = json.split(':');
    if (parts.length != 3) {
      throw FormatException('Hora GTFS inválida: "$json"');
    }
    return Duration(
      hours: int.parse(parts[0]),
      minutes: int.parse(parts[1]),
      seconds: int.parse(parts[2]),
    );
  }

  @override
  String toJson(Duration object) {
    final int totalSeconds = object.inSeconds;
    final String hours = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
    final String minutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(
      2,
      '0',
    );
    final String seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}

/// La misma hora, cuando el campo puede faltar.
class NullableGtfsTimeConverter implements JsonConverter<Duration?, String?> {
  const NullableGtfsTimeConverter();

  @override
  Duration? fromJson(String? json) =>
      json == null ? null : const GtfsTimeConverter().fromJson(json);

  @override
  String? toJson(Duration? object) =>
      object == null ? null : const GtfsTimeConverter().toJson(object);
}
