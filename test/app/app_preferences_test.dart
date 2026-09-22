import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yovoy_go/app/app.dart';
import 'package:yovoy_go/core/data/mock/mock_dataset.dart';
import 'package:yovoy_go/core/data/mock/simulator_config.dart';
import 'package:yovoy_go/core/data/transit_repository_provider.dart';
import 'package:yovoy_go/core/location/location_service.dart';
import 'package:yovoy_go/features/map/application/accessibility_filter.dart';
import 'package:yovoy_go/features/map/application/basemap_style.dart';
import 'package:yovoy_go/features/map/presentation/map_screen.dart';
import 'package:yovoy_go/features/settings/application/settings_providers.dart';
import 'package:yovoy_go/features/settings/data/settings_store.dart';

import '../helpers/screen_harness.dart';

/// Lo que se elige en ajustes tiene que llegar a toda la app, no a la pantalla
/// donde se eligió.
void main() {
  late MockDataset dataset;

  setUpAll(() => dataset = loadTestDataset());

  Future<ProviderContainer> pumpApp(
    WidgetTester tester, {
    required AppSettings settings,
    double systemScale = 1,
  }) async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        accessibilityFilterStoreProvider.overrideWithValue(
          InMemoryAccessibilityFilterStore(),
        ),
        mockDatasetProvider.overrideWith((Ref ref) async => dataset),
        simulatorSettingsProvider.overrideWith(
          () => FixedSettings(SimulatorConfig.perfect),
        ),
        basemapStyleProvider.overrideWith(
          (Ref ref, Brightness brightness) async => null,
        ),
        locationServiceProvider.overrideWithValue(const FixedLocation()),
        settingsStoreProvider.overrideWithValue(
          InMemorySettingsStore(settings),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MediaQuery(
          // El tamaño de texto que trae el teléfono.
          data: MediaQueryData(textScaler: TextScaler.linear(systemScale)),
          child: const YoVoyGoApp(),
        ),
      ),
    );
    await settle(tester);
    return container;
  }

  /// Lo que ve una pantalla cualquiera, ya con los ajustes aplicados.
  MediaQueryData seenByScreens(WidgetTester tester) =>
      MediaQuery.of(tester.element(find.byType(MapScreen)));

  testWidgets('el tema sale de ajustes, no está clavado', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pumpApp(
      tester,
      settings: const AppSettings(themeMode: ThemeMode.light),
    );

    final MaterialApp app = tester.widget(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.light);
    expect(
      Theme.of(tester.element(find.byType(MapScreen))).brightness,
      Brightness.light,
    );

    await unmount(tester, container);
  });

  testWidgets('la escala de la app se multiplica por la del sistema', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pumpApp(
      tester,
      settings: const AppSettings(textScale: 1.15),
      systemScale: 1.2,
    );

    expect(
      seenByScreens(tester).textScaler.scale(100) / 100,
      closeTo(1.38, 0.001),
    );

    await unmount(tester, container);
  });

  testWidgets('la escala total se topa en el doble', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pumpApp(
      tester,
      settings: const AppSettings(textScale: 1.35),
      systemScale: 2,
    );

    expect(seenByScreens(tester).textScaler.scale(100) / 100, 2);

    await unmount(tester, container);
  });

  testWidgets('"reducir animaciones" apaga el movimiento de todo el árbol', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pumpApp(
      tester,
      settings: const AppSettings(reduceMotion: true),
    );

    expect(seenByScreens(tester).disableAnimations, isTrue);

    await unmount(tester, container);
  });

  testWidgets('sin ajustes guardados arranca oscura y sin escalar', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pumpApp(
      tester,
      settings: AppSettings.defaults,
    );

    final MaterialApp app = tester.widget(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(seenByScreens(tester).textScaler.scale(100) / 100, 1);
    expect(seenByScreens(tester).disableAnimations, isFalse);

    await unmount(tester, container);
  });
}
