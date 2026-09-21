import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yovoy_go/core/clock/clock_provider.dart';
import 'package:yovoy_go/core/data/mock/mock_dataset.dart';
import 'package:yovoy_go/core/data/mock/simulator_config.dart';
import 'package:yovoy_go/core/data/transit_repository_provider.dart';
import 'package:yovoy_go/core/location/location_service.dart';
import 'package:yovoy_go/design/theme.dart';
import 'package:yovoy_go/features/map/application/basemap_style.dart';
import 'package:yovoy_go/features/map/presentation/layers/transit_markers_layer.dart';
import 'package:yovoy_go/features/map/presentation/map_hit_test.dart';
import 'package:yovoy_go/features/map/presentation/map_screen.dart';

import '../../helpers/golden_fonts.dart';

class _FixedLocation implements LocationService {
  const _FixedLocation();

  @override
  Future<UserLocation> current() async =>
      const UserLocation(position: aguascalientesCenter);

  @override
  Future<void> openSettings(LocationIssue issue) async {}
}

/// Fotos del mapa, para **verlo** sin emulador.
///
/// El reloj va fijo —lunes 21 de septiembre de 2026, 8:00, hora pico— para
/// que la flota salga en el mismo lugar cada vez. El fondo vectorial no se
/// dibuja: necesita red. Lo que se ve es lo que la app pinta encima, sobre la
/// superficie lisa, que es también lo que ve alguien sin datos ni caché.
///
/// Se regeneran con `flutter test --update-goldens`.
void main() {
  late MockDataset dataset;
  final DateTime eightAm = DateTime(2026, 9, 21, 8);

  setUpAll(() async {
    await loadAppFonts();
    dataset = MockDataset.fromJsonStrings(<String, String>{
      for (final String name in MockAssets.files)
        name: File('${MockAssets.directory}/$name').readAsStringSync(),
    });
  });

  Future<ProviderContainer> pumpMap(
    WidgetTester tester, {
    required ThemeData theme,
  }) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ProviderContainer container = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(() => eightAm),
        mockDatasetProvider.overrideWith((Ref ref) async => dataset),
        simulatorSettingsProvider.overrideWith(
          () => _FixedSettings(SimulatorConfig.perfect),
        ),
        basemapStyleProvider.overrideWith(
          (Ref ref, Brightness brightness) async => null,
        ),
        locationServiceProvider.overrideWithValue(const _FixedLocation()),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: const MapScreen(),
        ),
      ),
    );
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return container;
  }

  Future<void> unmount(WidgetTester tester, ProviderContainer container) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump();
  }

  testWidgets('inicio, tema oscuro', (WidgetTester tester) async {
    final ProviderContainer container = await pumpMap(
      tester,
      theme: AppTheme.dark,
    );
    await expectLater(
      find.byType(MapScreen),
      matchesGoldenFile('goldens/map_home_dark.png'),
    );
    await unmount(tester, container);
  });

  testWidgets('inicio, tema claro', (WidgetTester tester) async {
    final ProviderContainer container = await pumpMap(
      tester,
      theme: AppTheme.light,
    );
    await expectLater(
      find.byType(MapScreen),
      matchesGoldenFile('goldens/map_home_light.png'),
    );
    await unmount(tester, container);
  });

  testWidgets('un camión elegido: su ruta se enciende y sale la tira', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pumpMap(
      tester,
      theme: AppTheme.dark,
    );

    final MapHitRegistry hits = tester
        .widget<TransitMarkersLayer>(find.byType(TransitMarkersLayer))
        .hits;
    final Rect map = tester.getRect(find.byType(TransitMarkersLayer));
    // El camión suelto más cercano al centro de la parte visible del mapa.
    final Offset target = Offset(map.width / 2, map.height * 0.3);
    final List<VehicleHit> buses = hits.all.whereType<VehicleHit>().toList()
      ..sort(
        (VehicleHit a, VehicleHit b) =>
            (a.point - target).distance.compareTo((b.point - target).distance),
      );

    await tester.tapAt(map.topLeft + buses.first.point);
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    await expectLater(
      find.byType(MapScreen),
      matchesGoldenFile('goldens/map_vehicle_dark.png'),
    );
    await unmount(tester, container);
  });
}

class _FixedSettings extends SimulatorSettings {
  _FixedSettings(this.initial);

  final SimulatorConfig initial;

  @override
  SimulatorConfig build() => initial;
}
