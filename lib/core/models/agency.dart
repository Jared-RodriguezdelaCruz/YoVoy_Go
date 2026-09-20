import 'package:freezed_annotation/freezed_annotation.dart';

part 'agency.freezed.dart';
part 'agency.g.dart';

/// Operador del sistema, calcado de `agency.txt` de GTFS.
@freezed
abstract class Agency with _$Agency {
  const factory Agency({
    @JsonKey(name: 'agency_id') required String id,
    @JsonKey(name: 'agency_name') required String name,
    @JsonKey(name: 'agency_url') required String url,
    @JsonKey(name: 'agency_timezone') required String timezone,
  }) = _Agency;

  factory Agency.fromJson(Map<String, dynamic> json) => _$AgencyFromJson(json);
}
