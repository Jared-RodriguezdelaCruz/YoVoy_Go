import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/data/transit_network.dart';
import '../../../core/location/location_service.dart';
import '../../../core/models/models.dart';

/// Un extremo del viaje, tal como lo eligió el usuario.
///
/// Viaja en la URL (`?from=here&to=P606`), así que el planificador, el detalle
/// y el modo viaje se pueden abrir por enlace y reconstruirse solos.
@immutable
sealed class PlaceRef {
  const PlaceRef();

  /// Lee lo que escribe [encode]: `here`, `21.84,-102.29` o un id de parada.
  /// `null` si no hay nada.
  static PlaceRef? parse(String? raw) {
    final String value = raw?.trim() ?? '';
    if (value.isEmpty) {
      return null;
    }
    if (value == HerePlace.token) {
      return const HerePlace();
    }
    final RegExpMatch? point = _point.firstMatch(value);
    if (point != null) {
      return PointPlace(
        LatLng(double.parse(point.group(1)!), double.parse(point.group(2)!)),
      );
    }
    return StopPlace(value);
  }

  static final RegExp _point = RegExp(
    r'^(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)$',
  );

  String encode();
}

/// "Mi ubicación": se resuelve con el GPS al planear, no al elegirla.
final class HerePlace extends PlaceRef {
  const HerePlace();

  static const String token = 'here';

  @override
  String encode() => token;

  @override
  bool operator ==(Object other) => other is HerePlace;

  @override
  int get hashCode => token.hashCode;
}

/// Una parada de la red.
final class StopPlace extends PlaceRef {
  const StopPlace(this.stopId);

  final String stopId;

  @override
  String encode() => stopId;

  @override
  bool operator ==(Object other) =>
      other is StopPlace && other.stopId == stopId;

  @override
  int get hashCode => stopId.hashCode;
}

/// Un punto suelto del mapa, sin nombre.
final class PointPlace extends PlaceRef {
  const PointPlace(this.point);

  final LatLng point;

  @override
  String encode() =>
      '${point.latitude.toStringAsFixed(6)},'
      '${point.longitude.toStringAsFixed(6)}';

  @override
  bool operator ==(Object other) =>
      other is PointPlace && other.encode() == encode();

  @override
  int get hashCode => encode().hashCode;
}

/// Lo que se le pide al planificador.
@immutable
class TripRequest {
  const TripRequest({this.from, this.to, this.departMinutes});

  /// Lee la query de la URL.
  factory TripRequest.fromQuery(Map<String, String> query) => TripRequest(
    from: PlaceRef.parse(query[fromKey]),
    to: PlaceRef.parse(query[toKey]),
    departMinutes: _parseTime(query[atKey]),
  );

  static const String fromKey = 'from';
  static const String toKey = 'to';
  static const String atKey = 'at';

  final PlaceRef? from;
  final PlaceRef? to;

  /// La hora de salida en minutos desde la medianoche. `null` es "salir
  /// ahora", que es lo que se pide casi siempre.
  final int? departMinutes;

  bool get isComplete => from != null && to != null;

  bool get leavesNow => departMinutes == null;

  TripRequest withFrom(PlaceRef? place) =>
      TripRequest(from: place, to: to, departMinutes: departMinutes);

  TripRequest withTo(PlaceRef? place) =>
      TripRequest(from: from, to: place, departMinutes: departMinutes);

  TripRequest withDepartMinutes(int? minutes) =>
      TripRequest(from: from, to: to, departMinutes: minutes);

  TripRequest swapped() =>
      TripRequest(from: to, to: from, departMinutes: departMinutes);

  Map<String, String> toQuery() => <String, String>{
    if (from case final PlaceRef place) fromKey: place.encode(),
    if (to case final PlaceRef place) toKey: place.encode(),
    if (departMinutes case final int minutes) atKey: timeLabel(minutes),
  };

