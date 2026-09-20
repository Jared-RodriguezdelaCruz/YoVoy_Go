import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:latlong2/latlong.dart';

import 'converters/lat_lng_converter.dart';

part 'shape.freezed.dart';
part 'shape.g.dart';

/// El trazo de una ruta, calcado de `shapes.txt` de GTFS.
///
/// Los puntos llegan ya ordenados por `shape_pt_sequence`: el orden es el
/// dato. Una lista vacía significa ruta sin trazo, no error de parseo.
@freezed
abstract class Shape with _$Shape {
  const factory Shape({
    @JsonKey(name: 'shape_id') required String id,
    @LatLngListConverter() @Default(<LatLng>[]) List<LatLng> points,
  }) = _Shape;

  factory Shape.fromJson(Map<String, dynamic> json) => _$ShapeFromJson(json);
}
