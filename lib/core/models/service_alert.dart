import 'package:freezed_annotation/freezed_annotation.dart';

import 'converters/epoch_date_time_converter.dart';
import 'enums.dart';

part 'service_alert.freezed.dart';
part 'service_alert.g.dart';

/// Ventana en que una alerta está vigente.
///
/// `end` nulo significa "hasta nuevo aviso", que es lo más común en el mundo
/// real. No es un dato faltante.
@freezed
abstract class ActivePeriod with _$ActivePeriod {
  const factory ActivePeriod({
    @EpochDateTimeConverter() required DateTime start,
    @NullableEpochDateTimeConverter() DateTime? end,
  }) = _ActivePeriod;

  const ActivePeriod._();

  factory ActivePeriod.fromJson(Map<String, dynamic> json) =>
      _$ActivePeriodFromJson(json);

  /// Si la ventana cubre [moment].
  bool contains(DateTime moment) {
    final DateTime utc = moment.toUtc();
    if (utc.isBefore(start.toUtc())) {
      return false;
    }
    final DateTime? closesAt = end;
    return closesAt == null || !utc.isAfter(closesAt.toUtc());
  }
}

/// Alerta de servicio, calcada de GTFS-Realtime.
@freezed
abstract class ServiceAlert with _$ServiceAlert {
  const factory ServiceAlert({
    required String id,

    /// Encabezado corto: es lo que se lee arriba de la lista de arribos.
    required String header,

    @JsonKey(name: 'affected_route_ids')
    @Default(<String>[])
    List<String> affectedRouteIds,

    @JsonKey(name: 'affected_stop_ids')
    @Default(<String>[])
    List<String> affectedStopIds,

    @Default(AlertCause.unknownCause) AlertCause cause,
    @Default(AlertEffect.unknownEffect) AlertEffect effect,

    String? description,

    @JsonKey(name: 'active_period') ActivePeriod? activePeriod,
  }) = _ServiceAlert;

  const ServiceAlert._();

  factory ServiceAlert.fromJson(Map<String, dynamic> json) =>
      _$ServiceAlertFromJson(json);

  /// Una alerta sin periodo se considera vigente: si el operador no dijo
  /// cuándo termina, ocultarla sería inventar.
  bool isActiveAt(DateTime moment) => activePeriod?.contains(moment) ?? true;
}
