import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yovoy_go/app/routes.dart';
import 'package:yovoy_go/core/data/mock/mock_dataset.dart';
import 'package:yovoy_go/core/models/models.dart';
import 'package:yovoy_go/design/components/components.dart';
import 'package:yovoy_go/features/favorites/application/favorites_providers.dart';
import 'package:yovoy_go/features/favorites/data/favorites_store.dart';

import '../../helpers/screen_harness.dart';

/// Favoritos, como en la sección 8.5 del spec: paradas con su ETA en vivo y
/// rutas con su placa.
void main() {
  late MockDataset dataset;

  setUpAll(() => dataset = loadTestDataset());

  /// La primera parada del dataset que tiene rutas, y una ruta real.
  String stopId() => dataset.stops
      .firstWhere((Stop stop) => dataset.tripsForStop(stop.id).isNotEmpty)
      .id;

  testWidgets('sin nada guardado dice cómo guardar', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = makeContainer(dataset);
    await pumpAt(tester, container, AppPaths.favorites);

    expect(find.text('Todavía no guardas nada'), findsOneWidget);
    expect(find.textContaining('La estrella'), findsOneWidget);

    await unmount(tester, container);
  });

  testWidgets('una parada guardada trae sus camiones en vivo', (
    WidgetTester tester,
  ) async {
    final String id = stopId();
    final ProviderContainer container = makeContainer(
      dataset,
      favorites: InMemoryFavoritesStore(<String>{id}),
    );
    await pumpAt(tester, container, AppPaths.favorites);

    expect(find.text('Tus paradas'), findsOneWidget);
    expect(find.byType(StopTile), findsOneWidget);
    expect(find.text(dataset.stop(id)!.name), findsOneWidget);
    // Los arribos son de verdad: o hay ETA, o lo dice.
    expect(
      find.byType(EtaChip).evaluate().isNotEmpty ||
          find.text('Sin camiones en camino ahora').evaluate().isNotEmpty,
      isTrue,
    );

    await unmount(tester, container);
  });

  testWidgets('una ruta guardada se ve con su placa y se puede soltar', (
    WidgetTester tester,
  ) async {
    final TransitRoute route = dataset.routes.first;
    final InMemoryFavoritesStore store = InMemoryFavoritesStore(
      const <String>{},
      <String>{route.id},
    );
    final ProviderContainer container = makeContainer(
      dataset,
      favorites: store,
    );
    await pumpAt(tester, container, AppPaths.favorites);

    expect(find.text('Tus rutas'), findsOneWidget);
    expect(find.text(route.shortName), findsOneWidget);
    expect(find.text(route.longName), findsOneWidget);

    await tester.tap(find.byTooltip('Quitar de favoritos').first);
    await settle(tester);

    expect(await container.read(favoriteRoutesProvider.future), isEmpty);
    expect(find.text('Todavía no guardas nada'), findsOneWidget);

    await unmount(tester, container);
  });

  testWidgets('la estrella de una ruta la guarda desde su pantalla', (
    WidgetTester tester,
  ) async {
    final TransitRoute route = dataset.routes.first;
    final ProviderContainer container = makeContainer(dataset);
    await pumpAt(tester, container, AppPaths.route(route.id));

    await tester.tap(find.byTooltip('Guardar en favoritos'));
    await settle(tester);

    expect(await container.read(favoriteRoutesProvider.future), <String>{
      route.id,
    });
    expect(find.byTooltip('Quitar de favoritos'), findsOneWidget);

    await unmount(tester, container);
  });

  testWidgets('con texto al 200 % no se desborda', (WidgetTester tester) async {
    final TransitRoute route = dataset.routes.first;
    final ProviderContainer container = makeContainer(
      dataset,
      favorites: InMemoryFavoritesStore(<String>{stopId()}, <String>{route.id}),
    );
    await pumpAt(tester, container, AppPaths.favorites, textScale: 2);

    expect(tester.takeException(), isNull);

    await unmount(tester, container);
  });
}
