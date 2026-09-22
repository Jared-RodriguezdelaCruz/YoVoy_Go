import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:yovoy_go/core/history/history_store.dart';
import 'package:yovoy_go/core/history/observation.dart';
import 'package:yovoy_go/core/models/models.dart';
import 'package:yovoy_go/core/transit/reliability.dart';

/// Lunes 21 de septiembre de 2026, 8:00.
final DateTime monday8 = DateTime(2026, 9, 21, 8);

Arrival _arrival({
  required String vehicleId,
  required Duration eta,
  String routeId = 'R09',
  EtaConfidence confidence = EtaConfidence.live,
  Duration dataAge = const Duration(seconds: 10),
}) => Arrival(
  routeId: routeId,
  routeShortName: routeId,
  headsign: 'Hacia el centro',
  dataAge: dataAge,
  eta: eta,
  confidence: confidence,
  vehicleId: vehicleId,
);

VehiclePosition _vehicle({
  required int sequence,
  String id = 'V1',
  Duration age = const Duration(seconds: 10),
}) => VehiclePosition(
  vehicleId: id,
  tripId: 'T1',
  routeId: 'R09',
  position: const LatLng(21.88, -102.29),
  timestamp: monday8.subtract(age),
  currentStopSequence: sequence,
);

List<Stop> _tripStops() => <Stop>[
  for (int i = 0; i < 5; i++)
    Stop(id: 'P$i', name: 'Parada $i', lat: 21.88 + i * 0.001, lon: -102.29),
];

