import 'package:freezed_annotation/freezed_annotation.dart';

import 'converters/duration_seconds_converter.dart';
import 'leg.dart';

part 'itinerary.freezed.dart';
part 'itinerary.g.dart';

/// Una forma de ir de A a B, como en la sección 4.3 del spec.
@freezed
abstract class Itinerary with _$Itinerary {
  const factory Itinerary({
    required List<Leg> legs,

    @JsonKey(name: 'total_duration')
    @DurationSecondsConverter()
    required Duration totalDuration,

    /// Metros a pie, sumando todos los tramos caminando. Es el número que más
    /// pesa a la hora de elegir, más que los minutos totales.
    @JsonKey(name: 'walking_distance') @Default(0) double walkingDistance,

    @JsonKey(name: 'transfer_count') @Default(0) int transferCount,

    /// Tarifa estimada en pesos. Opcional: la v1 no la calcula.
    double? fare,
  }) = _Itinerary;

  const Itinerary._();

  factory Itinerary.fromJson(Map<String, dynamic> json) =>
      _$ItineraryFromJson(json);

  /// Las rutas que se toman, en orden. Vacía si todo el viaje es a pie.
  List<Leg> get busLegs =>
      legs.where((Leg leg) => !leg.isWalk).toList(growable: false);
}
