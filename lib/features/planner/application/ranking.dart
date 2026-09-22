import '../../../core/models/models.dart';

/// Lo que "cuesta" un transbordo, en minutos de viaje.
///
/// Citymapper propone cuatro transbordos cuando había un camión directo
/// (`FEATURES.md`). Bajarse, cruzar y esperar otro camión cansa más de lo que
/// dicen los minutos, y cada transbordo es otra oportunidad de que algo falle.
/// Por eso uno solo gana si ahorra más que esto.
const Duration transferPenalty = Duration(minutes: 10);

/// Caminar hasta aquí no se castiga: es ir a la parada.
const double freeWalkMeters = 500;

/// Cada minuto a pie más allá de [freeWalkMeters] pesa esto de más. Con sol,
/// con bolsas o con una rodilla mala, caminar es lo que más se siente.
const double extraWalkWeight = 1.5;

/// La velocidad a pie de los itinerarios, la misma del generador del
/// dataset (`tool/gtfs_to_mock.py`).
const double walkMetersPerSecond = 1.2;

/// El costo con el que se ordena: los minutos del viaje, más lo que pesan los
/// transbordos y la caminata larga.
Duration itineraryCost(Itinerary itinerary) {
  final double extraWalk = itinerary.walkingDistance - freeWalkMeters;
  final double walkSeconds = extraWalk > 0
      ? extraWalk / walkMetersPerSecond * extraWalkWeight
      : 0;
  return itinerary.totalDuration +
      transferPenalty * itinerary.transferCount +
      Duration(seconds: walkSeconds.round());
}

/// "Simplicidad antes que minutos": ordena por [itineraryCost], y en empate,
/// por el viaje más corto. No cambia la lista que recibe.
List<Itinerary> rankItineraries(List<Itinerary> options) {
  final List<Itinerary> sorted = List<Itinerary>.of(options);
  sorted.sort((Itinerary a, Itinerary b) {
    final int byCost = itineraryCost(a).compareTo(itineraryCost(b));
    return byCost != 0 ? byCost : a.totalDuration.compareTo(b.totalDuration);
  });
  return sorted;
}
