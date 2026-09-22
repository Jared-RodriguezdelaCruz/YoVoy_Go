import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:yovoy_go/core/config/freshness.dart';
import 'package:yovoy_go/core/data/mock/mock_dataset.dart';
import 'package:yovoy_go/core/data/mock/mock_transit_repository.dart';
import 'package:yovoy_go/core/data/mock/simulator_config.dart';
import 'package:yovoy_go/core/data/mock/transit_simulator.dart';
import 'package:yovoy_go/core/data/transit_repository.dart';
import 'package:yovoy_go/core/data/transit_repository_provider.dart';
import 'package:yovoy_go/core/models/models.dart';

/// La fase 4b: el repositorio mock y el simulador.
///
/// Lo que se prueba aquí no es "que compile": es que el simulador **se porte
/// mal de forma predecible**. Un mock de datos perfectos produce una UI que se
/// rompe en producción, así que cada falla de la sección 4.2 del spec tiene
/// que poder forzarse y verificarse.
void main() {
  late MockDataset dataset;

  setUpAll(() {
    // Se leen del disco y no por `rootBundle`: así el test no necesita el
    // binding de Flutter ni un isolate para parsear 2.8 MB.
    dataset = MockDataset.fromJsonStrings(<String, String>{
      for (final String name in MockAssets.files)
        name: File('${MockAssets.directory}/$name').readAsStringSync(),
    });
  });

  // Un martes a media mañana: hay servicio entre semana y la frecuencia corre.
  final DateTime martes = DateTime.utc(2026, 9, 22, 10, 30);

  MockTransitRepository build({
    SimulatorConfig config = SimulatorConfig.perfect,
    DateTime? now,
  }) {
    return MockTransitRepository(
      dataset: dataset,
      config: config,
      clock: () => now ?? martes,
    );
  }

  group('el dataset', () {
    test('carga con sus índices armados', () {
      expect(dataset.routes, hasLength(48));
      expect(dataset.stops, hasLength(1507));
      expect(dataset.tripsForRoute('R_01'), isNotEmpty);
      expect(dataset.frequency('R_01_ES_0'), isNotNull);
      expect(dataset.precookedTrips, hasLength(4));
    });

    test('sabe qué servicios corren hoy', () {
      expect(dataset.servicesOn(martes), contains('ES'));
      expect(dataset.servicesOn(DateTime.utc(2026, 9, 20)), contains('FS'));
    });
  });

  group('el simulador', () {
    test('con la misma semilla da la misma posición', () {
      // Sin esto ningún test de arriba podría afirmar nada: la flota estaría
      // en otro lado en cada corrida.
      final TransitSimulator uno = TransitSimulator(dataset: dataset);
      final TransitSimulator dos = TransitSimulator(dataset: dataset);

      final List<VehiclePosition> a = uno.positionsAt(martes);
      final List<VehiclePosition> b = dos.positionsAt(martes);

      expect(a, hasLength(b.length));
      expect(a.first.position.latitude, b.first.position.latitude);
      expect(a.first.position.longitude, b.first.position.longitude);
      expect(a.first.vehicleId, b.first.vehicleId);
    });

    test('la flota sale de service.json, no de un número redondo', () {
      final TransitSimulator simulator = TransitSimulator(dataset: dataset);
      final int esperados = dataset.service
          .where((RouteService row) => row.active)
          .fold(0, (int sum, RouteService row) => sum + row.vehicles);

      expect(simulator.fleetSize, esperados);
      expect(simulator.fleetSize, greaterThan(300));
    });

    test('las rutas sin servicio no reportan un solo vehículo', () {
      // Es el caso que hace falta para que la pantalla "esta ruta no tiene
      // servicio ahora" exista de verdad.
      final TransitSimulator simulator = TransitSimulator(
        dataset: dataset,
        config: SimulatorConfig.perfect,
      );

      expect(simulator.routesWithoutService, isNotEmpty);
      for (final String routeId in simulator.routesWithoutService) {
        expect(simulator.positionsAt(martes, routeId: routeId), isEmpty);
      }
    });

    test('entre reporte y reporte la posición no cambia', () {
      // La cadencia real es de 30 s. Si el simulador entregara una posición
      // nueva en cada consulta, la UI nunca tendría que interpolar y el
      // problema de rendimiento de la fase 5 quedaría escondido.
      final TransitSimulator simulator = TransitSimulator(dataset: dataset);

      final VehiclePosition primera = simulator.positionsAt(martes).first;
      final VehiclePosition dentro = simulator
          .positionsAt(martes.add(const Duration(seconds: 10)))
          .first;
      final VehiclePosition despues = simulator
          .positionsAt(martes.add(const Duration(seconds: 45)))
          .first;

      expect(dentro.position, primera.position);
      expect(dentro.timestamp, primera.timestamp);
      expect(despues.timestamp, isNot(primera.timestamp));
    });

    test('el dato envejece dentro de la ventana de reporte', () {
      final TransitSimulator simulator = TransitSimulator(dataset: dataset);
      final DateTime justo = simulator.lastReportBefore(martes);
      final DateTime tarde = justo.add(const Duration(seconds: 25));

      expect(simulator.positionsAt(tarde).first.ageAt(tarde).inSeconds, 25);
    });

    test('el vehículo se queda sobre su trazo, salvo el ruido declarado', () {
      final TransitSimulator simulator = TransitSimulator(
        dataset: dataset,
        config: const SimulatorConfig(gpsNoiseMinMeters: 5),
      );

      for (final VehiclePosition vehicle
          in simulator.positionsAt(martes).take(40)) {
        final Trip trip = dataset.trip(vehicle.tripId)!;
        final Shape shape = dataset.shape(trip.shapeId!)!;

        // Contra los segmentos, no contra los vértices: el camión va *entre*
        // dos puntos del trazo, y en este feed hay tramos de 150 m.
        double distancia = double.infinity;
        for (int i = 1; i < shape.points.length; i++) {
          distancia = min(
            distancia,
            _distanceToSegment(
              vehicle.position,
              shape.points[i - 1],
              shape.points[i],
            ),
          );
        }

        // El ruido declarado es de 5 a 20 m, perpendicular al trazo. Más que
        // eso sería un camión circulando por la banqueta.
        expect(distancia, lessThan(25), reason: vehicle.vehicleId);
      }
    });

    test('sin fallas, ningún reporte pierde la dirección', () {
      final TransitSimulator simulator = TransitSimulator(
        dataset: dataset,
        config: SimulatorConfig.perfect,
      );

      expect(
        simulator
            .positionsAt(martes)
            .where((VehiclePosition v) => v.bearing == null),
        isEmpty,
      );
    });

    test('con fallas, faltan bearings y faltan vehículos', () {
      final TransitSimulator perfecto = TransitSimulator(
        dataset: dataset,
        config: SimulatorConfig.perfect,
      );
      final TransitSimulator hostil = TransitSimulator(
        dataset: dataset,
        config: SimulatorConfig.hostile,
      );

      final List<VehiclePosition> reportes = hostil.positionsAt(martes);
      final int sinBearing = reportes
          .where((VehiclePosition v) => v.bearing == null)
          .length;

      expect(sinBearing, greaterThan(0));
      // Los que perdieron señal simplemente no están en el feed.
      expect(reportes.length, lessThan(perfecto.positionsAt(martes).length));
    });

    test('la ocupación es determinista y no mueve a nadie de lugar', () {
      // Sale de su propio generador: si sacara un número del ruido de
      // posición, cada golden del mapa cambiaría al agregarla.
      final TransitSimulator con = TransitSimulator(
        dataset: dataset,
        config: SimulatorConfig.perfect,
      );
      final TransitSimulator sin = TransitSimulator(
        dataset: dataset,
        config: SimulatorConfig.perfect.copyWith(missingOccupancyRate: 1),
      );
      final List<VehiclePosition> a = con.positionsAt(martes);
      final List<VehiclePosition> b = sin.positionsAt(martes);

      expect(a.every((VehiclePosition v) => v.occupancyStatus != null), isTrue);
      expect(b.every((VehiclePosition v) => v.occupancyStatus == null), isTrue);
      for (int i = 0; i < a.length; i++) {
        expect(a[i].position, b[i].position);
        expect(a[i].bearing, b[i].bearing);
      }
      expect(
        con.positionsAt(martes).map((VehiclePosition v) => v.occupancyStatus),
        a.map((VehiclePosition v) => v.occupancyStatus),
      );
    });

    test('en hora pico los camiones van más llenos que a media mañana', () {
      final TransitSimulator simulator = TransitSimulator(
        dataset: dataset,
        config: SimulatorConfig.perfect,
      );
      double carga(DateTime t) {
        final List<VehiclePosition> flota = simulator.positionsAt(t);
        return flota
                .map((VehiclePosition v) => v.occupancyStatus!.index)
                .reduce((int x, int y) => x + y) /
            flota.length;
      }

      // Las horas del reloj del teléfono: el pico es de 7 a 9 local.
      expect(
        carga(DateTime(2026, 9, 22, 8)),
        greaterThan(carga(DateTime(2026, 9, 22, 11))),
      );
    });

    test('con fallas, también falta la ocupación en algunos reportes', () {
      final TransitSimulator hostil = TransitSimulator(
        dataset: dataset,
        config: SimulatorConfig.hostile,
      );
      final List<VehiclePosition> reportes = hostil.positionsAt(martes);

      expect(
        reportes.where((VehiclePosition v) => v.occupancyStatus == null),
        isNotEmpty,
      );
      expect(
        reportes.where((VehiclePosition v) => v.occupancyStatus != null),
        isNotEmpty,
      );
    });
  });

  group('el repositorio', () {
    test('entrega el catálogo del feed real', () async {
      final MockTransitRepository repo = build();

      expect(await repo.getRoutes(), hasLength(48));
      expect((await repo.getRoute('R_01')).shortName, 'R01');
      expect((await repo.getShape('R_01_IDA')).points, isNotEmpty);
      expect(await repo.getStopsForRoute('R_01'), isNotEmpty);
    });

    test('pedir algo que no existe es un error de programa, no de red', () {
      final MockTransitRepository repo = build();

      expect(repo.getRoute('R_NO_EXISTE'), throwsStateError);
    });

    test('las paradas cercanas vienen ordenadas y dentro del radio', () async {
      final MockTransitRepository repo = build();
      const LatLng centro = LatLng(21.8818, -102.2916);

      final List<Stop> cerca = await repo.getStopsNear(
        centro,
        radiusMeters: 400,
      );

      expect(cerca, isNotEmpty);
      double previa = 0;
      for (final Stop stop in cerca) {
        final double distancia = _meters(centro, stop.position);
        expect(distancia, lessThanOrEqualTo(400));
        expect(distancia, greaterThanOrEqualTo(previa - 0.001));
        previa = distancia;
      }
    });

    test('con la tasa de error al tope, falla con su propia excepción', () {
      // Tipo propio para que la UI distinga "falló la red" de "hay un bug".
      final MockTransitRepository repo = build(
        config: SimulatorConfig.perfect.copyWith(errorRate: 1),
      );

      expect(repo.getRoutes(), throwsA(isA<TransitDataException>()));
    });

    test('la latencia se siente', () async {
      final MockTransitRepository repo = build(
        config: SimulatorConfig.perfect.copyWith(
          minLatency: const Duration(milliseconds: 120),
          maxLatency: const Duration(milliseconds: 120),
        ),
      );

      final Stopwatch reloj = Stopwatch()..start();
      await repo.getRoutes();
      reloj.stop();

      expect(reloj.elapsedMilliseconds, greaterThanOrEqualTo(100));
    });

    test('el stream de vehículos emite de inmediato', () async {
      // Una pantalla que espera 30 s para mostrar algo está rota, aunque el
      // dato sea correcto.
      final MockTransitRepository repo = build();

      final List<VehiclePosition> primera = await repo
          .watchVehicles(routeId: 'R_01')
          .first;

      expect(primera, isNotEmpty);
      expect(primera.every((VehiclePosition v) => v.routeId == 'R_01'), isTrue);
    });

    test('solo emite las alertas vigentes', () async {
      final MockTransitRepository repo = build();

      final List<ServiceAlert> alertas = await repo.watchAlerts().first;

      expect(alertas, hasLength(1));
      expect(alertas.single.effect, AlertEffect.detour);
    });
  });

  group('arribos: la regla del producto', () {
    /// Una parada servida por una ruta con vehículos.
    String paradaConServicio() {
      final Trip trip = dataset
          .tripsForRoute('R_01')
          .firstWhere((Trip t) => t.serviceId == 'ES');
      return dataset.stopTimesForTrip(trip.id)[10].stopId;
    }

    test('con vehículo en vivo hay minutos y se pueden mostrar', () async {
      final MockTransitRepository repo = build();

      final List<Arrival> arribos = await repo.getArrivals(paradaConServicio());

      expect(arribos, isNotEmpty);
      final Arrival primero = arribos.first;
      expect(primero.confidence, EtaConfidence.live);
      expect(primero.eta, isNotNull);
      expect(primero.showsNumericEta, isTrue);
      expect(primero.freshness, DataFreshness.live);
    });

    test('con el dato vencido no hay número que mostrar', () async {
      // Se fuerza subiendo la cadencia de reporte por encima del umbral de
      // 180 s: el vehículo sigue ahí, pero su último reporte ya no sirve para
      // prometer un minuto. Un número inventado es peor que un "no sé".
      final MockTransitRepository repo = build(
        config: SimulatorConfig.perfect.copyWith(
          reportInterval: const Duration(minutes: 10),
        ),
        now: martes.add(const Duration(minutes: 7)),
      );

      final List<Arrival> arribos = await repo.getArrivals(paradaConServicio());
      final Iterable<Arrival> conVehiculo = arribos.where(
        (Arrival a) => a.vehicleId != null,
      );

      expect(conVehiculo, isNotEmpty);
      for (final Arrival arribo in conVehiculo) {
        expect(arribo.freshness, DataFreshness.unknown);
        expect(arribo.eta, isNull);
        expect(arribo.confidence, EtaConfidence.unknown);
        expect(arribo.showsNumericEta, isFalse);
      }
    });

    test(
      'sin vehículo queda la frecuencia, y se dice que es programada',
      () async {
        // R_52 no tiene servicio a propósito: es el caso en el que la app tiene
        // que responder con la frecuencia en vez de callarse.
        final MockTransitRepository repo = build();
        final Trip trip = dataset
            .tripsForRoute('R_52')
            .firstWhere((Trip t) => t.serviceId == 'ES');
        final String parada = dataset.stopTimesForTrip(trip.id).first.stopId;

        final List<Arrival> arribos = await repo.getArrivals(parada);
        final Arrival sinVehiculo = arribos.firstWhere(
          (Arrival a) => a.routeId == 'R_52',
        );

        expect(sinVehiculo.vehicleId, isNull);
        expect(sinVehiculo.confidence, EtaConfidence.scheduled);
        // Un horario no envejece: su edad es cero y el chip no lo marca viejo.
        expect(sinVehiculo.dataAge, Duration.zero);
        expect(sinVehiculo.showsNumericEta, isTrue);
        // Y trae el intervalo, que es lo que la UI dice: "cada 20 min".
        expect(sinVehiculo.headway, isNotNull);
      },
    );

    test('los arribos en vivo también traen su frecuencia', () async {
      final MockTransitRepository repo = build();

      final List<Arrival> arribos = await repo.getArrivals(paradaConServicio());

      expect(
        arribos.where((Arrival a) => a.vehicleId != null && a.headway != null),
        isNotEmpty,
      );
    });

    test('los arribos en vivo traen la ocupación de su camión', () async {
      final MockTransitRepository repo = build();

      final List<Arrival> arribos = await repo.getArrivals(paradaConServicio());

      expect(
        arribos.where((Arrival a) => a.occupancyStatus != null),
        isNotEmpty,
      );
    });

    test('los arribos vienen ordenados por cercanía', () async {
      final MockTransitRepository repo = build();

      final List<Arrival> arribos = await repo.getArrivals(paradaConServicio());

      Duration previo = Duration.zero;
      for (final Arrival arribo in arribos) {
        final Duration eta = arribo.eta ?? const Duration(days: 1);
        expect(eta, greaterThanOrEqualTo(previo));
        previo = eta;
      }
    });
  });

  group('planificador', () {
    test('cerca de un par precocinado hay itinerario', () async {
      final MockTransitRepository repo = build();
      final PrecookedTrip par = dataset.precookedTrips.firstWhere(
        (PrecookedTrip p) => p.itineraries.isNotEmpty,
      );

      final List<Itinerary> resultados = await repo.planTrip(
        from: par.from,
        to: par.to,
      );

      expect(resultados, isNotEmpty);
      expect(resultados.first.legs.first.isWalk, isTrue);
    });

    test('lejos de todo, la respuesta correcta es la lista vacía', () async {
      // La pantalla de resultados vacíos es tan importante como la de
      // resultados (§4.3).
      final MockTransitRepository repo = build();

      final List<Itinerary> resultados = await repo.planTrip(
        from: const LatLng(19.4326, -99.1332), // Ciudad de México
        to: const LatLng(20.6597, -103.3496), // Guadalajara
      );

      expect(resultados, isEmpty);
    });

    test('el par sin resultados existe como dato', () async {
      final MockTransitRepository repo = build();
      final PrecookedTrip vacio = dataset.precookedTrips.firstWhere(
        (PrecookedTrip p) => p.itineraries.isEmpty,
      );

      expect(await repo.planTrip(from: vacio.from, to: vacio.to), isEmpty);
    });
  });

  group('providers', () {
    test('el repositorio se inyecta por override, sin tocar assets', () async {
      // Como pide la sección 13 del spec: los tests de providers inyectan el
      // repositorio con `overrides`, no cargan el bundle.
      final ProviderContainer container = ProviderContainer(
        // `Override` no está exportado por flutter_riverpod 3: el tipo se
        // infiere del parámetro y no hace falta escribirlo.
        overrides: [
          mockDatasetProvider.overrideWith((Ref ref) async => dataset),
        ],
      );
      addTearDown(container.dispose);

      final TransitRepository repo = await container.read(
        transitRepositoryProvider.future,
      );

      expect(repo, isA<MockTransitRepository>());
      expect(await repo.getRoutes(), hasLength(48));
    });

    test('mover el panel de debug cambia el simulador en caliente', () async {
      final ProviderContainer container = ProviderContainer(
        // `Override` no está exportado por flutter_riverpod 3: el tipo se
        // infiere del parámetro y no hace falta escribirlo.
        overrides: [
          mockDatasetProvider.overrideWith((Ref ref) async => dataset),
        ],
      );
      addTearDown(container.dispose);

      final MockTransitRepository repo = await container.read(
        transitRepositoryProvider.future,
      ) as MockTransitRepository;

      expect(repo.config.errorRate, const SimulatorConfig().errorRate);

      container.read(simulatorSettingsProvider.notifier).makeHostile();
      await container.pump();

      expect(repo.config.errorRate, SimulatorConfig.hostile.errorRate);
      // El repositorio es el mismo objeto: mover un control deslizante no
      // recarga 2.8 MB de dataset.
      expect(
        await container.read(transitRepositoryProvider.future),
        same(repo),
      );
    });
  });
}

