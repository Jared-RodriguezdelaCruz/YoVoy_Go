import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:yovoy_go/core/config/freshness.dart';
import 'package:yovoy_go/core/models/models.dart';

Arrival arribo({
  Duration? eta,
  EtaConfidence confidence = EtaConfidence.live,
  Duration dataAge = const Duration(seconds: 10),
}) => Arrival(
  routeId: 'r20',
  routeShortName: '20',
  headsign: 'Centro',
  eta: eta,
  confidence: confidence,
  dataAge: dataAge,
);

void main() {
  group('Arrival', () {
    test('round-trip JSON', () {
      const Map<String, dynamic> json = <String, dynamic>{
        'route_id': 'r20',
        'route_short_name': '20',
        'headsign': 'Centro',
        'data_age': 12,
        'eta': 240,
        'confidence': 'live',
        'vehicle_id': 'v7',
        'occupancy_status': 'MANY_SEATS_AVAILABLE',
      };

      final Arrival arrival = Arrival.fromJson(json);

      expect(arrival.eta, const Duration(minutes: 4));
      expect(arrival.confidence, EtaConfidence.live);
      expect(arrival.toJson(), json);
    });

    test('un ETA nulo es un estado válido, no un error', () {
      final Arrival arrival = Arrival.fromJson(<String, dynamic>{
        'route_id': 'r31',
        'route_short_name': '31',
        'headsign': 'Morelos',
        'data_age': 400,
      });

      expect(arrival.eta, isNull);
      expect(arrival.confidence, EtaConfidence.unknown);
      expect(arrival.showsNumericEta, isFalse);
    });

    test('dato fresco y en vivo: se muestra el número', () {
      final Arrival arrival = arribo(eta: const Duration(minutes: 4));

      expect(arrival.freshness, DataFreshness.live);
      expect(arrival.showsNumericEta, isTrue);
    });

    test('dato viejo pero dentro del umbral: todavía se muestra', () {
      final Arrival arrival = arribo(
        eta: const Duration(minutes: 4),
        dataAge: const Duration(seconds: 120),
      );

      expect(arrival.freshness, DataFreshness.stale);
      expect(arrival.showsNumericEta, isTrue);
    });

    test('pasados los 180 s no hay número, aunque haya ETA', () {
      // Es la regla central del producto: un número inventado es peor que un
      // "no sé".
      final Arrival arrival = arribo(
        eta: const Duration(minutes: 4),
        dataAge: const Duration(seconds: 181),
      );

      expect(arrival.freshness, DataFreshness.unknown);
      expect(arrival.showsNumericEta, isFalse);
    });

    test('confianza desconocida tampoco muestra número', () {
      final Arrival arrival = arribo(
        eta: const Duration(minutes: 4),
        confidence: EtaConfidence.unknown,
      );

      expect(arrival.showsNumericEta, isFalse);
    });

    test('un horario programado y fresco sí muestra número', () {
      final Arrival arrival = arribo(
        eta: const Duration(minutes: 9),
        confidence: EtaConfidence.scheduled,
      );

      expect(arrival.showsNumericEta, isTrue);
    });
  });

  group('Leg', () {
    test('round-trip JSON de un tramo a pie', () {
      final Leg leg = Leg.fromJson(<String, dynamic>{
        'type': 'walk',
        'from': 'Tu ubicación',
        'to': 'Bonanza',
        'duration': 420,
        'geometry': <Map<String, dynamic>>[
          <String, dynamic>{'lat': 21.88, 'lon': -102.29},
        ],
      });

      expect(leg.isWalk, isTrue);
      expect(leg.route, isNull);
      expect(leg.duration, const Duration(minutes: 7));
      expect(leg.toJson()['type'], 'walk');
    });

    test('un tramo de camión lleva su ruta', () {
      final Leg leg = Leg.fromJson(<String, dynamic>{
        'type': 'bus',
        'from': 'Bonanza',
        'to': 'Centro',
        'duration': 900,
        'route': <String, dynamic>{
          'route_id': 'r20',
          'route_short_name': '20',
          'route_long_name': 'Centro — Bonanza',
        },
      });

      expect(leg.isWalk, isFalse);
      expect(leg.route?.shortName, '20');
      expect(leg.geometry, isEmpty);
    });
  });

  group('Itinerary', () {
    final Itinerary itinerario = Itinerary(
      totalDuration: const Duration(minutes: 32),
      walkingDistance: 640,
      transferCount: 1,
      legs: <Leg>[
        const Leg(
          type: LegType.walk,
          from: 'Tu ubicación',
          to: 'Bonanza',
          duration: Duration(minutes: 7),
        ),
        const Leg(
          type: LegType.bus,
          from: 'Bonanza',
          to: 'Héroes',
          duration: Duration(minutes: 14),
          route: TransitRoute(
            id: 'r20',
            shortName: '20',
            longName: 'Centro — Bonanza',
          ),
        ),
        const Leg(
          type: LegType.bus,
          from: 'Héroes',
          to: 'Centro',
          duration: Duration(minutes: 11),
          route: TransitRoute(
            id: 'r31',
            shortName: '31',
            longName: 'Insurgentes — Morelos',
          ),
        ),
      ],
    );

    test('busLegs deja fuera los tramos a pie', () {
      expect(itinerario.busLegs, hasLength(2));
      expect(
        itinerario.busLegs.map((Leg leg) => leg.route?.shortName),
        <String>['20', '31'],
      );
    });

    test('round-trip JSON conserva los tramos', () {
      final Itinerary recuperado = Itinerary.fromJson(itinerario.toJson());

      expect(recuperado.legs, hasLength(3));
      expect(recuperado.walkingDistance, 640);
      expect(recuperado.transferCount, 1);
      expect(recuperado.totalDuration, const Duration(minutes: 32));
    });

    test('un viaje sin camiones tiene busLegs vacío', () {
      const Itinerary aPie = Itinerary(
        totalDuration: Duration(minutes: 12),
        legs: <Leg>[
          Leg(
            type: LegType.walk,
            from: 'Tu ubicación',
            to: 'Plaza',
            duration: Duration(minutes: 12),
          ),
        ],
      );

      expect(aPie.busLegs, isEmpty);
      expect(aPie.fare, isNull);
    });
  });

  test('LatLng sobrevive dentro de la geometría de un tramo', () {
    final Leg leg = Leg(
      type: LegType.bus,
      from: 'Bonanza',
      to: 'Centro',
      duration: const Duration(minutes: 9),
      geometry: <LatLng>[LatLng(21.88, -102.29), LatLng(21.89, -102.30)],
    );

    expect(Leg.fromJson(leg.toJson()).geometry, hasLength(2));
  });
}
