import 'package:freezed_annotation/freezed_annotation.dart';

import 'converters/gtfs_time_converter.dart';

part 'stop_time.freezed.dart';
part 'stop_time.g.dart';

/// Paso de un viaje por una parada, calcado de `stop_times.txt` de GTFS.
///
/// Las horas son [Duration] desde el inicio del día de servicio, no relojes:
/// GTFS admite `"25:30:00"` para viajes que cruzan la medianoche.
@freezed
abstract class StopTime with _$StopTime {
  const factory StopTime({
    @JsonKey(name: 'trip_id') required String tripId,
    @JsonKey(name: 'stop_id') required String stopId,
    @JsonKey(name: 'stop_sequence') required int stopSequence,
    @JsonKey(name: 'arrival_time')
    @GtfsTimeConverter()
    required Duration arrivalTime,
    @JsonKey(name: 'departure_time')
    @GtfsTimeConverter()
    required Duration departureTime,
  }) = _StopTime;

  factory StopTime.fromJson(Map<String, dynamic> json) =>
      _$StopTimeFromJson(json);
}
