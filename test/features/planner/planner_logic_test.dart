import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:yovoy_go/core/data/mock/mock_dataset.dart';
import 'package:yovoy_go/core/data/transit_network.dart';
import 'package:yovoy_go/core/location/location_service.dart';
import 'package:yovoy_go/core/models/models.dart';
import 'package:yovoy_go/core/transit/live_providers.dart';
import 'package:yovoy_go/features/map/application/accessibility_filter.dart';
import 'package:yovoy_go/features/planner/application/leg_timing.dart';
import 'package:yovoy_go/features/planner/application/no_route_help.dart';
import 'package:yovoy_go/features/planner/application/planner_providers.dart';
import 'package:yovoy_go/features/planner/application/ranking.dart';
import 'package:yovoy_go/features/planner/application/ride_session.dart';
import 'package:yovoy_go/features/planner/application/trip_request.dart';
import 'package:yovoy_go/features/route/application/vehicle_placement.dart';

import '../../helpers/screen_harness.dart';

/// La lógica del planificador y del modo viaje, sin pantallas.
void main() {
  late MockDataset dataset;
  late TransitNetwork network;

  setUpAll(() async {
    dataset = loadTestDataset();
    final ProviderContainer container = makeContainer(dataset);
    network = await container.read(transitNetworkProvider.future);
    container.dispose();
  });

  PrecookedTrip pair(String id) =>
      dataset.precookedTrips.firstWhere((PrecookedTrip p) => p.id == id);

  Itinerary option({
    required int minutes,
    int transfers = 0,
    double walk = 300,
  }) => Itinerary(
    legs: const <Leg>[],
    totalDuration: Duration(minutes: minutes),
    transferCount: transfers,
    walkingDistance: walk,
  );

  group('PlaceRef y TripRequest', () {
    test('ida y vuelta por la URL', () {
      const TripRequest request = TripRequest(
        from: HerePlace(),
        to: StopPlace('P606'),
        departMinutes: 8 * 60 + 5,
      );

      final Map<String, String> query = request.toQuery();
      expect(query, <String, String>{
        'from': 'here',
        'to': 'P606',
        'at': '8:05',
      });
      expect(TripRequest.fromQuery(query), request);
    });

    test('un punto se lee como punto, y una hora mala como "ahora"', () {
      final TripRequest request = TripRequest.fromQuery(const <String, String>{
        'from': '21.842672,-102.294872',
        'to': 'P453',
        'at': '25:99',
      });

      expect(request.from, isA<PointPlace>());
      expect(
        (request.from! as PointPlace).point,
        const LatLng(21.842672, -102.294872),
      );
      expect(request.leavesNow, isTrue);
      expect(request.swapped().from, const StopPlace('P453'));
    });

    test('incompleta sin destino', () {
      expect(const TripRequest(from: HerePlace()).isComplete, isFalse);
      expect(TripRequest.fromQuery(const <String, String>{}).from, isNull);
    });

    test('"mi ubicación" sin GPS no se sustituye en silencio', () {
      expect(
        () => resolvePlace(
          const HerePlace(),
          network: network,
          location: const UserLocation.fallback(LocationIssue.denied),
        ),
        throwsA(
          isA<OriginUnavailable>().having(
            (OriginUnavailable e) => e.issue,
            'issue',
            LocationIssue.denied,
          ),
        ),
      );
      expect(
        () => resolvePlace(const StopPlace('NADA'), network: network),
        throwsA(isA<PlaceNotFound>()),
      );
    });

    test('un letrero se resuelve a la parada donde termina el viaje', () {
      final Trip trip = network.trips.first;
      final String? stopId = terminalStopFor(
        network,
        headsign: trip.headsign,
        routeIds: <String>[trip.routeId],
      );

      expect(stopId, network.stopsForTrip(trip.id).last.id);
      expect(
        terminalStopFor(network, headsign: 'Nunca', routeIds: <String>['R_09']),
        isNull,
      );
    });
  });

  group('rankItineraries', () {
    test('un directo le gana a un transbordo que ahorra poco', () {
      final Itinerary directo = option(minutes: 27);
      final Itinerary conTransbordo = option(minutes: 20, transfers: 1);

      expect(rankItineraries(<Itinerary>[conTransbordo, directo]), <Itinerary>[
        directo,
        conTransbordo,
      ]);
    });

    test('un transbordo que ahorra de verdad sí gana', () {
      final Itinerary directo = option(minutes: 45);
      final Itinerary conTransbordo = option(minutes: 25, transfers: 1);

      expect(
        rankItineraries(<Itinerary>[directo, conTransbordo]).first,
        conTransbordo,
      );
    });

    test('la caminata larga pesa más que sus minutos', () {
      final Itinerary cerca = option(minutes: 24);
      // 1 100 m a pie: 600 de más, que pesan 12.5 min.
      final Itinerary lejos = option(minutes: 18, walk: 1100);

      expect(itineraryCost(lejos), greaterThan(itineraryCost(cerca)));
      expect(itineraryCost(cerca), const Duration(minutes: 24));
    });

    test('con los pares reales, el directo sale antes que el de dos '
        'transbordos', () {
      final List<Itinerary> ranked = rankItineraries(
        pair('dos_transbordos').itineraries,
      );

      expect(ranked.first.transferCount, lessThan(2));
      expect(ranked.last.transferCount, 2);
    });
  });

  group('tripPlan', () {
    ProviderContainer container({bool accessibleOnly = false}) {
      final ProviderContainer c = makeContainer(
        dataset,
        accessibility: InMemoryAccessibilityFilterStore(value: accessibleOnly),
      );
      addTearDown(c.dispose);
      return c;
    }

    TripRequest between(PrecookedTrip p) =>
        TripRequest(from: PointPlace(p.from), to: PointPlace(p.to));

    test('trae las opciones ordenadas y con los nombres elegidos', () async {
      final TripPlan plan = await container().read(
        tripPlanProvider(between(pair('directo'))).future,
      );

      expect(plan.ranked, hasLength(pair('directo').itineraries.length));
      expect(
        plan.ranked,
        rankItineraries(plan.ranked),
        reason: 'ya viene ordenada',
      );
      expect(plan.ranked.first.legs.first.from, 'Un punto del mapa');
      expect(plan.ranked.first.legs.last.to, 'Un punto del mapa');
      expect(plan.help, isNull);
      expect(plan.leavesNow, isTrue);
      expect(plan.departAt, eightAm);
    });

    test('con el filtro, esconde lo que no es accesible y lo cuenta', () async {
      final TripPlan plan = await container(accessibleOnly: true)
          .read(tripPlanProvider(between(pair('un_transbordo'))).future);

      for (final (int _, Itinerary itinerary) in plan.visible) {
        expect(itineraryIsAccessible(itinerary, plan.stops), isTrue);
      }
      expect(
        plan.visible.length + plan.hiddenByAccessibility,
        plan.ranked.length,
      );
      // Con el dataset de hoy ninguna opción sube y baja en paradas
      // verificadas: es el caso que la pantalla tiene que resolver bien.
      expect(plan.visible, isEmpty);
      expect(plan.hiddenByAccessibility, plan.ranked.length);
      expect(plan.help, isNull, reason: 'hay opciones, solo están ocultas');
    });

    test('sin resultados trae la salida útil', () async {
      final TripPlan plan = await container().read(
        tripPlanProvider(between(pair('sin_resultados'))).future,
      );

      expect(plan.ranked, isEmpty);
      expect(plan.help, isNotNull);
    });

    test('una opción que no existe es "no encontrada"', () async {
      final ProviderContainer c = container();
      final TripRequest request = between(pair('directo'));
      await c.read(tripPlanProvider(request).future);

      await expectLater(
        c.read(tripOptionProvider(request, 9).future),
        throwsA(isA<TripOptionNotFound>()),
      );
    });
  });

  group('noRouteHelp', () {
    test('cerca de la red da rutas cercanas y hasta dónde se llega', () {
      final Stop origen = network.stop('P453')!; // Rosaura Zapata, en la R09
      final Stop lejos = network.stop('P606')!; // DIF Estatal

      final NoRouteHelp help = noRouteHelp(
        network,
        from: origen.position,
        to: lejos.position,
      );

      expect(help.nearOrigin, isNotEmpty);
      expect(help.nearOrigin.length, lessThanOrEqualTo(5));
      expect(
        help.nearOrigin.map((NearbyRoute r) => r.route.id),
        contains('R_09'),
      );
      for (final NearbyRoute r in help.nearOrigin) {
        expect(r.meters, lessThanOrEqualTo(nearbyMeters));
      }
      expect(help.reach, isNotNull);
      expect(help.reach!.remainingMeters, lessThan(300));
    });

    test('fuera de la red no inventa nada', () {
      final NoRouteHelp help = noRouteHelp(
        network,
        from: const LatLng(21.742, -102.518),
        to: const LatLng(21.60, -102.60),
      );

      expect(help.nearOrigin, isEmpty);
      expect(help.reach, isNull);
    });

    test('distancias como se dicen', () {
      expect(distanceLabel(12), '50 m');
      expect(distanceLabel(274), '250 m');
      expect(distanceLabel(1240), '1.2 km');
    });
  });

  group('horas y textos', () {
    test('cada tramo empieza donde terminó el anterior', () {
      final Itinerary itinerary = pair('un_transbordo').itineraries.first;
      final List<LegTimes> times = legTimes(itinerary, eightAm);

      expect(times.first.start, eightAm);
      for (int i = 1; i < times.length; i++) {
        expect(times[i].start, times[i - 1].end);
      }
      expect(times.last.end, arrivalAt(itinerary, eightAm));
    });

    test('el arribo de subida prefiere el que está en vivo', () {
      const Arrival horario = Arrival(
        routeId: 'R_09',
        routeShortName: 'R09',
        headsign: 'Los Laureles',
        eta: Duration(minutes: 10),
        confidence: EtaConfidence.scheduled,
        dataAge: Duration.zero,
      );
      const Arrival vivo = Arrival(
        routeId: 'R_09',
        routeShortName: 'R09',
        headsign: 'Los Laureles',
        eta: Duration(minutes: 14),
        confidence: EtaConfidence.live,
        dataAge: Duration(seconds: 10),
      );
      const Arrival otra = Arrival(
        routeId: 'R_12',
        routeShortName: 'R12',
        headsign: 'Centro',
        eta: Duration(minutes: 2),
        confidence: EtaConfidence.live,
        dataAge: Duration(seconds: 10),
      );

      expect(boardingArrival(<Arrival>[otra, horario, vivo], 'R_09'), vivo);
      expect(boardingArrival(<Arrival>[otra, horario], 'R_09'), horario);
      expect(boardingArrival(<Arrival>[otra], 'R_09'), isNull);
    });

    test('duraciones y transbordos', () {
      expect(durationLabel(const Duration(seconds: 1637)), '27 min');
      expect(durationLabel(const Duration(minutes: 65)), '1 h 05 min');
      expect(transfersLabel(0), 'directo');
      expect(transfersLabel(1), '1 transbordo');
      expect(transfersLabel(2), '2 transbordos');
    });
  });

  group('modo viaje', () {
    late Leg leg;
    late LegPath path;

    setUpAll(() {
      leg = pair('directo').itineraries.first.busLegs.single;
      path = legPath(network, leg)!;
    });

    VehiclePosition bus(
      int afterIndex, {
      Duration age = const Duration(seconds: 20),
    }) => VehiclePosition(
      vehicleId: 'R_09-01',
      tripId: path.tripId,
      routeId: 'R_09',
      position: path.tripStops[afterIndex].position,
      timestamp: eightAm.subtract(age),
      currentStopSequence: afterIndex + 1,
    );

    test('el tramo se pone en el sentido que sube antes de bajar', () {
      expect(path.tripStops[path.board].id, leg.fromStopId);
      expect(path.alightStop.id, leg.toStopId);
      expect(path.stopCount, greaterThan(2));
    });

    test('elige el camión en la parada antes que el que viene llegando', () {
      final VehiclePosition llegando = bus(path.board - 1)
          .copyWith(vehicleId: 'llegando');
      final VehiclePosition aqui = bus(path.board).copyWith(vehicleId: 'aqui');
      // Ya pasó por la parada: subirse a ese ya no se puede.
      final VehiclePosition lejos = bus(path.board + 3)
          .copyWith(vehicleId: 'lejos');

      final PlacedVehicle? picked = pickBoardedVehicle(
        network: network,
        leg: leg,
        fleet: <VehiclePosition>[lejos, llegando, aqui],
        now: eightAm,
      );
      expect(picked?.vehicle.vehicleId, 'aqui');

      expect(
        pickBoardedVehicle(
          network: network,
          leg: leg,
          fleet: <VehiclePosition>[lejos, llegando],
          now: eightAm,
        )?.vehicle.vehicleId,
        'llegando',
      );
    });

    test('sin señal, o de otra ruta, no se elige', () {
      expect(
        pickBoardedVehicle(
          network: network,
          leg: leg,
          fleet: <VehiclePosition>[
            bus(path.board, age: const Duration(minutes: 5)),
            bus(path.board).copyWith(routeId: 'R_12'),
          ],
          now: eightAm,
        ),
        isNull,
      );
    });

    test('cuenta las paradas que faltan y avisa a las dos y a la una', () {
      RideStatus at(int afterIndex) =>
          rideStatus(path: path, vehicle: bus(afterIndex), now: eightAm);

      expect(at(path.board).stopsLeft, path.stopCount);
      expect(at(path.alight - 3).alert, isNull);
      expect(at(path.alight - 2).alert, RideAlert.prepare);
      expect(at(path.alight - 1).alert, RideAlert.next);
      expect(at(path.alight).alert, RideAlert.here);
      expect(at(path.alight).stopsLeft, 0);
      expect(at(path.alight - 2).strip!.stopNames.last, path.alightStop.name);
    });

    test('con la señal perdida no inventa avance', () {
      final RideStatus viejo = rideStatus(
        path: path,
        vehicle: bus(path.alight - 4, age: const Duration(minutes: 4)),
        now: eightAm,
      );
      expect(viejo.signalLost, isTrue);
      expect(viejo.stopsLeft, 4, reason: 'se queda con el último reporte');

      final RideStatus perdido = rideStatus(
        path: path,
        vehicle: null,
        now: eightAm,
      );
      expect(perdido.signalLost, isTrue);
      expect(perdido.stopsLeft, isNull);
      expect(perdido.alert, isNull);
    });

    test('cada aviso suena una sola vez por tramo', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);
      const TripRequest request = TripRequest(
        from: StopPlace('P453'),
        to: StopPlace('P606'),
      );
      final RideController ride = container.read(
        rideControllerProvider(request, 0).notifier,
      );
      final ProviderSubscription<RideState> keep = container.listen(
        rideControllerProvider(request, 0),
        (RideState? _, RideState _) {},
      );
      addTearDown(keep.close);

      ride.advance();
      ride.board('R_09-01');
      expect(ride.claim(RideAlert.prepare), isTrue);
      expect(ride.claim(RideAlert.prepare), isFalse);
      expect(ride.claim(RideAlert.next), isTrue);
      expect(
        container.read(rideControllerProvider(request, 0)).vehicleId,
        'R_09-01',
      );

      ride.advance();
      final RideState next = container.read(rideControllerProvider(request, 0));
      expect(next.legIndex, 2);
      expect(next.vehicleId, isNull);
      expect(ride.claim(RideAlert.prepare), isTrue, reason: 'tramo nuevo');
    });
  });
}