double _meters(LatLng a, LatLng b) {
  final double latMid = (a.latitude + b.latitude) / 2 * pi / 180;
  final double x = (b.longitude - a.longitude) * cos(latMid) * 111320;
  final double y = (b.latitude - a.latitude) * 110574;
  return sqrt(x * x + y * y);
}

/// Distancia de un punto al segmento `a`–`b`, que es lo que mide de verdad
/// "qué tan fuera del trazo va".
double _distanceToSegment(LatLng point, LatLng a, LatLng b) {
  final double ax = _x(a, a);
  final double ay = _y(a, a);
  final double bx = _x(b, a);
  final double by = _y(b, a);
  final double px = _x(point, a);
  final double py = _y(point, a);

  final double dx = bx - ax;
  final double dy = by - ay;
  final double lengthSquared = dx * dx + dy * dy;
  if (lengthSquared == 0) {
    return sqrt(pow(px - ax, 2) + pow(py - ay, 2));
  }

  final double t = (((px - ax) * dx + (py - ay) * dy) / lengthSquared).clamp(
    0.0,
    1.0,
  );
  return sqrt(pow(px - (ax + t * dx), 2) + pow(py - (ay + t * dy), 2));
}

/// Metros al este del origen.
double _x(LatLng point, LatLng origin) =>
    (point.longitude - origin.longitude) *
    cos(origin.latitude * pi / 180) *
    111320;

/// Metros al norte del origen.
double _y(LatLng point, LatLng origin) =>
    (point.latitude - origin.latitude) * 110574;