void main() {
  group('TimeBand', () {
    test('parte el día en franjas de dos horas', () {
      expect(TimeBand.of(monday8).slot, 4);
      expect(TimeBand.of(monday8).dayKind, DayKind.weekday);
      expect(TimeBand.of(DateTime(2026, 9, 21, 9, 59)).slot, 4);
      expect(TimeBand.of(DateTime(2026, 9, 21, 10)).slot, 5);
    });

    test('el sábado y el domingo no son días laborales', () {
      expect(TimeBand.of(DateTime(2026, 9, 26, 8)).dayKind, DayKind.saturday);
      expect(TimeBand.of(DateTime(2026, 9, 27, 8)).dayKind, DayKind.sunday);
    });

    test('las franjas vecinas se reconocen, incluso a medianoche', () {
      const TimeBand midnight = TimeBand(dayKind: DayKind.weekday, slot: 0);
      const TimeBand lateNight = TimeBand(dayKind: DayKind.weekday, slot: 11);
      expect(midnight.isNeighbour(lateNight), isTrue);
      expect(midnight.isNeighbour(midnight), isFalse);
    });

    test('se guarda y se vuelve a leer', () {
      final TimeBand band = TimeBand.of(monday8);
      expect(band.code, 'L4');
      expect(TimeBand.parse(band.code), band);
      expect(TimeBand.parse('X9'), isNull);
      expect(TimeBand.parse('L99'), isNull);
    });
  });

  group('lo que se guarda vuelve igual', () {
    test('una observación de arribo', () {
      final ArrivalObservation observation = ArrivalObservation(
        routeId: 'R09',
        stopId: 'P606',
        band: TimeBand.of(monday8),
        delay: const Duration(minutes: -2),
        at: monday8,
      );
      final ArrivalObservation? back = ArrivalObservation.decode(
        observation.encode(),
      );
      expect(back?.routeId, 'R09');
      expect(back?.stopId, 'P606');
      expect(back?.delay, const Duration(minutes: -2));
      expect(back?.band, TimeBand.of(monday8));
      expect(back?.at, monday8);
    });

    test('un evento de uso, con y sin ruta', () {
      final UseEvent withRoute = UseEvent(
        stopId: 'P606',
        routeId: 'R09',
        kind: UseKind.ride,
        at: monday8,
      );
      expect(UseEvent.decode(withRoute.encode())?.routeId, 'R09');

      final UseEvent without = UseEvent(
        stopId: 'P606',
        kind: UseKind.detail,
        at: monday8,
      );
      expect(UseEvent.decode(without.encode())?.routeId, isNull);
    });

    test('una línea rota se ignora en vez de tirar la lectura', () {
      expect(ArrivalObservation.decode('basura'), isNull);
      expect(UseEvent.decode('R09|P606|x|no-es-un-número'), isNull);
    });
  });

  group('promesas', () {
    test('solo prometen los arribos en vivo, con camión y con tiempo', () {
      final Map<String, Promise> promises = promisesFrom(
        arrivals: <Arrival>[
          _arrival(vehicleId: 'V1', eta: const Duration(minutes: 5)),
          // Muy cerca: acertar no demuestra nada.
          _arrival(vehicleId: 'V2', eta: const Duration(seconds: 30)),
          // Un horario no promete un minuto.
          _arrival(
            vehicleId: 'V3',
            eta: const Duration(minutes: 8),
            confidence: EtaConfidence.scheduled,
          ),
          // Dato vencido: la app ni siquiera pinta el número.
          _arrival(
            vehicleId: 'V4',
            eta: const Duration(minutes: 6),
            dataAge: const Duration(minutes: 10),
          ),
        ],
        known: const <String, Promise>{},
        now: monday8,
      );

      expect(promises.keys, <String>['V1']);
      expect(
        promises['V1']!.promisedAt,
        monday8.add(const Duration(minutes: 5)),
      );
    });

    test('una promesa hecha no se reescribe', () {
      final Map<String, Promise> first = promisesFrom(
        arrivals: <Arrival>[
          _arrival(vehicleId: 'V1', eta: const Duration(minutes: 5)),
        ],
        known: const <String, Promise>{},
        now: monday8,
      );
      // Un minuto después el camión dice que ahora llega en 7: la promesa
      // original manda, o siempre se cumpliría.
      final Map<String, Promise> second = promisesFrom(
        arrivals: <Arrival>[
          _arrival(vehicleId: 'V1', eta: const Duration(minutes: 7)),
        ],
        known: first,
        now: monday8.add(const Duration(minutes: 1)),
      );

      expect(second['V1']!.promisedAt, monday8.add(const Duration(minutes: 5)));
    });
  });

  group('avistamientos', () {
    test('pasó cuando su secuencia rebasa la parada', () {
      final StopSighting? before = sightingOf(
        vehicle: _vehicle(sequence: 2),
        tripStops: _tripStops(),
        stopId: 'P2',
        now: monday8,
      );
      expect(before?.passed, isFalse, reason: 'va llegando a P2');

      final StopSighting? after = sightingOf(
        vehicle: _vehicle(sequence: 4),
        tripStops: _tripStops(),
        stopId: 'P2',
        now: monday8,
      );
      expect(after?.passed, isTrue);
    });

    test('sin secuencia no se juzga a nadie', () {
      final VehiclePosition blind = VehiclePosition(
        vehicleId: 'V1',
        tripId: 'T1',
        routeId: 'R09',
        position: const LatLng(21.88, -102.29),
        timestamp: monday8,
      );
      expect(
        sightingOf(
          vehicle: blind,
          tripStops: _tripStops(),
          stopId: 'P2',
          now: monday8,
        ),
        isNull,
      );
    });

    test('un reporte de más de tres minutos no fecha nada', () {
      final StopSighting? old = sightingOf(
        vehicle: _vehicle(sequence: 4, age: const Duration(minutes: 5)),
        tripStops: _tripStops(),
        stopId: 'P2',
        now: monday8,
      );
      expect(old?.isFresh, isFalse);
    });
  });

  group('cerrar promesas', () {
    Promise promise({Duration lastSeen = Duration.zero}) => Promise(
      vehicleId: 'V1',
      routeId: 'R09',
      promisedAt: monday8.add(const Duration(minutes: 5)),
      madeAt: monday8,
      lastSeenAt: monday8.subtract(lastSeen),
    );

    test('al pasar, la diferencia queda anotada', () {
      final DateTime passedAt = monday8.add(const Duration(minutes: 8));
      final ({
        List<ArrivalObservation> observations,
        Map<String, Promise> pending,
      })
      settled = settlePromises(
        promises: <String, Promise>{'V1': promise()},
        sightings: <StopSighting>[
          const StopSighting(
            vehicleId: 'V1',
            passed: true,
            age: Duration(seconds: 20),
          ),
        ],
        stopId: 'P606',
        now: passedAt,
      );

      expect(settled.pending, isEmpty);
      expect(settled.observations.single.delay, const Duration(minutes: 3));
      expect(settled.observations.single.stopId, 'P606');
      expect(settled.observations.single.routeId, 'R09');
    });

    test('mientras no pasa, la promesa sigue viva y se refresca', () {
      final DateTime later = monday8.add(const Duration(minutes: 2));
      final ({
        List<ArrivalObservation> observations,
        Map<String, Promise> pending,
      })
      settled = settlePromises(
        promises: <String, Promise>{'V1': promise()},
        sightings: <StopSighting>[
          const StopSighting(
            vehicleId: 'V1',
            passed: false,
            age: Duration(seconds: 20),
          ),
        ],
        stopId: 'P606',
        now: later,
      );

      expect(settled.observations, isEmpty);
      expect(settled.pending['V1']!.lastSeenAt, later);
    });

    test('sin señal no se inventa un retraso: la promesa se tira', () {
      final ({
        List<ArrivalObservation> observations,
        Map<String, Promise> pending,
      })
      settled = settlePromises(
        promises: <String, Promise>{
          'V1': promise(lastSeen: const Duration(minutes: 4)),
        },
        sightings: const <StopSighting>[],
        stopId: 'P606',
        now: monday8,
      );

      expect(settled.observations, isEmpty);
      expect(settled.pending, isEmpty);
    });

    test('un silencio corto no la tira todavía', () {
      final ({
        List<ArrivalObservation> observations,
        Map<String, Promise> pending,
      })
      settled = settlePromises(
        promises: <String, Promise>{
          'V1': promise(lastSeen: const Duration(minutes: 1)),
        },
        sightings: const <StopSighting>[],
        stopId: 'P606',
        now: monday8,
      );

      expect(settled.pending.keys, <String>['V1']);
    });
  });

  group('el resumen', () {
    test('mediana y percentiles, no promedio', () {
      // Ocho a tiempo y un desastre: la mediana no se deja arrastrar.
      final ReliabilityStat? stat = statFrom(<Duration>[
        for (int i = 0; i < 8; i++) const Duration(minutes: 1),
        const Duration(minutes: 40),
      ]);

      expect(stat?.observations, 9);
      expect(stat?.medianDelay, const Duration(minutes: 1));
      expect(stat?.p90, const Duration(minutes: 40));
    });

    test('sin observaciones no hay resumen', () {
      expect(statFrom(const <Duration>[]), isNull);
    });

    test('con menos de cinco, la app sigue callada', () {
      final ReliabilityStat? stat = statFrom(<Duration>[
        for (int i = 0; i < 4; i++) const Duration(minutes: 3),
      ]);
      expect(ReliabilityCopy.describe(stat), isNull);
    });

    test('con cinco ya dice lo que vio', () {
      final ReliabilityStat? stat = statFrom(<Duration>[
        for (int i = 0; i < 5; i++) const Duration(minutes: 3),
      ]);
      expect(
        ReliabilityCopy.describe(stat),
        'suele llegar 3 min tarde · según 5 observaciones tuyas',
      );
    });
  });

  group('lo aprendido', () {
    UseEvent use(Duration ago, {String stopId = 'P606', UseKind? kind}) =>
        UseEvent(
          stopId: stopId,
          kind: kind ?? UseKind.detail,
          at: monday8.subtract(ago),
        );

    test('lo de siempre a esta hora encabeza', () {
      final List<String> learned = learnedStops(
        uses: <UseEvent>[
          use(const Duration(days: 1), kind: UseKind.board),
          use(const Duration(days: 2), kind: UseKind.board),
          use(const Duration(days: 3), kind: UseKind.ride),
        ],
        now: monday8,
      );
      expect(learned, <String>['P606']);
    });

    test('una visita suelta no alcanza para sugerir', () {
      expect(
        learnedStops(uses: <UseEvent>[use(Duration.zero)], now: monday8),
        isEmpty,
      );
    });

    test('lo de otra hora pesa mucho menos', () {
      // Tres usos, pero de madrugada: a las 8 de la mañana no dicen nada.
      final List<UseEvent> nightly = <UseEvent>[
        for (int i = 1; i <= 3; i++)
          UseEvent(
            stopId: 'P606',
            kind: UseKind.board,
            at: DateTime(2026, 9, 21 - i, 2),
          ),
      ];
      expect(learnedStops(uses: nightly, now: monday8), isEmpty);
    });

    test('lo viejo se desvanece', () {
      final double fresh = learnedScore(
        uses: <UseEvent>[use(const Duration(days: 1))],
        now: monday8,
        stopId: 'P606',
      );
      final double old = learnedScore(
        uses: <UseEvent>[use(const Duration(days: 29))],
        now: monday8,
        stopId: 'P606',
      );
      expect(old, lessThan(fresh / 3));
    });

    test('lo oculto no vuelve', () {
      final List<UseEvent> uses = <UseEvent>[
        for (int i = 1; i <= 3; i++)
          use(Duration(days: i), kind: UseKind.board),
      ];
      expect(
        learnedStops(uses: uses, now: monday8, hidden: <String>{'P606'}),
        isEmpty,
      );
    });

    test('a lo más tres sugerencias, de mayor a menor', () {
      final List<UseEvent> uses = <UseEvent>[
        for (final String stopId in <String>['A', 'B', 'C', 'D'])
          for (int i = 1; i <= 4; i++)
            use(
              Duration(days: i),
              stopId: stopId,
              kind: UseKind.ride,
            ),
        // La de siempre, además, se usó hoy.
        use(Duration.zero, stopId: 'B', kind: UseKind.ride),
      ];
      final List<String> learned = learnedStops(uses: uses, now: monday8);

      expect(learned.length, 3);
      expect(learned.first, 'B');
    });
  });

  group('el historial no crece sin fin', () {
    test('se queda con lo último', () async {
      final InMemoryHistoryStore store = InMemoryHistoryStore();
      await store.saveArrivals(<ArrivalObservation>[
        for (int i = 0; i < maxArrivalObservations + 20; i++)
          ArrivalObservation(
            routeId: 'R$i',
            stopId: 'P606',
            band: TimeBand.of(monday8),
            delay: Duration(seconds: i),
            at: monday8,
          ),
      ]);

      final List<ArrivalObservation> kept = await store.loadArrivals();
      expect(kept.length, maxArrivalObservations);
      expect(kept.first.routeId, 'R20', reason: 'lo viejo se cae primero');
    });
  });
}
