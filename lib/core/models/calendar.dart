import 'package:freezed_annotation/freezed_annotation.dart';

import 'converters/epoch_date_time_converter.dart';
import 'enums.dart';

part 'calendar.freezed.dart';
part 'calendar.g.dart';

/// Días en que corre un servicio, calcado de `calendar.txt` de GTFS.
@freezed
abstract class Calendar with _$Calendar {
  const factory Calendar({
    @JsonKey(name: 'service_id') required String serviceId,
    @Default(<Weekday>{}) Set<Weekday> days,
    @JsonKey(name: 'start_date')
    @GtfsDateConverter()
    required DateTime startDate,
    @JsonKey(name: 'end_date') @GtfsDateConverter() required DateTime endDate,
  }) = _Calendar;

  const Calendar._();

  factory Calendar.fromJson(Map<String, dynamic> json) =>
      _$CalendarFromJson(json);

  /// Si el servicio corre en [date].
  ///
  /// El orden de [Weekday] coincide con el de `DateTime.weekday`, que empieza
  /// en lunes = 1.
  bool runsOn(DateTime date) {
    final DateTime day = DateTime.utc(date.year, date.month, date.day);
    if (day.isBefore(startDate) || day.isAfter(endDate)) {
      return false;
    }
    return days.contains(Weekday.values[day.weekday - 1]);
  }
}
