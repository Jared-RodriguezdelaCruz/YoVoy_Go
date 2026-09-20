import 'package:freezed_annotation/freezed_annotation.dart';

import 'converters/duration_seconds_converter.dart';
import 'converters/epoch_date_time_converter.dart';

part 'stop_time_update.freezed.dart';
part 'stop_time_update.g.dart';

/// Predicción de llegada de un viaje a una parada, calcada de GTFS-Realtime.
@freezed
abstract class StopTimeUpdate with _$StopTimeUpdate {
  const factory StopTimeUpdate({
    @JsonKey(name: 'trip_id') required String tripId,
    @JsonKey(name: 'stop_id') required String stopId,
    @JsonKey(name: 'stop_sequence') required int stopSequence,

    /// Positivo es retraso, negativo es adelanto. Puede faltar.
    @JsonKey(name: 'arrival_delay')
    @NullableDurationSecondsConverter()
    Duration? arrivalDelay,

    @JsonKey(name: 'predicted_arrival')
    @NullableEpochDateTimeConverter()
    DateTime? predictedArrival,
  }) = _StopTimeUpdate;

  factory StopTimeUpdate.fromJson(Map<String, dynamic> json) =>
      _$StopTimeUpdateFromJson(json);
}