  /// La hora en la que sale el viaje, en el día de [now].
  DateTime departAt(DateTime now) => switch (departMinutes) {
    final int minutes => DateTime(
      now.year,
      now.month,
      now.day,
    ).add(Duration(minutes: minutes)),
    null => now,
  };

  /// "8:05", como se lee en un reloj.
  static String timeLabel(int minutes) =>
      '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}';

  static int? _parseTime(String? raw) {
    final RegExpMatch? match = RegExp(r'^(\d{1,2}):(\d{2})$')
        .firstMatch(raw?.trim() ?? '');
    if (match == null) {
      return null;
    }
    final int hours = int.parse(match.group(1)!);
    final int minutes = int.parse(match.group(2)!);
    if (hours > 23 || minutes > 59) {
      return null;
    }
    return hours * 60 + minutes;
  }

  @override
  bool operator ==(Object other) =>
      other is TripRequest &&
      other.from == from &&
      other.to == to &&
      other.departMinutes == departMinutes;

  @override
  int get hashCode => Object.hash(from, to, departMinutes);

  @override
  String toString() => 'TripRequest(${toQuery()})';
}

/// Un extremo ya ubicado: dónde está y cómo se llama en pantalla.
@immutable
class ResolvedPlace {
  const ResolvedPlace({required this.position, required this.label, this.stop});

  final LatLng position;
  final String label;

  /// La parada, si el extremo es una.
  final Stop? stop;
}

/// "Mi ubicación" no se pudo resolver. Planear desde el centro de la ciudad
/// sin decirlo daría un viaje que no es el del usuario.
class OriginUnavailable implements Exception {
  const OriginUnavailable(this.issue);

  final LocationIssue issue;

  @override
  String toString() => 'OriginUnavailable($issue)';
}

/// Una parada de la URL que la red no tiene.
class PlaceNotFound implements Exception {
  const PlaceNotFound(this.id);

  final String id;

  @override
  String toString() => 'PlaceNotFound($id)';
}

/// El nombre que se ve en el campo, sin tocar el GPS.
String placeLabel(PlaceRef place, TransitNetwork? network) => switch (place) {
  HerePlace() => 'Mi ubicación',
  StopPlace(:final String stopId) => network?.stop(stopId)?.name ?? stopId,
  PointPlace() => 'Un punto del mapa',
};

/// Ubica [place]. Lanza [OriginUnavailable] si es "mi ubicación" y el
/// teléfono no la dio, y [PlaceNotFound] si es una parada que no existe.
ResolvedPlace resolvePlace(
  PlaceRef place, {
  required TransitNetwork network,
  UserLocation? location,
}) {
  switch (place) {
    case HerePlace():
      final UserLocation? here = location;
      if (here == null || here.isFallback) {
        throw OriginUnavailable(here?.issue ?? LocationIssue.unavailable);
      }
      return ResolvedPlace(position: here.position, label: 'Tu ubicación');
    case StopPlace(:final String stopId):
      final Stop stop = network.stop(stopId) ?? (throw PlaceNotFound(stopId));
      return ResolvedPlace(
        position: stop.position,
        label: stop.name,
        stop: stop,
      );
    case PointPlace(:final LatLng point):
      return ResolvedPlace(position: point, label: 'Un punto del mapa');
  }
}

/// La parada donde termina un letrero: "Hacia Las Palmas" es un lugar, y se
/// llega bajando donde el camión termina su viaje.
///
/// `null` si ningún viaje de [routeIds] lleva ese letrero.
String? terminalStopFor(
  TransitNetwork network, {
  required String headsign,
  required List<String> routeIds,
}) {
  for (final String routeId in routeIds) {
    for (final Trip trip in network.tripsForRoute(routeId)) {
      if (trip.headsign != headsign) {
        continue;
      }
      final List<Stop> stops = network.stopsForTrip(trip.id);
      if (stops.isNotEmpty) {
        return stops.last.id;
      }
    }
  }
  return null;
}
