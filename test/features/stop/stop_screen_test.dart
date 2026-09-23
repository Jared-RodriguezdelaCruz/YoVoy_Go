import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yovoy_go/core/data/mock/mock_dataset.dart';
import 'package:yovoy_go/core/data/mock/simulator_config.dart';
import 'package:yovoy_go/core/transit/reliability.dart';
import 'package:yovoy_go/design/components/components.dart';
import 'package:yovoy_go/features/favorites/data/favorites_store.dart';
import 'package:yovoy_go/features/route/presentation/route_screen.dart';

import '../../helpers/screen_harness.dart';

/// El detalle de parada con el dataset real, a las 8:00 de un lunes.
///
/// P074, Héroes de Chapultepec: pasan 14 rutas, entre ellas la R03, que
/// tiene vigente el desvío de López Mateos.
/// Un historial que siempre vio lo mismo: para probar la nota sin la fase 8.
class _FixedHistory implements ReliabilityHistory {
  const _FixedHistory();

  @override
  Future<ReliabilityStat?> statFor({
    required String routeId,
    required String stopId,
  }) async => const ReliabilityStat(
    observations: 14,
    medianDelay: Duration(minutes: 3),
    p10: Duration(minutes: 1),
    p90: Duration(minutes: 5),
  );
}

void main() {
  const String heroes = '/stop/P074';
  late MockDataset dataset;

  setUpAll(() => dataset = loadTestDataset());

  testWidgets('el letrero: nombre, código, rutas, alerta y arribos', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = makeContainer(dataset);
    await pumpAt(tester, container, heroes);

    expect(find.text('Héroes de Chapultepec'), findsOneWidget);
    expect(find.textContaining('Parada P-074'), findsOneWidget);
    expect(find.textContaining('Pasan 14 rutas'), findsOneWidget);
    expect(find.byType(AlertBanner), findsOneWidget);
    expect(find.text('Desvío en López Mateos por obra'), findsOneWidget);
    expect(find.byType(EtaChip), findsWidgets);

    await unmount(tester, container);
  });

  testWidgets('la alerta se abre para leer el detalle', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = makeContainer(dataset);
    await pumpAt(tester, container, heroes);

    expect(find.textContaining('Toma la parada de Héroes'), findsNothing);
    await tester.tap(find.text('Desvío en López Mateos por obra'));
    await settle(tester, frames: 3);
    expect(find.textContaining('Toma la parada de Héroes'), findsOneWidget);

    await unmount(tester, container);
  });

  testWidgets('cada fila se anuncia completa, en una sola frase', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final ProviderContainer container = makeContainer(dataset);
    await pumpAt(tester, container, heroes);

    // "Ruta R03 a UAA Sur, llega en 4 minutos, dato en vivo. Ver la ruta"
    expect(
      find.bySemanticsLabel(
        RegExp(r'^Ruta R\w+ a .+, (llega en \d+ minutos?|está llegando), '),
      ),
      findsWidgets,
    );

    await unmount(tester, container);
    semantics.dispose();
  });

  testWidgets('la estrella guarda la parada y cambia de estado', (
    WidgetTester tester,
  ) async {
    final InMemoryFavoritesStore store = InMemoryFavoritesStore();
    final ProviderContainer container = makeContainer(
      dataset,
      favorites: store,
    );
    await pumpAt(tester, container, heroes);

    await tester.tap(find.byTooltip('Guardar en favoritos'));
    await settle(tester, frames: 2);

    expect(find.byTooltip('Quitar de favoritos'), findsOneWidget);
    expect(await store.loadStops(), <String>{'P074'});

    await unmount(tester, container);
  });

  testWidgets('sin historial, la parada no dice nada de puntualidad', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = makeContainer(dataset);
    await pumpAt(tester, container, heroes);

    expect(find.textContaining('suele llegar'), findsNothing);

    await unmount(tester, container);
  });

  testWidgets('con historial, cada fila dice cómo le ha ido a esa ruta', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = makeContainer(
      dataset,
      reliability: const _FixedHistory(),
    );
    await pumpAt(tester, container, heroes);

    expect(
      find.text('suele llegar 3 min tarde · según 14 observaciones tuyas'),
      findsWidgets,
    );

    await unmount(tester, container);
  });

  testWidgets('las filas dicen qué tan lleno viene el camión', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = makeContainer(dataset);
    await pumpAt(tester, container, heroes);

    expect(find.byType(OccupancyIndicator), findsWidgets);

    await unmount(tester, container);
  });

  testWidgets('tocar un arribo abre su ruta', (WidgetTester tester) async {
    final ProviderContainer container = makeContainer(dataset);
    await pumpAt(tester, container, heroes);

    await tester.tap(find.byType(EtaChip).first);
    await settle(tester);

    expect(find.byType(RouteScreen), findsOneWidget);

    await unmount(tester, container);
  });

  testWidgets('deslizar hacia abajo vuelve a pedir los arribos', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = makeContainer(dataset);
    await pumpAt(tester, container, heroes);

    await tester.fling(
      find.text('Héroes de Chapultepec'),
      const Offset(0, 400),
      1000,
    );
    await settle(tester);

    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(find.byType(EtaChip), findsWidgets);

    await unmount(tester, container);
  });

  testWidgets('una parada que no existe lo dice y lleva al mapa', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = makeContainer(dataset);
    await pumpAt(tester, container, '/stop/NADA');

    expect(find.text('Esta parada no existe'), findsOneWidget);
    await tester.tap(find.text('Ir al mapa'));
    await settle(tester);
    expect(find.text('mapa'), findsOneWidget);

    await unmount(tester, container);
  });

  testWidgets('mientras carga se ve la forma del letrero, no un spinner', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = makeContainer(
      dataset,
      config: const SimulatorConfig(
        minLatency: Duration(seconds: 3),
        maxLatency: Duration(seconds: 3),
        errorRate: 0,
      ),
    );
    await pumpAt(tester, container, heroes, frames: 2);

    expect(find.byType(SheetSkeleton), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await settle(tester, frames: 40);
    await unmount(tester, container);
    // Las peticiones con latencia que ya iban en camino.
    await tester.pump(const Duration(seconds: 5));
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
    // Al doble de tamaño el letrero, la fecha del horario y las 14 rutas de
    // esta parada no caben de un golpe, y una lista perezosa no construye lo
    // que no se ve: hay que bajar antes de buscar los arribos.
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await settle(tester, frames: 5);

    expect(tester.takeException(), isNull);
    // Con 20 % de error puede quedar el error o los arribos, nunca nada.
    expect(
      find.byType(EtaChip).evaluate().isNotEmpty ||
          find.byType(ErrorState).evaluate().isNotEmpty,
      isTrue,
    );

    await unmount(tester, container);
  });
}
