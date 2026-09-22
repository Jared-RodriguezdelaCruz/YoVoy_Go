import 'package:flutter/foundation.dart';

import '../../../core/models/models.dart';

/// Cuándo empieza y termina un tramo, según el horario del itinerario.
@immutable
class LegTimes {
  const LegTimes({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

/// Las horas de cada tramo: la salida más las duraciones acumuladas.
///
/// Es una estimación y se muestra como tal: los itinerarios no cuentan la
/// espera en la parada, porque esa sale de los arribos y no del horario.
List<LegTimes> legTimes(Itinerary itinerary, DateTime departAt) {
  final List<LegTimes> times = <LegTimes>[];
  DateTime cursor = departAt;
  for (final Leg leg in itinerary.legs) {
    final DateTime end = cursor.add(leg.duration);
    times.add(LegTimes(start: cursor, end: end));
    cursor = end;
  }
  return times;
}

/// La hora a la que se llega, sin contar la espera.
DateTime arrivalAt(Itinerary itinerary, DateTime departAt) =>
    departAt.add(itinerary.totalDuration);

/// El primer tramo en camión, o `null` si todo el viaje es a pie.
Leg? firstBusLeg(Itinerary itinerary) => itinerary.busLegs.firstOrNull;

/// El próximo camión de [routeId] entre los arribos de su parada de subida.
///
/// Se prefiere el que da número en vivo; si no, cualquiera de esa ruta, que
/// trae su horario o su frecuencia. Nunca se arma un arribo que no llegó.
Arrival? boardingArrival(List<Arrival> arrivals, String routeId) {
  final Iterable<Arrival> ofRoute = arrivals.where(
    (Arrival a) => a.routeId == routeId,
  );
  return ofRoute
          .where(
            (Arrival a) =>
                a.confidence == EtaConfidence.live && a.showsNumericEta,
          )
          .firstOrNull ??
      ofRoute.firstOrNull;
}

/// "27 min" o "1 h 05 min".
String durationLabel(Duration duration) {
  final int minutes = (duration.inSeconds / 60).round();
  if (minutes < 60) {
    return '${minutes < 1 ? 1 : minutes} min';
  }
  return '${minutes ~/ 60} h ${(minutes % 60).toString().padLeft(2, '0')} min';
}

/// "directo", "1 transbordo", "2 transbordos".
String transfersLabel(int count) => switch (count) {
  0 => 'directo',
  1 => '1 transbordo',
  _ => '$count transbordos',
};
