import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:yovoy_go/core/models/models.dart';

/// El dataset de `assets/mock/` contra los modelos de la fase 2.
///
/// No es un test de "parsea sin reventar": es el cierre de la fase 4a. Los
/// datos vienen del GTFS oficial de Aguascalientes y los convierte
/// `tool/gtfs_to_mock.py`. Si alguien reimporta el feed y algo se rompe
/// —fechas vencidas, ids colgando, coordenadas invertidas— tiene que verse
/// aquí y no en el mapa.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<dynamic> load(String name) async =>
      jsonDecode(await rootBundle.loadString('assets/mock/$name'));

  Future<List<dynamic>> loadList(String name) async =>
      (await load(name)) as List<dynamic>;

  // La caja de la zona metropolitana, con holgura. Una coordenada invertida
  // —lat y lon volteadas— cae fuera y se ve aquí.
  const double minLat = 21.75;
  const double maxLat = 22.05;
  const double minLon = -102.45;
  const double maxLon = -102.15;

  late List<TransitRoute> routes;
  late List<Stop> stops;
  late List<Shape> shapes;
  late List<Trip> trips;
  late List<StopTime> stopTimes;
  late List<Frequency> frequencies;
  late List<Calendar> calendars;
  late List<ServiceAlert> alerts;

  setUpAll(() async {
    routes = <TransitRoute>[
      for (final dynamic row in await loadList('routes.json'))
        TransitRoute.fromJson(row as Map<String, dynamic>),
    ];
    stops = <Stop>[
      for (final dynamic row in await loadList('stops.json'))
        Stop.fromJson(row as Map<String, dynamic>),
    ];
    shapes = <Shape>[
      for (final dynamic row in await loadList('shapes.json'))
        Shape.fromJson(row as Map<String, dynamic>),
    ];
    trips = <Trip>[
      for (final dynamic row in await loadList('trips.json'))
        Trip.fromJson(row as Map<String, dynamic>),
    ];
    stopTimes = <StopTime>[
      for (final dynamic row in await loadList('stop_times.json'))
        StopTime.fromJson(row as Map<String, dynamic>),
    ];
    frequencies = <Frequency>[
      for (final dynamic row in await loadList('frequencies.json'))
        Frequency.fromJson(row as Map<String, dynamic>),
    ];
    calendars = <Calendar>[
      for (final dynamic row in await loadList('calendar.json'))
        Calendar.fromJson(row as Map<String, dynamic>),
    ];
    alerts = <ServiceAlert>[
      for (final dynamic row in await loadList('alerts.json'))
        ServiceAlert.fromJson(row as Map<String, dynamic>),
    ];
  });

  group('conteos', () {
    // Si el feed cambia, estos números cambian y el test falla a propósito:
    // reimportar el GTFS es una decisión, no un accidente.
    test('el dataset trae lo que dice DATASET.md', () {
      expect(routes, hasLength(48));
      expect(stops, hasLength(1507));
      expect(shapes, hasLength(92));
      expect(trips, hasLength(184));
      expect(stopTimes, hasLength(8388));
      expect(frequencies, hasLength(184));
      expect(calendars, hasLength(2));
      expect(alerts, hasLength(2));
    });

    test('la agencia es una y es la del estado', () async {
      final List<dynamic> rows = await loadList('agency.json');
      final Agency agency = Agency.fromJson(rows.single as Map<String, dynamic>);

      expect(agency.timezone, 'America/Mexico_City');
    });
  });

  group('integridad referencial', () {
    test('ningún viaje apunta a una ruta o un trazo que no existe', () {
      final Set<String> routeIds = routes.map((TransitRoute r) => r.id).toSet();
      final Set<String> shapeIds = shapes.map((Shape s) => s.id).toSet();

      for (final Trip trip in trips) {
        expect(routeIds, contains(trip.routeId));
        expect(shapeIds, contains(trip.shapeId));
      }
    });

    test('ningún stop_time apunta a una parada o un viaje que no existe', () {
      final Set<String> stopIds = stops.map((Stop s) => s.id).toSet();
      final Set<String> tripIds = trips.map((Trip t) => t.id).toSet();

      for (final StopTime stopTime in stopTimes) {
        expect(stopIds, contains(stopTime.stopId));
        expect(tripIds, contains(stopTime.tripId));
      }
    });

    test('toda frecuencia pertenece a un viaje del dataset', () {
      final Set<String> tripIds = trips.map((Trip t) => t.id).toSet();

      for (final Frequency frequency in frequencies) {
        expect(tripIds, contains(frequency.tripId));
        expect(frequency.headway, greaterThan(Duration.zero));
        expect(frequency.endTime, greaterThan(frequency.startTime));
      }
    });

    test('todo viaje corre bajo un servicio declarado', () {
      final Set<String> serviceIds = calendars
          .map((Calendar c) => c.serviceId)
          .toSet();

      for (final Trip trip in trips) {
        expect(serviceIds, contains(trip.serviceId));
      }
    });

    test('las alertas apuntan a rutas y paradas reales', () {
      final Set<String> routeIds = routes.map((TransitRoute r) => r.id).toSet();
      final Set<String> stopIds = stops.map((Stop s) => s.id).toSet();

      for (final ServiceAlert alert in alerts) {
        expect(routeIds, containsAll(alert.affectedRouteIds));
        expect(stopIds, containsAll(alert.affectedStopIds));
      }
    });
  });

  group('geografía', () {
    test('toda parada cae dentro de la zona metropolitana', () {
      for (final Stop stop in stops) {
        expect(stop.lat, inInclusiveRange(minLat, maxLat), reason: stop.id);
        expect(stop.lon, inInclusiveRange(minLon, maxLon), reason: stop.id);
      }
    });

    test('todo trazo tiene al menos dos puntos y todos caen en la caja', () {
      for (final Shape shape in shapes) {
        expect(shape.points.length, greaterThan(1), reason: shape.id);
        for (final LatLng point in shape.points) {
          expect(point.latitude, inInclusiveRange(minLat, maxLat));
          expect(point.longitude, inInclusiveRange(minLon, maxLon));
        }
      }
    });

    test('los trazos van sobre calles, no en línea recta', () {
      // Un trazo dibujado a ojo tiene decenas de puntos; uno que sigue la
      // calle tiene cientos. Es la diferencia entre cortar manzanas y no.
      final double promedio =
          shapes.fold<int>(0, (int sum, Shape s) => sum + s.points.length) /
          shapes.length;

      expect(promedio, greaterThan(200));
    });
  });

  group('secuencias', () {
    test('stop_sequence crece dentro de cada viaje', () {
      final Map<String, List<StopTime>> porViaje = <String, List<StopTime>>{};
      for (final StopTime stopTime in stopTimes) {
        porViaje.putIfAbsent(stopTime.tripId, () => <StopTime>[]).add(stopTime);
      }

      expect(porViaje, hasLength(trips.length));

      for (final MapEntry<String, List<StopTime>> entry in porViaje.entries) {
        int previous = -1;
        Duration last = Duration.zero;
        for (final StopTime stopTime in entry.value) {
          expect(
            stopTime.stopSequence,
            greaterThan(previous),
            reason: entry.key,
          );
          expect(
            stopTime.departureTime,
            greaterThanOrEqualTo(stopTime.arrivalTime),
          );
          expect(
            stopTime.arrivalTime,
            greaterThanOrEqualTo(last),
            reason: entry.key,
          );
          previous = stopTime.stopSequence;
          last = stopTime.departureTime;
        }
        expect(entry.value.length, greaterThan(3), reason: entry.key);
      }
    });
  });

  group('calendario', () {
    test('hay servicio hoy', () {
      // La trampa que deja el feed: declara vigencia 20230101–20251231, ya
      // vencida. Con esas fechas la app diría que no hay servicio nunca, y
      // nadie lo notaría hasta abrir una parada.
      final DateTime hoy = DateTime.now();

      expect(
        calendars.any((Calendar c) => c.runsOn(hoy)),
        isTrue,
        reason: 'ningún servicio corre hoy: revisa la vigencia del calendario',
      );
    });

    test('hay servicio entre semana y en fin de semana', () {
      expect(
        calendars.any((Calendar c) => c.days.contains(Weekday.monday)),
        isTrue,
      );
      expect(
        calendars.any((Calendar c) => c.days.contains(Weekday.sunday)),
        isTrue,
      );
    });
  });

  group('alertas', () {
    test('exactamente una está vigente hoy', () {
      // La otra existe para probar que una alerta vencida no se pinta.
      final DateTime hoy = DateTime.now();

      expect(alerts.where((ServiceAlert a) => a.isActiveAt(hoy)), hasLength(1));
    });

    test('la vigente no tiene fin declarado', () {
      final ServiceAlert vigente = alerts.firstWhere(
        (ServiceAlert a) => a.isActiveAt(DateTime.now()),
      );

      expect(vigente.activePeriod?.end, isNull);
      expect(vigente.effect, AlertEffect.detour);
    });
  });

  group('rutas', () {
    test('todas traen el color del feed y un nombre que dice algo', () {
      for (final TransitRoute route in routes) {
        expect(route.color, isNotNull, reason: route.id);
        expect(route.color, hasLength(6), reason: route.id);
        expect(route.shortName, isNotEmpty);
        // `R-01` es lo que trae el feed y no informa; el nombre largo se
        // deriva de las terminales.
        expect(route.longName, isNot(matches(r'^R-\d')), reason: route.id);
      }
    });

    test('todo viaje lleva letrero', () {
      for (final Trip trip in trips) {
        expect(trip.headsign, isNotEmpty, reason: trip.id);
        expect(trip.headsign, isNot(contains(' - ')), reason: trip.id);
      }
    });
  });

  group('reparto de flota', () {
    test('la cuenta de service.json es la de Frequency.vehiclesFor', () async {
      final Map<String, dynamic> service =
          (await load('service.json')) as Map<String, dynamic>;
      final List<dynamic> filas = service['routes'] as List<dynamic>;
      final Map<String, Frequency> porViaje = <String, Frequency>{
        for (final Frequency f in frequencies) f.tripId: f,
      };

      expect(filas, hasLength(routes.length));

      int sinServicio = 0;
      for (final dynamic fila in filas) {
        final Map<String, dynamic> row = fila as Map<String, dynamic>;
        final bool activa = row['active'] as bool;
        final int vehiculos = row['vehicles'] as int;

        if (!activa) {
          sinServicio++;
          expect(vehiculos, 0, reason: row['route_id'] as String);
          continue;
        }

        final Trip viaje = trips.firstWhere(
          (Trip t) => t.routeId == row['route_id'] && t.serviceId == 'ES',
        );
        final Frequency frecuencia = porViaje[viaje.id]!;

        expect(
          vehiculos,
          frecuencia.vehiclesFor(
            Duration(seconds: row['cycle_seconds'] as int),
          ),
          reason: row['route_id'] as String,
        );
        expect(vehiculos, greaterThan(0));
      }

      // Sin esto la pantalla "esta ruta no tiene servicio ahora" no tendría
      // cómo dispararse (§4.2 del spec).
      expect(sinServicio, greaterThan(0));
    });
  });

  group('itinerarios precocinados', () {
    late List<dynamic> pares;

    setUpAll(() async {
      final Map<String, dynamic> raw =
          (await load('itineraries.json')) as Map<String, dynamic>;
      pares = raw['pairs'] as List<dynamic>;
    });

    test('son cuatro pares y uno viene sin resultados', () {
      expect(pares, hasLength(4));
      expect(
        pares.where(
          (dynamic p) =>
              ((p as Map<String, dynamic>)['itineraries'] as List<dynamic>)
                  .isEmpty,
        ),
        hasLength(1),
      );
    });

    test('cada itinerario parsea y se cuenta solo', () {
      final Set<int> transbordos = <int>{};

      for (final dynamic par in pares) {
        final List<dynamic> filas =
            (par as Map<String, dynamic>)['itineraries'] as List<dynamic>;
        for (final dynamic row in filas) {
          final Itinerary itinerary = Itinerary.fromJson(
            row as Map<String, dynamic>,
          );

          expect(itinerary.legs.length, greaterThan(2));
          expect(itinerary.transferCount, itinerary.busLegs.length - 1);
          expect(itinerary.walkingDistance, greaterThan(0));
          expect(
            itinerary.totalDuration,
            itinerary.legs.fold(
              Duration.zero,
              (Duration sum, Leg leg) => sum + leg.duration,
            ),
          );
          transbordos.add(itinerary.transferCount);

          // Un viaje que arranca o termina en camión no existe: siempre se
          // camina hasta la parada.
          expect(itinerary.legs.first.isWalk, isTrue);
          expect(itinerary.legs.last.isWalk, isTrue);
        }
      }

      // Directo, un transbordo y dos, como pide la sección 4.3 del spec.
      expect(transbordos, <int>{0, 1, 2});
    });

    test('los tramos de camión traen ruta, paradas y geometría real', () {
      final Set<String> stopIds = stops.map((Stop s) => s.id).toSet();

      for (final dynamic par in pares) {
        final List<dynamic> filas =
            (par as Map<String, dynamic>)['itineraries'] as List<dynamic>;
        for (final dynamic row in filas) {
          final Itinerary itinerary = Itinerary.fromJson(
            row as Map<String, dynamic>,
          );
          for (final Leg leg in itinerary.busLegs) {
            expect(leg.route, isNotNull);
            expect(stopIds, contains(leg.fromStopId));
            expect(stopIds, contains(leg.toStopId));
            // Recortada del trazo del viaje, no una línea entre dos puntos.
            expect(leg.geometry.length, greaterThan(10));
            expect(leg.duration, greaterThan(Duration.zero));
          }
        }
      }
    });

    test('el par sin resultados apunta lejos de la red', () {
      final Map<String, dynamic> vacio =
          pares.firstWhere(
                (dynamic p) =>
                    ((p as Map<String, dynamic>)['itineraries']
                            as List<dynamic>)
                        .isEmpty,
              )
              as Map<String, dynamic>;
      final Map<String, dynamic> destino = vacio['to'] as Map<String, dynamic>;

      expect(destino['lon'] as double, lessThan(minLon));
    });
  });

  group('accesibilidad y códigos', () {
    test('toda parada trae código visible', () {
      for (final Stop stop in stops) {
        expect(stop.code, isNotNull, reason: stop.id);
        expect(stop.code, matches(r'^[A-Z]+-\d{3,4}$'), reason: stop.id);
      }
    });

    test('la accesibilidad tiene los tres valores, y unknown manda', () {
      // Es dato simulado y está declarado en DATASET.md. `unknown` queda como
      // mayoría a propósito: es el estado real del mundo, y no significa "no
      // accesible".
      final Map<WheelchairBoarding, int> cuenta = <WheelchairBoarding, int>{};
      for (final Stop stop in stops) {
        cuenta.update(
          stop.wheelchairBoarding,
          (int n) => n + 1,
          ifAbsent: () => 1,
        );
      }

      expect(cuenta.keys, hasLength(3));
      expect(
        cuenta[WheelchairBoarding.unknown],
        greaterThan(cuenta[WheelchairBoarding.accessible]!),
      );
    });
  });
}
