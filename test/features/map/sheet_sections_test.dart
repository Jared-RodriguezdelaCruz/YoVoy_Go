import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yovoy_go/core/clock/clock_provider.dart';
import 'package:yovoy_go/core/data/mock/mock_dataset.dart';
import 'package:yovoy_go/core/data/mock/simulator_config.dart';
import 'package:yovoy_go/core/data/transit_repository_provider.dart';
import 'package:yovoy_go/core/history/history_providers.dart';
import 'package:yovoy_go/core/history/history_store.dart';
import 'package:yovoy_go/core/history/observation.dart';
import 'package:yovoy_go/core/location/location_service.dart';
import 'package:yovoy_go/core/models/models.dart';
import 'package:yovoy_go/features/favorites/application/favorites_providers.dart';
import 'package:yovoy_go/features/favorites/data/favorites_store.dart';
import 'package:yovoy_go/features/map/application/accessibility_filter.dart';
import 'package:yovoy_go/features/map/application/basemap_style.dart';
import 'package:yovoy_go/features/map/application/map_providers.dart';
import 'package:yovoy_go/features/map/presentation/map_screen.dart';

import '../../helpers/screen_harness.dart';

/// La hoja de inicio con lo del usuario arriba: primero lo que guardó, luego
/// lo que la app aprendió, y hasta abajo lo que está cerca.
void main() {
  late MockDataset dataset;

  setUpAll(() => dataset = loadTestDataset());

  /// Una parada real del dataset, la primera con rutas.
  String stopWithRoutes() => dataset.stops
      .firstWhere((Stop stop) => dataset.tripsForStop(stop.id).isNotEmpty)
      .id;

  Future<ProviderContainer> pumpMap(
    WidgetTester tester, {
    List<UseEvent> uses = const <UseEvent>[],
    Set<String> favorites = const <String>{},
    Set<String> hidden = const <String>{},
  }) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ProviderContainer container = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(() => eightAm),
        mockDatasetProvider.overrideWith((Ref ref) async => dataset),
        simulatorSettingsProvider.overrideWith(
          () => FixedSettings(SimulatorConfig.perfect),
        ),
        basemapStyleProvider.overrideWith(
          (Ref ref, Brightness brightness) async => null,
        ),
        locationServiceProvider.overrideWithValue(const FixedLocation()),
        accessibilityFilterStoreProvider.overrideWithValue(
          InMemoryAccessibilityFilterStore(),
        ),
        favoritesStoreProvider.overrideWithValue(
          InMemoryFavoritesStore(favorites),
        ),
        historyStoreProvider.overrideWithValue(
          InMemoryHistoryStore(uses: uses, hidden: hidden),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MapScreen()),
      ),
    );
    await settle(tester);
    return container;
  }

  /// Lo que deja quien toma la misma parada todos los días a esta hora.
  List<UseEvent> habit(String stopId) => <UseEvent>[
    for (int day = 1; day <= 3; day++)
      UseEvent(
        stopId: stopId,
        kind: UseKind.board,
        at: eightAm.subtract(Duration(days: day)),
      ),
  ];

  testWidgets('sin historial la hoja se ve como siempre', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pumpMap(tester);

    expect(find.text('Paradas cercanas'), findsOneWidget);
    expect(find.text('A esta hora sueles tomar'), findsNothing);
    expect(find.text('Tus favoritos'), findsNothing);

    await unmount(tester, container);
  });

  testWidgets('lo que sueles tomar a esta hora encabeza la hoja', (
    WidgetTester tester,
  ) async {
    final String stopId = stopWithRoutes();
    final ProviderContainer container = await pumpMap(
      tester,
      uses: habit(stopId),
    );

    expect(find.text('A esta hora sueles tomar'), findsOneWidget);
    // El código del poste y la etiqueta comparten renglón en el `StopTile`.
    expect(find.textContaining('a esta hora sueles tomar'), findsWidgets);
    expect(container.read(learnedStopIdsProvider), <String>[stopId]);

    await unmount(tester, container);
  });

  testWidgets('"No me la muestres" la calla y no vuelve', (
    WidgetTester tester,
  ) async {
    final String stopId = stopWithRoutes();
    final ProviderContainer container = await pumpMap(
      tester,
      uses: habit(stopId),
    );

    // La hoja arranca colapsada, con lo de abajo fuera de la pantalla: se
    // abre y se desplaza hasta el botón antes de tocarlo.
    await tester.dragFrom(const Offset(206, 850), const Offset(0, -700));
    await settle(tester);
    await tester.ensureVisible(find.text('No me la muestres'));
    await settle(tester);

    await tester.tap(find.text('No me la muestres'));
    await settle(tester);

    expect(find.text('A esta hora sueles tomar'), findsNothing);
    expect(
      await container.read(hiddenSuggestionsProvider.future),
      contains(stopId),
    );

    await unmount(tester, container);
  });

  testWidgets('un favorito manda sobre lo aprendido y no se repite', (
    WidgetTester tester,
  ) async {
    final String stopId = stopWithRoutes();
    final ProviderContainer container = await pumpMap(
      tester,
      uses: habit(stopId),
      favorites: <String>{stopId},
    );

    expect(find.text('Tus favoritos'), findsOneWidget);
    // La misma parada no sale dos veces: arriba como favorita basta.
    expect(find.text('A esta hora sueles tomar'), findsNothing);

    await unmount(tester, container);
  });

  testWidgets('una parada de arriba no se repite en "Paradas cercanas"', (
    WidgetTester tester,
  ) async {
    // La parada más cercana al centro, que es donde mira el mapa en los tests.
    final ProviderContainer container = await pumpMap(tester);
    final List<NearbyStop> near = await container.read(
      nearbyStopsProvider.future,
    );
    final String closest = near.first.stop.id;
    await unmount(tester, container);

    final ProviderContainer withFavorite = await pumpMap(
      tester,
      favorites: <String>{closest},
    );

    expect(find.text('Tus favoritos'), findsOneWidget);
    expect(
      find.text(near.first.stop.name),
      findsOneWidget,
      reason: 'arriba como favorita, no otra vez abajo',
    );

    await unmount(tester, withFavorite);
  });
}
