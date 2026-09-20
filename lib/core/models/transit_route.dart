import 'package:freezed_annotation/freezed_annotation.dart';

part 'transit_route.freezed.dart';
part 'transit_route.g.dart';

/// Una ruta, calcada de `routes.txt` de GTFS.
///
/// Se llama `TransitRoute` y no `Route` por una sola razón: `Route<T>` ya
/// existe en `flutter/material.dart` y un modelo con ese nombre obligaría a
/// escribir `hide Route` en cada archivo de UI de aquí en adelante. El JSON
/// sigue siendo GTFS literal —`route_id`, `route_short_name`, …—, que es lo
/// que la regla de la sección 3 del spec protege: el día que llegue el feed
/// oficial, el mapeo no cambia.
@freezed
abstract class TransitRoute with _$TransitRoute {
  const factory TransitRoute({
    @JsonKey(name: 'route_id') required String id,

    /// El código que la gente dice en voz alta: "el 20".
    @JsonKey(name: 'route_short_name') required String shortName,

    @JsonKey(name: 'route_long_name') required String longName,

    /// `route_type` de GTFS. 3 es autobús, que es todo lo que hay en la v1.
    @JsonKey(name: 'route_type') @Default(3) int type,

    /// Hexadecimal sin `#`, como lo escribe GTFS. Falta muy seguido: cuando no
    /// está, el color se genera con hash desde [id] en la capa de diseño.
    @JsonKey(name: 'route_color') String? color,

    @JsonKey(name: 'route_text_color') String? textColor,
  }) = _TransitRoute;

  factory TransitRoute.fromJson(Map<String, dynamic> json) =>
      _$TransitRouteFromJson(json);
}
