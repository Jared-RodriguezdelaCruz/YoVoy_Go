import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../../models/models.dart';

/// Los nombres de los archivos de `assets/mock/`, en un solo lugar.
abstract final class MockAssets {
  static const String directory = 'assets/mock';

  static const List<String> files = <String>[
    'agency.json',
    'feed.json',
    'routes.json',
    'stops.json',
    'shapes.json',
    'trips.json',
    'stop_times.json',
    'calendar.json',
    'frequencies.json',
    'alerts.json',
    'itineraries.json',
    'service.json',
  ];
}

/// Cuántos vehículos le tocan a una ruta y si está en servicio.
///
/// Sale de `service.json`, que lo calculó `tool/gtfs_to_mock.py` con
/// `ceil(vuelta ÷ intervalo)`: la flota que esa frecuencia exige, no un número
/// redondo elegido a ojo.
@immutable
class RouteService {
  const RouteService({
    required this.routeId,
    required this.active,
    required this.vehicles,
    required this.cycle,
    required this.headway,
  });

  factory RouteService.fromJson(Map<String, dynamic> json) => RouteService(
    routeId: json['route_id'] as String,
    active: json['active'] as bool,
    vehicles: json['vehicles'] as int,
    cycle: Duration(seconds: json['cycle_seconds'] as int),
    headway: Duration(seconds: json['headway_seconds'] as int),
  );

  final String routeId;

  /// `false` en las rutas que el dataset deja sin servicio a propósito. La
  /// pantalla "esta ruta no tiene servicio ahora" necesita un caso real.
  final bool active;

  final int vehicles;

  /// Lo que tarda una unidad en dar la vuelta completa.
  final Duration cycle;

  final Duration headway;
}

/// Un par origen–destino precocinado de `itineraries.json`.
///
/// La v1 no tiene motor de ruteo (§4.3 del spec): `planTrip` hace matching por
/// proximidad contra estos pares. Uno de ellos trae la lista vacía a propósito.
@immutable
class PrecookedTrip {
  const PrecookedTrip({
    required this.id,
    required this.from,
    required this.to,
    required this.matchRadiusMeters,
    required this.itineraries,
  });

  factory PrecookedTrip.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> from = json['from'] as Map<String, dynamic>;
    final Map<String, dynamic> to = json['to'] as Map<String, dynamic>;
    return PrecookedTrip(
      id: json['id'] as String,
      from: LatLng(from['lat'] as double, from['lon'] as double),
      to: LatLng(to['lat'] as double, to['lon'] as double),
      matchRadiusMeters: (json['match_radius_meters'] as num).toDouble(),
      itineraries: <Itinerary>[
        for (final dynamic row in json['itineraries'] as List<dynamic>)
          Itinerary.fromJson(row as Map<String, dynamic>),
      ],
    );
  }

  final String id;
  final LatLng from;
  final LatLng to;
  final double matchRadiusMeters;
  final List<Itinerary> itineraries;
}

/// El dataset de `assets/mock/` ya parseado y con sus índices armados.
///
/// Se carga una vez y se reusa: son 2.8 MB de JSON y 41 252 puntos de trazo.
/// [load] hace el parseo **fuera del hilo de UI** con `compute`; a mano se usa
/// [fromJsonStrings], que no toca Flutter y sirve en tests.
class MockDataset {
  MockDataset._({
    required this.agencies,
    required this.feed,
    required this.routes,
    required this.stops,
    required this.shapes,
    required this.trips,
    required this.stopTimes,
    required this.calendars,
    required this.frequencies,
    required this.alerts,
    required this.precookedTrips,
    required this.service,
  }) {
    for (final TransitRoute route in routes) {
      _routesById[route.id] = route;
    }
    for (final Stop stop in stops) {
      _stopsById[stop.id] = stop;
    }
    for (final Shape shape in shapes) {
      _shapesById[shape.id] = shape;
    }
    for (final Trip trip in trips) {
      _tripsById[trip.id] = trip;
      _tripsByRoute.putIfAbsent(trip.routeId, () => <Trip>[]).add(trip);
    }
    for (final StopTime stopTime in stopTimes) {
      _stopTimesByTrip
          .putIfAbsent(stopTime.tripId, () => <StopTime>[])
          .add(stopTime);
      _tripsByStop
          .putIfAbsent(stopTime.stopId, () => <String>{})
          .add(stopTime.tripId);
    }
    for (final List<StopTime> times in _stopTimesByTrip.values) {
      times.sort((StopTime a, StopTime b) => a.stopSequence - b.stopSequence);
    }
    for (final Frequency frequency in frequencies) {
      _frequencyByTrip[frequency.tripId] = frequency;
    }
    for (final Calendar calendar in calendars) {
      _calendarsById[calendar.serviceId] = calendar;
    }
    for (final RouteService row in service) {
      _serviceByRoute[row.routeId] = row;
    }
  }

