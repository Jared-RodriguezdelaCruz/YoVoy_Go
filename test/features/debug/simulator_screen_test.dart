import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yovoy_go/core/data/mock/mock_dataset.dart';
import 'package:yovoy_go/core/data/mock/simulator_config.dart';
import 'package:yovoy_go/core/data/transit_repository_provider.dart';
import 'package:yovoy_go/design/theme.dart';
import 'package:yovoy_go/features/debug/presentation/simulator_screen.dart';

/// El panel de `/debug/simulator`.
///
/// Existe para poder empujar la app a su peor caso a mano, así que lo que hay
/// que probar es justo eso: que los controles muevan la configuración de
/// verdad y que la pantalla aguante el dataset completo.
void main() {
  late MockDataset dataset;

  setUpAll(() {
    dataset = MockDataset.fromJsonStrings(<String, String>{
      for (final String name in MockAssets.files)
        name: File('${MockAssets.directory}/$name').readAsStringSync(),
    });
  });

  Future<ProviderContainer> pumpPanel(WidgetTester tester) async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        mockDatasetProvider.overrideWith((Ref ref) async => dataset),
        // Sin latencia ni errores: lo que se prueba es el panel, no la ruleta.
        simulatorSettingsProvider.overrideWith(
          () => _FixedSettings(SimulatorConfig.perfect),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.dark, home: const SimulatorScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();
    return container;
  }

  testWidgets('muestra la flota moviéndose sobre el dataset real', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpPanel(tester);

    expect(find.textContaining('reportando'), findsOneWidget);
    expect(find.textContaining('48 rutas'), findsOneWidget);
    // Las rutas que el dataset deja sin servicio a propósito se dicen por su
    // nombre: si desaparecen, la pantalla de "sin servicio" se queda sin caso.
    expect(find.textContaining('R_50B'), findsOneWidget);

    // Desmontar para que el stream de 30 s no quede vivo.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('el botón hostil empuja la app a su peor caso', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ProviderContainer container = await pumpPanel(tester);

    expect(container.read(simulatorSettingsProvider).errorRate, 0);

    await tester.tap(find.text('Hostil'));
    await tester.pump();

    expect(
      container.read(simulatorSettingsProvider).errorRate,
      SimulatorConfig.hostile.errorRate,
    );
    expect(find.text('20 %'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

/// El notifier con un estado inicial puesto a mano, para no depender del
/// default al abrir el panel.
class _FixedSettings extends SimulatorSettings {
  _FixedSettings(this.initial);

  final SimulatorConfig initial;

  @override
  SimulatorConfig build() => initial;
}
