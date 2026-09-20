import 'package:json_annotation/json_annotation.dart';

/// [DateTime] ↔ epoch en segundos, en UTC.
///
/// Es lo que manda GTFS-Realtime en `timestamp`. Se conserva en UTC a
/// propósito: el `timestamp` dice cuándo reportó el vehículo, y comparar eso
/// contra la hora local del teléfono es de donde salen los ETAs fantasma.
class EpochDateTimeConverter implements JsonConverter<DateTime, int> {
  const EpochDateTimeConverter();

  @override
  DateTime fromJson(int json) =>
      DateTime.fromMillisecondsSinceEpoch(json * 1000, isUtc: true);

  @override
  int toJson(DateTime object) => object.toUtc().millisecondsSinceEpoch ~/ 1000;
}

/// El mismo instante, cuando el campo puede faltar.
class NullableEpochDateTimeConverter implements JsonConverter<DateTime?, int?> {
  const NullableEpochDateTimeConverter();

  @override
  DateTime? fromJson(int? json) =>
      json == null ? null : const EpochDateTimeConverter().fromJson(json);

  @override
  int? toJson(DateTime? object) =>
      object == null ? null : const EpochDateTimeConverter().toJson(object);
}

/// Fecha sin hora en el formato de `calendar.txt` (`"YYYYMMDD"`).
class GtfsDateConverter implements JsonConverter<DateTime, String> {
  const GtfsDateConverter();

  @override
  DateTime fromJson(String json) {
    if (json.length != 8) {
      throw FormatException('Fecha GTFS inválida: "$json"');
    }
    return DateTime.utc(
      int.parse(json.substring(0, 4)),
      int.parse(json.substring(4, 6)),
      int.parse(json.substring(6, 8)),
    );
  }

  @override
  String toJson(DateTime object) {
    final DateTime utc = object.toUtc();
    final String month = utc.month.toString().padLeft(2, '0');
    final String day = utc.day.toString().padLeft(2, '0');
    return '${utc.year.toString().padLeft(4, '0')}$month$day';
  }
}
