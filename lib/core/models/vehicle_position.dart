import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:latlong2/latlong.dart';

import 'converters/epoch_date_time_converter.dart';
import 'converters/lat_lng_converter.dart';
import 'enums.dart';

part 'vehicle_position.freezed.dart';
part 'vehicle_position.g.dart';

/// Posición reportada por un vehículo, calcada de GTFS-Realtime.
@freezed
abstract class VehiclePosition with _$VehiclePosition {
  const factory VehiclePosition({
    @JsonKey(name: 'vehicle_id') required String vehicleId,
    @JsonKey(name: 'trip_id') required String tripId,
    @JsonKey(name: 'route_id') required String routeId,
    @LatLngConverter() required LatLng position,

    /// Cuándo reportó **el vehículo**, no cuándo lo recibimos nosotros. De esa
    /// distinción depende toda la lógica de frescura.
    @EpochDateTimeConverter() required DateTime timestamp,

    /// Grados, 0 = norte. Falta en buena parte de los reportes reales: el
    /// marcador degrada a círculo sin dirección, no a una flecha al norte.
    double? bearing,

    /// Metros por segundo.
    double? speed,

    @JsonKey(name: 'occupancy_status') OccupancyStatus? occupancyStatus,
    @JsonKey(name: 'current_stop_sequence') int? currentStopSequence,
  }) = _VehiclePosition;

  const VehiclePosition._();

  factory VehiclePosition.fromJson(Map<String, dynamic> json) =>
      _$VehiclePositionFromJson(json);

  /// Qué tan viejo es este reporte respecto a [now].
  ///
  /// Se pasa a `Freshness.classify` para decidir si la UI puede mostrar un ETA
  /// numérico.
  Duration ageAt(DateTime now) => now.toUtc().difference(timestamp.toUtc());
}
