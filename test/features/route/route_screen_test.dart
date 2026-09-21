import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yovoy_go/core/data/mock/mock_dataset.dart';
import 'package:yovoy_go/core/data/mock/simulator_config.dart';
import 'package:yovoy_go/design/components/components.dart';
import 'package:yovoy_go/features/route/presentation/route_minimap.dart';
import 'package:yovoy_go/features/route/presentation/route_stop_ladder.dart';
import 'package:yovoy_go/features/stop/presentation/stop_screen.dart';

import '../../helpers/screen_harness.dart';

/// El detalle de ruta con el dataset real y el reloj fijo.
void main() {
  late MockDataset dataset;

  setUpAll(() => dataset = loadTestDataset());

  testWidgets('trazo, selector de sentido y la tira de pie', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = makeContainer(dataset);
    await pumpAt(tester, container, '/route/R_01');

    expect(find.byType(RouteBadge), findsOneWidget);
    expect(find.byType(RouteMinimap), findsOneWidget);
    expect(find.text('Hacia Margaritas'), findsOneWidget);
    expect(find.text('Hacia Vicente Guerrero'), findsOneWidget);
    expect(find.byType(LadderRow), findsWidgets);

    await unmount(tester, container);
  });

  testWidgets('cambiar de sentido cambia las paradas', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = makeContainer(dataset);
    await pumpAt(tester, container, '/route/R_01');

    final String firstBefore = tester
        .widget<LadderRow>(find.byType(LadderRow).first)
        .stop
        .id;
    await tester.tap(find.text('Hacia Vicente Guerrero'));
    await settle(tester);
    final String firstAfter = tester
        .widget<LadderRow>(find.byType(LadderRow).first)
        .stop
        .id;

    expect(firstAfter, isNot(firstBefore));

    await unmount(tester, container);
  });

  testWidgets('a las 8:00 hay camiones sobre la tira, y se cuentan', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = makeContainer(dataset);
    await pumpAt(tester, container, '/route/R_01');

    expect(find.textContaining('reportando'), findsOneWidget);

    await unmount(tester, container);
  });

  testWidgets('sin camiones lo dice con todas sus letras', (
    WidgetTester tester,
  ) async {
    // La R52 no tiene flota a propósito (`service.json`, active: false):
    // es el caso que dispara este estado.
    final ProviderContainer container = makeContainer(dataset);
    await pumpAt(tester, container, '/route/R_52');

    expect(
      find.text('Ningún camión de esta ruta está reportando ahora.'),
      findsOneWidget,
    );
    // Las paradas siguen ahí: sirven igual.
    expect(find.byType(LadderRow), findsWidgets);

    await unmount(tester, container);
  });

  testWidgets('tocar una parada de la tira abre la parada', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = makeContainer(dataset);
    await pumpAt(tester, container, '/route/R_01');

    await tester.tap(find.byType(LadderRow).first);
    await settle(tester);

    expect(find.byType(StopScreen), findsOneWidget);

    await unmount(tester, container);
  });

  testWidgets('una ruta de un solo sentido no lleva selector', (
    WidgetTester tester,
  ) async {
    // Se busca en el dataset en vez de fijar el id: si el GTFS cambia, el
    // test sigue probando lo mismo.
    final String oneWay = dataset.routes
        .map((r) => r.id)
        .firstWhere(
          (String id) =>
              dataset
                  .tripsForRoute(id)
                  .map((t) => t.directionId)
                  .toSet()
                  .length ==
              1,
        );
    final ProviderContainer container = makeContainer(dataset);
    await pumpAt(tester, container, '/route/$oneWay');

    expect(find.byType(SegmentedButton<int>), findsNothing);
    expect(find.byType(LadderRow), findsWidgets);

    await unmount(tester, container);
  });

  testWidgets('una ruta que no existe lo dice', (WidgetTester tester) async {
    final ProviderContainer container = makeContainer(dataset);
    await pumpAt(tester, container, '/route/R_999');

    expect(find.text('Esta ruta no existe'), findsOneWidget);

    await unmount(tester, container);
  });

  testWidgets('en modo hostil y con texto al 200 % no se desborda', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = makeContainer(
      dataset,
      config: SimulatorConfig.hostile,
    );
    await pumpAt(tester, container, '/route/R_01', textScale: 2, frames: 60);

    expect(tester.takeException(), isNull);

    await unmount(tester, container);
  });
}
