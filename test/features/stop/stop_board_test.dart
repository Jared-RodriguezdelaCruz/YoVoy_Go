import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:yovoy_go/core/data/mock/mock_dataset.dart';
import 'package:yovoy_go/core/data/mock/simulator_config.dart';
import 'package:yovoy_go/core/device/screen_awake.dart';
import 'package:yovoy_go/core/lifecycle/app_lifecycle_provider.dart';
import 'package:yovoy_go/core/models/models.dart';
import 'package:yovoy_go/design/components/components.dart';
import 'package:yovoy_go/features/stop/application/stop_board.dart';
import 'package:yovoy_go/features/stop/presentation/stop_board_screen.dart';
import 'package:yovoy_go/features/stop/presentation/stop_screen.dart';

import '../../helpers/screen_harness.dart';

/// El modo paradero: la lógica de la tira de acercamiento, y la pantalla.
void main() {
  final DateTime now = DateTime(2026, 9, 21, 8);

  List<Stop> line(int n) => <Stop>[
    for (int i = 0; i < n; i++)
      Stop(id: 'S$i', name: 'Parada $i', lat: 21.88 + i * 0.001, lon: -102.29),
  ];

  VehiclePosition bus({int? sequence, LatLng? at}) => VehiclePosition(
    vehicleId: 'V1',
    tripId: 'T1',
    routeId: 'R1',
    position: at ?? const LatLng(21.88, -102.29),
    timestamp: now.subtract(const Duration(seconds: 20)),
    currentStopSequence: sequence,
  );

  group('approachStrip', () {
    test('va de donde está el camión hasta esta parada', () {
      final ApproachStrip? strip = approachStrip(
        tripStops: line(10),
        stopId: 'S5',
        vehicle: bus(sequence: 4), // pasó por S3
        now: now,
      );

      expect(strip!.stopNames, <String>['Parada 3', 'Parada 4', 'Parada 5']);
      // Entre S3 y S4: a la cuarta parte del tramo de dos.
      expect(strip.progress, closeTo(0.25, 1e-9));
      expect(strip.dataAge, const Duration(seconds: 20));
    });

    test('lejos, recorta a las últimas cinco paradas', () {
      final ApproachStrip? strip = approachStrip(
        tripStops: line(20),
        stopId: 'S15',
        vehicle: bus(sequence: 2),
        now: now,
      );

      expect(strip!.stopNames, hasLength(5));
      expect(strip.stopNames.last, 'Parada 15');
      // El camión va antes del inicio de la tira: se dibuja en su arranque.
      expect(strip.progress, lessThanOrEqualTo(0.125));
    });

    test('si el camión ya pasó, no hay tira', () {
      expect(
        approachStrip(
          tripStops: line(10),
          stopId: 'S3',
          vehicle: bus(sequence: 6),
          now: now,
        ),
        isNull,
      );
    });

    test('si el camión está en la parada, va al final de la tira', () {
      final ApproachStrip? strip = approachStrip(
        tripStops: line(10),
        stopId: 'S5',
        vehicle: bus(sequence: 6), // está en S5
        now: now,
      );

      expect(strip!.stopNames.last, 'Parada 5');
      expect(strip.stopNames, hasLength(5));
      expect(strip.progress, 1);
    });

    test('sin secuencia usa la parada más cercana', () {
      final List<Stop> stops = line(10);
      final ApproachStrip? strip = approachStrip(
        tripStops: stops,
        stopId: 'S6',
        vehicle: bus(at: stops[2].position),
        now: now,
      );

      expect(strip!.stopNames.first, 'Parada 2');
    });

    test('una parada que no está en el viaje no da tira', () {
      expect(
        approachStrip(
          tripStops: line(5),
          stopId: 'OTRA',
          vehicle: bus(sequence: 1),
          now: now,
        ),
        isNull,
      );
    });
  });

  group('leadArrival', () {
    const Arrival horario = Arrival(
      routeId: 'R_07',
      routeShortName: 'R07',
      headsign: 'Las Palmas',
      eta: Duration(minutes: 10),
      confidence: EtaConfidence.scheduled,
      dataAge: Duration.zero,
    );
    const Arrival sinSenal = Arrival(
      routeId: 'R_12',
      routeShortName: 'R12',
      headsign: 'Centro',
      dataAge: Duration(minutes: 5),
    );
    const Arrival enVivo = Arrival(
      routeId: 'R_03',
      routeShortName: 'R03',
      headsign: 'UAA Sur',
      eta: Duration(minutes: 12),
      confidence: EtaConfidence.live,
      dataAge: Duration(seconds: 10),
    );

    test('gana el primero en vivo, aunque un horario ordene antes', () {
      expect(leadArrival(<Arrival>[sinSenal, enVivo]), enVivo);
      expect(leadArrival(<Arrival>[horario, enVivo]), enVivo);
    });

    test('sin ninguno en vivo, el primero de la lista', () {
      expect(leadArrival(<Arrival>[sinSenal, horario]), sinSenal);
      expect(leadArrival(const <Arrival>[]), isNull);
    });
  });

  group('la pantalla', () {
    late MockDataset dataset;
    const String heroes = '/stop/P074/board';

    setUpAll(() => dataset = loadTestDataset());

    testWidgets('un número enorme, la ruta y la pantalla encendida', (
      WidgetTester tester,
    ) async {
      final FakeScreenAwake awake = FakeScreenAwake();
      final ProviderContainer container = makeContainer(
        dataset,
        screenAwake: awake,
      );
      await pumpAt(tester, container, heroes);

      expect(find.byType(StopBoardScreen), findsOneWidget);
      // El nombre va arriba y al final de la tira, que termina aquí.
      expect(find.text('Héroes de Chapultepec'), findsWidgets);
      expect(find.byType(RouteBadge), findsOneWidget);
      expect(find.textContaining('Hacia '), findsOneWidget);
      expect(find.textContaining('Después: '), findsOneWidget);
      expect(awake.on, isTrue);

      await unmount(tester, container);
      expect(awake.on, isFalse);
    });

    testWidgets('en segundo plano suelta la pantalla y al volver la retoma', (
      WidgetTester tester,
    ) async {
      final FakeScreenAwake awake = FakeScreenAwake();
      final ProviderContainer container = makeContainer(
        dataset,
        screenAwake: awake,
      );
      await pumpAt(tester, container, heroes);

      container
          .read(appLifecycleProvider.notifier)
          .set(AppLifecycleState.paused);
      await tester.pump();
      expect(awake.on, isFalse);

      container
          .read(appLifecycleProvider.notifier)
          .set(AppLifecycleState.resumed);
      await tester.pump();
      expect(awake.on, isTrue);

      await unmount(tester, container);
    });

    testWidgets('se entra desde la parada y un toque sale', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = makeContainer(dataset);
      await pumpAt(tester, container, '/stop/P074');

      await tester.tap(find.byTooltip('Modo paradero'));
      await settle(tester);
      expect(find.byType(StopBoardScreen), findsOneWidget);

      await tester.tapAt(const Offset(200, 450));
      await settle(tester);
      expect(find.byType(StopBoardScreen), findsNothing);
      expect(find.byType(StopScreen), findsOneWidget);

      await unmount(tester, container);
    });

    testWidgets('el lector de pantalla sabe cómo salir', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      final ProviderContainer container = makeContainer(dataset);
      await pumpAt(tester, container, heroes);

      expect(
        find.bySemanticsLabel(RegExp('Modo paradero. Toca para salir')),
        findsOneWidget,
      );
      expect(find.byTooltip('Salir del modo paradero'), findsOneWidget);

      await unmount(tester, container);
      semantics.dispose();
    });

    testWidgets('en modo hostil y con texto al 200 % no se desborda', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = makeContainer(
        dataset,
        config: SimulatorConfig.hostile,
      );
      await pumpAt(tester, container, heroes, textScale: 2, frames: 60);

      expect(tester.takeException(), isNull);

      await unmount(tester, container);
    });

    testWidgets('una parada que no existe lo dice', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = makeContainer(dataset);
      await pumpAt(tester, container, '/stop/NADA/board');

      expect(find.text('Esta parada no existe'), findsOneWidget);

      await unmount(tester, container);
    });
  });
}
