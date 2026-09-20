import 'package:freezed_annotation/freezed_annotation.dart';

import 'converters/duration_seconds_converter.dart';
import 'converters/gtfs_time_converter.dart';

part 'frequency.freezed.dart';
part 'frequency.g.dart';

/// La frecuencia de un viaje, calcada de `frequencies.txt` de GTFS.
///
/// El feed de Aguascalientes no publica horarios: publica **frecuencias**. Un
/// viaje por sentido con un intervalo, que es como opera el sistema y como lo
/// anuncia el poste: "pasa cada 20 minutos". Sin esta entidad no se puede
/// repartir la flota del simulador (sección 4.2 del spec) ni dar el respaldo
/// de frecuencia cuando no hay ningún vehículo reportando.
@freezed
abstract class Frequency with _$Frequency {
  const factory Frequency({
    @JsonKey(name: 'trip_id') required String tripId,

    /// Desde cuándo corre esta frecuencia, como desplazamiento desde el inicio
    /// del día de servicio: GTFS admite `"25:30:00"`.
    @JsonKey(name: 'start_time')
    @GtfsTimeConverter()
    required Duration startTime,

    @JsonKey(name: 'end_time') @GtfsTimeConverter() required Duration endTime,

    /// Cada cuánto sale un vehículo dentro de la ventana.
    @JsonKey(name: 'headway_secs')
    @DurationSecondsConverter()
    required Duration headway,

    /// `true` cuando las salidas ocurren a horas exactas y no "cada tanto".
    /// En este feed siempre es `false`, que es el caso interesante: el usuario
    /// no puede planear al minuto.
    @JsonKey(name: 'exact_times') @Default(false) bool exactTimes,
  }) = _Frequency;

  const Frequency._();

  factory Frequency.fromJson(Map<String, dynamic> json) =>
      _$FrequencyFromJson(json);

  /// Si la ventana cubre [timeOfDay], medido desde el inicio del día de
  /// servicio.
  bool coversTime(Duration timeOfDay) =>
      timeOfDay >= startTime && timeOfDay <= endTime;

  /// Cuántos vehículos hacen falta para sostener esta frecuencia en un
  /// recorrido que tarda [cycle] en dar la vuelta completa.
  ///
  /// Es la cuenta que reparte la flota del simulador: con 20 minutos de
  /// intervalo y dos horas de vuelta hacen falta seis unidades, no un número
  /// redondo elegido a ojo.
  int vehiclesFor(Duration cycle) {
    if (headway.inSeconds <= 0) {
      return 0;
    }
    return (cycle.inSeconds / headway.inSeconds).ceil();
  }
}
