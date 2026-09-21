import 'package:flutter/foundation.dart';

import '../models/models.dart';

/// La red estática completa: rutas, viajes, trazos y paradas.
///
/// Es lo que en GTFS se descarga **de una vez**, en un solo zip, y cambia
/// cada varios meses. Por eso llega en una sola llamada y no en noventa y dos:
/// el mapa necesita todos los trazos para dibujar la red, y pedirlos uno por
/// uno multiplicaría la latencia y las fallas por cada trazo.
///
/// No trae nada de tiempo real. Las posiciones y los arribos siguen saliendo
/// de sus propios métodos del contrato.
@immutable
class TransitNetwork {
  TransitNetwork({
    required this.routes,
    required this.trips,
    required this.shapes,
    required this.stops,
    required this._stopIdsByTrip,
  }) {
    for (final TransitRoute route in routes) {
      _routesById[route.id] = route;
    }
    for (final Trip trip in trips) {
      _tripsById[trip.id] = trip;
      _tripsByRoute.putIfAbsent(trip.routeId, () => <Trip>[]).add(trip);
    }
    for (final Shape shape in shapes) {
      _shapesById[shape.id] = shape;
    }
    for (final Stop stop in stops) {
      _stopsById[stop.id] = stop;
    }
  }

  final List<TransitRoute> routes;
  final List<Trip> trips;
  final List<Shape> shapes;
  final List<Stop> stops;

  final Map<String, List<String>> _stopIdsByTrip;
  final Map<String, TransitRoute> _routesById = <String, TransitRoute>{};
  final Map<String, Trip> _tripsById = <String, Trip>{};
  final Map<String, List<Trip>> _tripsByRoute = <String, List<Trip>>{};
  final Map<String, Shape> _shapesById = <String, Shape>{};
  final Map<String, Stop> _stopsById = <String, Stop>{};

  TransitRoute? route(String routeId) => _routesById[routeId];
  Trip? trip(String tripId) => _tripsById[tripId];
  Shape? shape(String shapeId) => _shapesById[shapeId];
  Stop? stop(String stopId) => _stopsById[stopId];

  List<Trip> tripsForRoute(String routeId) =>
      _tripsByRoute[routeId] ?? const <Trip>[];

  /// Los trazos de una ruta, sin repetir: ida y regreso, normalmente.
  List<Shape> shapesForRoute(String routeId) {
    final Set<String> seen = <String>{};
    return <Shape>[
      for (final Trip trip in tripsForRoute(routeId))
        if (trip.shapeId case final String id when seen.add(id))
          if (_shapesById[id] case final Shape shape) shape,
    ];
  }

  /// Las paradas de un viaje en el orden en que las recorre.
  List<Stop> stopsForTrip(String tripId) => <Stop>[
    for (final String id in _stopIdsByTrip[tripId] ?? const <String>[])
      if (_stopsById[id] case final Stop stop) stop,
  ];
}
