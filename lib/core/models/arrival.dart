import 'package:freezed_annotation/freezed_annotation.dart';

import '../config/freshness.dart';
import 'converters/duration_seconds_converter.dart';
import 'enums.dart';

part 'arrival.freezed.dart';
part 'arrival.g.dart';

/// Un arribo listo para pintarse: lo que la UI necesita saber de "el 20 llega
/// en 4 minutos".
///
/// Es un modelo de presentación, no una entidad de GTFS. [confidence] y
/// [dataAge] no son adorno: son el corazón de la propuesta del producto, y
/// todo componente que pinte un ETA recibe los dos.
@freezed
abstract class Arrival with _$Arrival {
  const factory Arrival({
    @JsonKey(name: 'route_id') required String routeId,
    @JsonKey(name: 'route_short_name') required String routeShortName,
    required String headsign,

    /// Qué tan viejo es el dato que sostiene este arribo.
    @JsonKey(name: 'data_age')
    @DurationSecondsConverter()
    required Duration dataAge,

    /// `null` es un estado válido y frecuente: no sabemos en cuánto llega.
    @NullableDurationSecondsConverter() Duration? eta,

    @Default(EtaConfidence.unknown) EtaConfidence confidence,

    @JsonKey(name: 'vehicle_id') String? vehicleId,

    /// Ocupación reportada por el vehículo, cuando la hay.
    @JsonKey(name: 'occupancy_status') OccupancyStatus? occupancyStatus,
  }) = _Arrival;

  const Arrival._();

  factory Arrival.fromJson(Map<String, dynamic> json) =>
      _$ArrivalFromJson(json);

  /// Edad del dato traducida a estado de presentación.
  DataFreshness get freshness => Freshness.classify(dataAge);

  /// Si la UI puede mostrar el número de minutos.
  ///
  /// Falso cuando no hay ETA o cuando el dato pasó del umbral: un número
  /// inventado es peor que un "no sé". Ningún componente decide esto por su
  /// cuenta; todos preguntan aquí.
  bool get showsNumericEta =>
      eta != null &&
      confidence != EtaConfidence.unknown &&
      Freshness.allowsNumericEta(freshness);
}
