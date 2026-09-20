import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:latlong2/latlong.dart';

import 'converters/duration_seconds_converter.dart';
import 'converters/lat_lng_converter.dart';
import 'enums.dart';
import 'transit_route.dart';

part 'leg.freezed.dart';
part 'leg.g.dart';

/// Un tramo de un itinerario, como en la sección 4.3 del spec: o se camina o
/// se va en camión.
@freezed
abstract class Leg with _$Leg {
  const factory Leg({
    required LegType type,

    /// Nombre del punto de origen, tal como se muestra: "Tu ubicación",
    /// "Bonanza".
    required String from,

    /// Nombre del punto de destino.
    required String to,

    @DurationSecondsConverter() required Duration duration,

    /// La ruta que se toma. Nula en los tramos a pie.
    TransitRoute? route,

    @JsonKey(name: 'from_stop_id') String? fromStopId,
    @JsonKey(name: 'to_stop_id') String? toStopId,

    /// Geometría del tramo, para dibujarlo sobre el mapa.
    @LatLngListConverter() @Default(<LatLng>[]) List<LatLng> geometry,
  }) = _Leg;

  const Leg._();

  factory Leg.fromJson(Map<String, dynamic> json) => _$LegFromJson(json);

  /// Un tramo a pie se dibuja punteado y no lleva placa de ruta.
  bool get isWalk => type == LegType.walk;
}