  /// Parsea el dataset desde el contenido crudo de cada archivo.
  ///
  /// No toca Flutter a propósito: así corre dentro de un isolate y también en
  /// un test que lee los archivos del disco.
  factory MockDataset.fromJsonStrings(Map<String, String> sources) {
    List<dynamic> list(String name) =>
        jsonDecode(sources[name]!) as List<dynamic>;
    Map<String, dynamic> map(String name) =>
        jsonDecode(sources[name]!) as Map<String, dynamic>;

    final Map<String, dynamic> itineraries = map('itineraries.json');

    return MockDataset._(
      feed: FeedInfo.fromJson(map('feed.json')),
      agencies: <Agency>[
        for (final dynamic row in list('agency.json'))
          Agency.fromJson(row as Map<String, dynamic>),
      ],
      routes: <TransitRoute>[
        for (final dynamic row in list('routes.json'))
          TransitRoute.fromJson(row as Map<String, dynamic>),
      ],
      stops: <Stop>[
        for (final dynamic row in list('stops.json'))
          Stop.fromJson(row as Map<String, dynamic>),
      ],
      shapes: <Shape>[
        for (final dynamic row in list('shapes.json'))
          Shape.fromJson(row as Map<String, dynamic>),
      ],
      trips: <Trip>[
        for (final dynamic row in list('trips.json'))
          Trip.fromJson(row as Map<String, dynamic>),
      ],
      stopTimes: <StopTime>[
        for (final dynamic row in list('stop_times.json'))
          StopTime.fromJson(row as Map<String, dynamic>),
      ],
      calendars: <Calendar>[
        for (final dynamic row in list('calendar.json'))
          Calendar.fromJson(row as Map<String, dynamic>),
      ],
      frequencies: <Frequency>[
        for (final dynamic row in list('frequencies.json'))
          Frequency.fromJson(row as Map<String, dynamic>),
      ],
      alerts: <ServiceAlert>[
        for (final dynamic row in list('alerts.json'))
          ServiceAlert.fromJson(row as Map<String, dynamic>),
      ],
      precookedTrips: <PrecookedTrip>[
        for (final dynamic row in itineraries['pairs'] as List<dynamic>)
          PrecookedTrip.fromJson(row as Map<String, dynamic>),
      ],
      service: <RouteService>[
        for (final dynamic row
            in map('service.json')['routes'] as List<dynamic>)
          RouteService.fromJson(row as Map<String, dynamic>),
      ],
    );
  }

  /// Lee `assets/mock/` y parsea en un isolate.
  ///
  /// El `rootBundle` solo existe en el hilo principal, así que primero se leen
  /// los textos y después se manda el parseo afuera. Bloquear el hilo de UI
  /// 200 ms al arrancar es exactamente el jank que el spec no perdona.
  static Future<MockDataset> load({AssetBundle? bundle}) async {
    final AssetBundle source = bundle ?? rootBundle;
    final Map<String, String> sources = <String, String>{
      for (final String name in MockAssets.files)
        name: await source.loadString('${MockAssets.directory}/$name'),
    };
    return compute(MockDataset.fromJsonStrings, sources);
  }

  final List<Agency> agencies;

  /// De cuándo es el horario que la app trae empacado.
  final FeedInfo feed;
  final List<TransitRoute> routes;
  final List<Stop> stops;
  final List<Shape> shapes;
  final List<Trip> trips;
  final List<StopTime> stopTimes;
  final List<Calendar> calendars;
  final List<Frequency> frequencies;
  final List<ServiceAlert> alerts;
  final List<PrecookedTrip> precookedTrips;
  final List<RouteService> service;

  final Map<String, TransitRoute> _routesById = <String, TransitRoute>{};
  final Map<String, Stop> _stopsById = <String, Stop>{};
  final Map<String, Shape> _shapesById = <String, Shape>{};
  final Map<String, Trip> _tripsById = <String, Trip>{};
  final Map<String, List<Trip>> _tripsByRoute = <String, List<Trip>>{};
  final Map<String, List<StopTime>> _stopTimesByTrip =
      <String, List<StopTime>>{};
  final Map<String, Set<String>> _tripsByStop = <String, Set<String>>{};
  final Map<String, Frequency> _frequencyByTrip = <String, Frequency>{};
  final Map<String, Calendar> _calendarsById = <String, Calendar>{};
  final Map<String, RouteService> _serviceByRoute = <String, RouteService>{};

  TransitRoute? route(String routeId) => _routesById[routeId];
  Stop? stop(String stopId) => _stopsById[stopId];
  Shape? shape(String shapeId) => _shapesById[shapeId];
  Trip? trip(String tripId) => _tripsById[tripId];
  Frequency? frequency(String tripId) => _frequencyByTrip[tripId];
  RouteService? serviceFor(String routeId) => _serviceByRoute[routeId];

  List<Trip> tripsForRoute(String routeId) =>
      _tripsByRoute[routeId] ?? const <Trip>[];

  List<StopTime> stopTimesForTrip(String tripId) =>
      _stopTimesByTrip[tripId] ?? const <StopTime>[];

  /// Los viajes que pasan por una parada.
  Set<String> tripsForStop(String stopId) =>
      _tripsByStop[stopId] ?? const <String>{};

  /// Los servicios que corren en [date]. Vacío significa que hoy no hay
  /// servicio, no que el dataset esté roto.
  Set<String> servicesOn(DateTime date) => <String>{
    for (final Calendar calendar in calendars)
      if (calendar.runsOn(date)) calendar.serviceId,
  };

  Calendar? calendar(String serviceId) => _calendarsById[serviceId];
}
