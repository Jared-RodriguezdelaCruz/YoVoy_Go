import 'package:json_annotation/json_annotation.dart';
import 'package:latlong2/latlong.dart';

/// `LatLng` ↔ `{"lat": …, "lon": …}`.
///
/// GTFS usa `stop_lat` / `stop_lon` como columnas sueltas; donde el JSON del
/// dataset agrupa un punto, esta es su forma.
class LatLngConverter implements JsonConverter<LatLng, Map<String, dynamic>> {
  const LatLngConverter();

  @override
  LatLng fromJson(Map<String, dynamic> json) => LatLng(
    (json['lat']! as num).toDouble(),
    (json['lon']! as num).toDouble(),
  );

  @override
  Map<String, dynamic> toJson(LatLng object) => <String, dynamic>{
    'lat': object.latitude,
    'lon': object.longitude,
  };
}

/// Lista de puntos, para `Shape.points`.
class LatLngListConverter
    implements JsonConverter<List<LatLng>, List<dynamic>> {
  const LatLngListConverter();

  @override
  List<LatLng> fromJson(List<dynamic> json) => json
      .cast<Map<String, dynamic>>()
      .map(const LatLngConverter().fromJson)
      .toList(growable: false);

  @override
  List<dynamic> toJson(List<LatLng> object) =>
      object.map(const LatLngConverter().toJson).toList(growable: false);
}
