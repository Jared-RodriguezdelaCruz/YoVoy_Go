import 'package:freezed_annotation/freezed_annotation.dart';

part 'trip.freezed.dart';
part 'trip.g.dart';

/// Un viaje de una ruta, calcado de `trips.txt` de GTFS.
@freezed
abstract class Trip with _$Trip {
  const factory Trip({
    @JsonKey(name: 'trip_id') required String id,
    @JsonKey(name: 'route_id') required String routeId,
    @JsonKey(name: 'service_id') required String serviceId,

    /// Lo que dice el letrero del camión: su destino.
    @JsonKey(name: 'trip_headsign') required String headsign,

    /// Sentido: 0 de ida, 1 de vuelta. Es la convención de GTFS.
    @JsonKey(name: 'direction_id') @Default(0) int directionId,

    @JsonKey(name: 'shape_id') String? shapeId,
  }) = _Trip;

  factory Trip.fromJson(Map<String, dynamic> json) => _$TripFromJson(json);
}
