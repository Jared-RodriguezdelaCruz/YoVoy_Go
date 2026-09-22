import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yovoy_go/core/data/mock/mock_dataset.dart';
import 'package:yovoy_go/core/data/transit_network.dart';
import 'package:yovoy_go/core/device/screen_awake.dart';
import 'package:yovoy_go/core/lifecycle/app_lifecycle_provider.dart';
import 'package:yovoy_go/core/models/models.dart';
import 'package:yovoy_go/core/transit/live_providers.dart';
import 'package:yovoy_go/features/planner/application/planner_providers.dart';
import 'package:yovoy_go/features/planner/application/ride_session.dart';
import 'package:yovoy_go/features/planner/application/trip_request.dart';
import 'package:yovoy_go/features/planner/presentation/ride_screen.dart';

import '../../helpers/screen_harness.dart';

/// El modo viaje: esperar, subirse, contar paradas, avisar y llegar.
void main() {
  late MockDataset dataset;
  late TransitNetwork network;
  late PrecookedTrip directo;
  late TripRequest request;
  late String rideUrl;
  late Leg leg;
  late LegPath path;
  late int option;

  setUpAll(() async {
    dataset = loadTestDataset();
    directo = dataset.precookedTrips.firstWhere(
      (PrecookedTrip p) => p.id == 'directo',
    );
    request = TripRequest(
      from: PointPlace(directo.from),
      to: PointPlace(directo.to),
    );
    final ProviderContainer container = makeContainer(dataset);
    network = await container.read(transitNetworkProvider.future);
    final TripPlan plan = await container.read(
      tripPlanProvider(request).future,
    );
    container.dispose();
    // La opción de la R09, sea cual sea su lugar en el orden.
    option = plan.ranked.indexWhere(
      (Itinerary i) =>
          i.busLegs.length == 1 && i.busLegs.single.route?.id == 'R_09',
    );
    leg = plan.ranked[option].busLegs.single;
    path = legPath(network, leg)!;
    rideUrl = Uri(
      path: '/planner/option/$option/ride',
      queryParameters: request.toQuery(),
    ).toString();
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

  RideController ride(ProviderContainer container) =>
      container.read(rideControllerProvider(request, option).notifier);

  testWidgets('camina, espera y se sube al camión que está en la parada', (
    WidgetTester tester,
  ) async {
    final FakeScreenAwake awake = FakeScreenAwake();
    final ProviderContainer container = makeContainer(
      dataset,
      screenAwake: awake,
      vehicles: <VehiclePosition>[bus(path.board)],
    );
    await pumpAt(tester, container, rideUrl);

    expect(find.byType(RideScreen), findsOneWidget);
    expect(find.text('Modo viaje · paso 1 de 3'), findsOneWidget);
    expect(find.text('Camina a ${leg.from}'), findsOneWidget);
    expect(awake.on, isTrue);

    await tester.tap(find.text('Ya estoy en la parada'));
    await settle(tester);
    expect(find.text('Espera en ${leg.from}'), findsOneWidget);

    await tester.tap(find.text('Ya me subí'));
    await settle(tester);
    expect(find.text('Faltan ${path.stopCount} paradas'), findsOneWidget);
    expect(find.text('Bajas en ${leg.to}'), findsOneWidget);

    await unmount(tester, container);
    expect(awake.on, isFalse, reason: 'al salir se suelta la pantalla');
  });

  testWidgets('sin camión cerca, "Ya me subí" no deja seguir a uno inventado', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = makeContainer(
      dataset,
      // Ya pasó por la parada.
      vehicles: <VehiclePosition>[bus(path.board + 3)],
    );
    await pumpAt(tester, container, rideUrl);
    ride(container).advance();
    await settle(tester);

    expect(
      find.textContaining('Todavía no veo un camión de la R09'),
      findsOneWidget,
    );
    await tester.tap(find.text('Ya me subí'));
    await settle(tester);
    expect(find.textContaining('Espera en '), findsOneWidget);

    await unmount(tester, container);
  });

  testWidgets('a dos paradas avisa, vibra una sola vez y lo anuncia', (
    WidgetTester tester,
  ) async {
    final List<String> haptics = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final ProviderContainer container = makeContainer(
      dataset,
      vehicles: <VehiclePosition>[bus(path.alight - 2)],
    );
    await pumpAt(tester, container, rideUrl);
    ride(container)
      ..advance()
      ..board('R_09-01');
    await settle(tester);

    expect(find.text('Prepárate: bajas en 2 paradas'), findsOneWidget);
    expect(find.text('Faltan 2 paradas'), findsOneWidget);
    expect(haptics, <String>['HapticFeedbackType.mediumImpact']);
    expect(
      tester.takeAnnouncements().map(
        (CapturedAccessibilityAnnouncement a) => a.message,
      ),
      <String>['Prepárate: bajas en 2 paradas, en ${leg.to}'],
    );

    // Más cuadros con el mismo reporte: no vuelve a vibrar.
    await settle(tester, frames: 20);
    expect(haptics, hasLength(1));

    await unmount(tester, container);
  });

  testWidgets('con la señal perdida lo dice y no inventa avance', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = makeContainer(
      dataset,
      vehicles: <VehiclePosition>[
        bus(path.alight - 4, age: const Duration(minutes: 5)),
      ],
    );
    await pumpAt(tester, container, rideUrl);
    ride(container)
      ..advance()
      ..board('R_09-01');
    await settle(tester);

    expect(find.text('Faltan 4 paradas'), findsOneWidget);
    expect(
      find.textContaining('Perdimos la señal de tu camión'),
      findsOneWidget,
    );

    await unmount(tester, container);
  });

  testWidgets('bajarse, caminar y llegar', (WidgetTester tester) async {
    final ProviderContainer container = makeContainer(
      dataset,
      vehicles: <VehiclePosition>[bus(path.alight)],
    );
    await pumpAt(tester, container, rideUrl);
    ride(container)
      ..advance()
      ..board('R_09-01');
    await settle(tester);
    expect(find.text('Bájate aquí'), findsOneWidget);

    await tester.tap(find.text('Ya bajé'));
    await settle(tester);
    expect(find.text('Camina a tu destino'), findsOneWidget);

    await tester.tap(find.text('Ya llegué'));
    await settle(tester);
    expect(find.text('Llegaste'), findsOneWidget);
    expect(find.text('Modo viaje'), findsOneWidget);

    await unmount(tester, container);
  });

  testWidgets('en segundo plano suelta la pantalla y al volver la retoma', (
    WidgetTester tester,
  ) async {
    final FakeScreenAwake awake = FakeScreenAwake();
    final ProviderContainer container = makeContainer(
      dataset,
      screenAwake: awake,
    );
    await pumpAt(tester, container, rideUrl);

    container.read(appLifecycleProvider.notifier).set(AppLifecycleState.paused);
    await tester.pump();
    expect(awake.on, isFalse);

    container
        .read(appLifecycleProvider.notifier)
        .set(AppLifecycleState.resumed);
    await tester.pump();
    expect(awake.on, isTrue);

    await unmount(tester, container);
  });

  testWidgets('con texto al 200 % no se desborda a bordo', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = makeContainer(
      dataset,
      vehicles: <VehiclePosition>[bus(path.alight - 1)],
    );
    await pumpAt(tester, container, rideUrl, textScale: 2);
    ride(container)
      ..advance()
      ..board('R_09-01');
    await settle(tester);

    expect(find.text('Bájate en la siguiente'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await unmount(tester, container);
  });
}
