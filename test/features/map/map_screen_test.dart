import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yovoy_go/core/data/mock/mock_dataset.dart';
import 'package:yovoy_go/core/data/mock/simulator_config.dart';
import 'package:yovoy_go/design/components/components.dart';
import 'package:yovoy_go/features/map/application/accessibility_filter.dart';
import 'package:yovoy_go/features/map/application/map_providers.dart';
import 'package:yovoy_go/features/map/presentation/layers/transit_markers_layer.dart';
import 'package:yovoy_go/features/map/presentation/map_hit_test.dart';
import 'package:yovoy_go/features/map/presentation/map_sheet.dart';

import '../../helpers/screen_harness.dart';

/// La pantalla de inicio, con el dataset real y sin tocar la red: el fondo
/// vectorial se sustituye por la superficie lisa, que es también lo que ve el
/// usuario sin datos y sin caché.
void main() {
  late MockDataset dataset;

  setUpAll(() => dataset = loadTestDataset());

  Future<ProviderContainer> pumpMap(
    WidgetTester tester, {
    SimulatorConfig config = SimulatorConfig.perfect,
    double textScale = 1,
  }) async {
    final ProviderContainer container = makeContainer(dataset, config: config);
    await pumpMapScreen(tester, container, textScale: textScale);
    return container;
  }

  testWidgets(
    'arranca con la hoja colapsada, "¿Ya me voy?" y paradas cercanas',
    (WidgetTester tester) async {
      final ProviderContainer container = await pumpMap(tester);

      expect(find.text('Paradas cercanas'), findsOneWidget);
      expect(find.byType(StopTile), findsWidgets);
      expect(find.text('Ruta, parada o destino'), findsOneWidget);
      expect(find.byTooltip('Ir a mi ubicación'), findsOneWidget);
      expect(find.text('© OpenMapTiles © OpenStreetMap'), findsOneWidget);

      await unmount(tester, container);
    },
  );

  testWidgets('"Solo accesibles" se nombra en la hoja y se recuerda', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pumpMap(tester);

    expect(find.text('Solo accesibles'), findsOneWidget);
    await tester.tap(find.text('Solo accesibles'));
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Paradas accesibles cercanas'), findsOneWidget);
    expect(container.read(accessibleOnlyProvider).value, isTrue);
    final InMemoryAccessibilityFilterStore store = container.read(
      accessibilityFilterStoreProvider,
    ) as InMemoryAccessibilityFilterStore;
    expect(store.value, isTrue);

    await unmount(tester, container);
  });

  testWidgets(
    'la hoja se detiene en 120 px, 45 % y 90 % (o bajo la búsqueda)',
    (WidgetTester tester) async {
      final ProviderContainer container = await pumpMap(tester);

      final DraggableScrollableSheet sheet = tester.widget(
        find.byType(DraggableScrollableSheet),
      );
      expect(sheet.minChildSize, closeTo(120 / 915, 1e-9));
      expect(sheet.initialChildSize, sheet.minChildSize);
      expect(sheet.snapSizes, contains(SheetStops.half));
      // Sin barra de estado en el test, el 90 % no alcanza la búsqueda.
      expect(sheet.maxChildSize, SheetStops.full);
      // Con la barra de estado de un Pixel 8, se detiene debajo de la búsqueda.
      expect(
        SheetStops.fullFor(915, topInset: 48),
        closeTo(1 - (48 + SheetStops.searchBarPixels) / 915, 1e-9),
      );
      expect(SheetStops.fullFor(915, topInset: 48), lessThan(SheetStops.full));

      await unmount(tester, container);
    },
  );

  testWidgets('no hay un solo BackdropFilter sobre el mapa', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pumpMap(tester);
    expect(find.byType(BackdropFilter), findsNothing);
    await unmount(tester, container);
  });

  testWidgets('tocar un camión abre la tira con luz de recorrido', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pumpMap(tester);

    final MapHitRegistry hits = tester
        .widget<TransitMarkersLayer>(find.byType(TransitMarkersLayer))
        .hits;
    final Rect map = tester.getRect(find.byType(TransitMarkersLayer));
    // Un camión suelto, arriba de la hoja y debajo de la barra de búsqueda.
    final VehicleHit bus = hits.all.whereType<VehicleHit>().firstWhere(
      (VehicleHit h) => h.point.dy > 140 && h.point.dy < map.height - 200,
    );

    await tester.tapAt(map.topLeft + bus.point);
    // flutter_map espera a descartar un doble toque antes de avisar.
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(
      container.read(mapSelectionStateProvider),
      isA<VehicleSelected>().having(
        (VehicleSelected s) => s.vehicleId,
        'vehicleId',
        bus.vehicleId,
      ),
    );
    expect(find.byType(RouteStrip), findsOneWidget);
    expect(find.textContaining('Próxima parada'), findsOneWidget);

    await unmount(tester, container);
  });

  testWidgets('buscar "20" ofrece la ruta y la enciende', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pumpMap(tester);

    await tester.enterText(find.byType(TextField), '20');
    await tester.pump();
    expect(find.text('Rutas'), findsOneWidget);

    await tester.tap(find.text('R20N').first);
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(container.read(mapSelectionStateProvider).litRouteId, 'R_20N');
    expect(find.textContaining('reportando'), findsOneWidget);

    await unmount(tester, container);
  });

  testWidgets('elegir una parada en la hoja muestra sus arribos', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pumpMap(tester);

    // Colapsada solo se ve "¿Ya me voy?": se sube la hoja como lo haría una
    // persona, desde su borde.
    await tester.dragFrom(const Offset(206, 915 - 100), const Offset(0, -420));
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(StopTile).hitTestable(), findsWidgets);

    await tester.tap(find.byType(StopTile).hitTestable().first);
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(container.read(mapSelectionStateProvider), isA<StopSelected>());
    expect(find.byTooltip('Cerrar'), findsOneWidget);

    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(mapSelectionStateProvider), isA<NothingSelected>());

    await unmount(tester, container);
  });

  testWidgets(
    'en modo hostil la pantalla aguanta: carga, falla y se recupera',
    (WidgetTester tester) async {
      // 1.2–4 s de latencia, 20 % de errores, 35 % de camiones sin señal. Lo
      // que se prueba es que ningún estado rompa el layout ni deje la pantalla
      // en blanco mientras pasa el tiempo.
      final ProviderContainer container = await pumpMap(
        tester,
        config: SimulatorConfig.hostile,
      );
      expect(find.byType(SheetSkeleton), findsWidgets);

      for (int i = 0; i < 12; i++) {
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
      }
      // Pasados los 4 s de latencia máxima algo tiene que haber llegado: datos
      // o un error con su botón de reintentar, nunca un skeleton eterno.
      expect(
        find.byType(StopTile).evaluate().isNotEmpty ||
            find.text('Reintentar').evaluate().isNotEmpty,
        isTrue,
      );

      await unmount(tester, container);
    },
  );

  testWidgets('con el texto del sistema al 200 % no se rompe nada', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pumpMap(tester, textScale: 2);
    expect(tester.takeException(), isNull);

    await tester.dragFrom(const Offset(206, 915 - 100), const Offset(0, -700));
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
    expect(find.text('Paradas cercanas'), findsOneWidget);

    await unmount(tester, container);
  });
}
