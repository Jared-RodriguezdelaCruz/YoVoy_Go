import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yovoy_go/app/routes.dart';
import 'package:yovoy_go/core/data/mock/mock_dataset.dart';
import 'package:yovoy_go/core/history/history_providers.dart';
import 'package:yovoy_go/core/history/history_store.dart';
import 'package:yovoy_go/core/history/observation.dart';
import 'package:yovoy_go/features/settings/application/settings_providers.dart';
import 'package:yovoy_go/features/settings/data/settings_store.dart';

import '../../helpers/screen_harness.dart';

void main() {
  late MockDataset dataset;

  setUpAll(() => dataset = loadTestDataset());

  group('lo que se guarda', () {
    test('cada cambio se escribe y se recuerda', () async {
      final InMemorySettingsStore store = InMemorySettingsStore();
      final ProviderContainer container = ProviderContainer(
        overrides: [settingsStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);

      final Settings settings = container.read(settingsProvider.notifier);
      await settings.setThemeMode(ThemeMode.light);
      await settings.setTextScale(1.35);
      await settings.setReduceMotion(reduce: true);

      expect(store.settings.themeMode, ThemeMode.light);
      expect(store.settings.textScale, 1.35);
      expect(store.settings.reduceMotion, isTrue);
      expect(store.saves, 3);

      // Un arranque nuevo lee lo mismo.
      final ProviderContainer again = ProviderContainer(
        overrides: [settingsStoreProvider.overrideWithValue(store)],
      );
      addTearDown(again.dispose);
      expect(
        (await again.read(settingsProvider.future)).themeMode,
        ThemeMode.light,
      );
    });

    test(
      'sin nada guardado, la app arranca oscura y en tamaño normal',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final AppSettings settings =
            await const SharedPreferencesSettingsStore().load();

        expect(settings.themeMode, ThemeMode.dark);
        expect(settings.textScale, 1);
        expect(settings.reduceMotion, isFalse);
      },
    );

    test('un tema guardado que ya no existe no rompe el arranque', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        SharedPreferencesSettingsStore.themeKey: 'sepia',
      });
      expect(
        (await const SharedPreferencesSettingsStore().load()).themeMode,
        ThemeMode.dark,
      );
    });
  });

  group('la pantalla', () {
    testWidgets('el tema, el tamaño y las animaciones se eligen y se guardan', (
      WidgetTester tester,
    ) async {
      final InMemorySettingsStore store = InMemorySettingsStore();
      final ProviderContainer container = makeContainer(
        dataset,
        settings: store,
      );
      await pumpAt(tester, container, AppPaths.settings);

      await tester.tap(find.text('Claro'));
      await settle(tester);
      expect(container.read(appSettingsProvider).themeMode, ThemeMode.light);

      await tester.tap(find.text('Grande'));
      await settle(tester);
      expect(container.read(appSettingsProvider).textScale, 1.15);

      await tester.tap(find.text('Reducir animaciones'));
      await settle(tester);
      expect(container.read(appSettingsProvider).reduceMotion, isTrue);

      expect(store.settings.themeMode, ThemeMode.light);

      await unmount(tester, container);
    });

    testWidgets('borrar el historial pregunta antes y luego olvida', (
      WidgetTester tester,
    ) async {
      final InMemoryHistoryStore history = InMemoryHistoryStore(
        uses: <UseEvent>[
          UseEvent(stopId: 'P606', kind: UseKind.board, at: eightAm),
        ],
        arrivals: <ArrivalObservation>[
          ArrivalObservation(
            routeId: 'R09',
            stopId: 'P606',
            band: TimeBand.of(eightAm),
            delay: const Duration(minutes: 2),
            at: eightAm,
          ),
        ],
      );
      final ProviderContainer container = makeContainer(
        dataset,
        history: history,
      );
      await pumpAt(tester, container, AppPaths.settings);

      expect(find.textContaining('1 observaciones'), findsOneWidget);

      await tester.tap(find.text('Borrar el historial'));
      await settle(tester);
      expect(find.text('¿Borrar lo que la app aprendió?'), findsOneWidget);

      // Cancelar no borra nada.
      await tester.tap(find.text('Cancelar'));
      await settle(tester);
      expect(await history.loadUses(), hasLength(1));

      await tester.tap(find.text('Borrar el historial'));
      await settle(tester);
      await tester.tap(find.text('Borrar'));
      await settle(tester);

      expect(await history.loadUses(), isEmpty);
      expect(await history.loadArrivals(), isEmpty);
      expect(container.read(arrivalHistoryProvider).value, isEmpty);

      await unmount(tester, container);
    });

    testWidgets('el aviso de app independiente está en "Acerca de"', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = makeContainer(dataset);
      await pumpAt(tester, container, AppPaths.about);

      expect(find.text('Es una app independiente'), findsOneWidget);
      expect(
        find.textContaining('no tiene relación con la Coordinación'),
        findsOneWidget,
      );
      expect(find.textContaining('CC BY-SA 4.0'), findsOneWidget);

      // Lo de la privacidad va hasta abajo: la lista es perezosa.
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await settle(tester);
      expect(find.textContaining('no se mandan a ningún lado'), findsOneWidget);

      await unmount(tester, container);
    });

    testWidgets('con texto al 200 % nada se desborda', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = makeContainer(dataset);
      await pumpAt(tester, container, AppPaths.settings, textScale: 2);

      expect(tester.takeException(), isNull);

      await unmount(tester, container);
    });
  });
}
