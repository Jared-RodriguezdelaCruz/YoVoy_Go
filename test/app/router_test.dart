import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yovoy_go/app/app.dart';
import 'package:yovoy_go/app/phase_placeholder.dart';
import 'package:yovoy_go/app/router.dart';
import 'package:yovoy_go/app/routes.dart';
import 'package:yovoy_go/core/data/mock/mock_dataset.dart';
import 'package:yovoy_go/core/data/mock/simulator_config.dart';
import 'package:yovoy_go/core/data/transit_repository_provider.dart';
import 'package:yovoy_go/core/location/location_service.dart';
import 'package:yovoy_go/features/map/application/accessibility_filter.dart';
import 'package:yovoy_go/features/map/application/basemap_style.dart';
import 'package:yovoy_go/features/map/presentation/map_screen.dart';
import 'package:yovoy_go/features/route/presentation/route_screen.dart';
import 'package:yovoy_go/features/settings/presentation/settings_screen.dart';
import 'package:yovoy_go/features/stop/presentation/stop_screen.dart';

class _FixedLocation implements LocationService {
  const _FixedLocation();

  @override
  Future<UserLocation> current() async =>
      const UserLocation(position: aguascalientesCenter);

  @override
  Future<void> openSettings(LocationIssue issue) async {}
}

class _FixedSettings extends SimulatorSettings {
  @override
  SimulatorConfig build() => SimulatorConfig.perfect;
}

void main() {
  late ProviderContainer container;
  late MockDataset dataset;

  setUpAll(() {
    dataset = MockDataset.fromJsonStrings(<String, String>{
      for (final String name in MockAssets.files)
        name: File('${MockAssets.directory}/$name').readAsStringSync(),
    });
  });

  setUp(() {
    // El inicio es el mapa, y el mapa carga el dataset, pide la ubicación y
    // baja tiles: nada de eso le toca a un test de navegación.
    container = ProviderContainer(
      overrides: [
        accessibilityFilterStoreProvider.overrideWithValue(
          InMemoryAccessibilityFilterStore(),
        ),
        mockDatasetProvider.overrideWith((Ref ref) async => dataset),
        simulatorSettingsProvider.overrideWith(_FixedSettings.new),
        basemapStyleProvider.overrideWith(
          (Ref ref, Brightness brightness) async => null,
        ),
        locationServiceProvider.overrideWithValue(const _FixedLocation()),
      ],
    );
  });

  /// El mapa nunca se asienta —su `Ticker` mueve la flota todo el tiempo—, así
  /// que se avanza un número fijo de cuadros en vez de `pumpAndSettle`.
  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const YoVoyGoApp(),
      ),
    );
    await settle(tester);
  }

  /// Suelta el stream de 30 s y los relojes **dentro** del test: el framework
  /// revisa que no queden timers vivos antes de correr los `tearDown`.
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump();
  }

  testWidgets('la ruta inicial es el mapa', (WidgetTester tester) async {
    await pumpApp(tester);

    expect(find.byType(MapScreen), findsOneWidget);

    await finish(tester);
  });

  testWidgets('navegar por nombre llega a ajustes', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    container.read(appRouterProvider).goNamed(AppRoute.settings.name);
    await settle(tester);

    expect(find.byType(SettingsScreen), findsOneWidget);

    await finish(tester);
  });

  testWidgets('la parada recibe su parámetro de path', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    container.read(appRouterProvider).go(AppPaths.stop('123'));
    await settle(tester);

    // 123 no existe en el dataset: la pantalla lo dice con el código que
    // le llegó por el path, que es lo que este test revisa.
    expect(find.byType(StopScreen), findsOneWidget);
    expect(find.text('Esta parada no existe'), findsOneWidget);
    expect(find.textContaining('el código 123'), findsOneWidget);

    await finish(tester);
  });

  testWidgets('una parada real ya no es un placeholder', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    container.read(appRouterProvider).go(AppPaths.stop('P090'));
    await settle(tester);

    expect(find.text('Leche San Marcos'), findsOneWidget);
    expect(find.byType(PhasePlaceholder), findsNothing);

    await finish(tester);
  });

  testWidgets('la ruta recibe su parámetro de path', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    container.read(appRouterProvider).go(AppPaths.route('R_01'));
    await settle(tester);

    expect(find.byType(RouteScreen), findsOneWidget);
    expect(find.textContaining('Margaritas'), findsWidgets);
    expect(find.byType(PhasePlaceholder), findsNothing);

    await finish(tester);
  });

  testWidgets('una ruta inexistente cae en la pantalla de error propia', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    container.read(appRouterProvider).go('/no-existe');
    await settle(tester);

    expect(find.text('Esta pantalla no existe'), findsOneWidget);
    expect(find.text('/no-existe'), findsOneWidget);

    await finish(tester);
  });
}
