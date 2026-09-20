import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:latlong2/latlong.dart';

import 'enums.dart';

part 'stop.freezed.dart';
part 'stop.g.dart';

/// Una parada, calcada de `stops.txt` de GTFS.
@freezed
abstract class Stop with _$Stop {
  const factory Stop({
    @JsonKey(name: 'stop_id') required String id,
    @JsonKey(name: 'stop_name') required String name,
    @JsonKey(name: 'stop_lat') required double lat,
    @JsonKey(name: 'stop_lon') required double lon,

    /// Código visible en el poste. No siempre existe.
    @JsonKey(name: 'stop_code') String? code,

    /// `unknown` es el default del estándar y **no** significa "no accesible":
    /// significa que nadie lo verificó. La UI los distingue.
    @JsonKey(name: 'wheelchair_boarding')
    @Default(WheelchairBoarding.unknown)
    WheelchairBoarding wheelchairBoarding,
  }) = _Stop;

  const Stop._();

  factory Stop.fromJson(Map<String, dynamic> json) => _$StopFromJson(json);

  /// Posición de la parada, para el mapa.
  LatLng get position => LatLng(lat, lon);
}
