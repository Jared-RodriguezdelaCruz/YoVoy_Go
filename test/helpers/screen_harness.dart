import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:yovoy_go/app/routes.dart';
import 'package:yovoy_go/core/clock/clock_provider.dart';
import 'package:yovoy_go/core/data/mock/mock_dataset.dart';
import 'package:yovoy_go/core/data/mock/simulator_config.dart';
import 'package:yovoy_go/core/data/transit_repository_provider.dart';
import 'package:yovoy_go/core/location/location_service.dart';
import 'package:yovoy_go/design/theme.dart';
import 'package:yovoy_go/features/favorites/application/favorites_providers.dart';
import 'package:yovoy_go/features/favorites/data/favorites_store.dart';
import 'package:yovoy_go/features/map/application/basemap_style.dart';
import 'package:yovoy_go/features/route/presentation/route_screen.dart';
import 'package:yovoy_go/features/stop/presentation/stop_screen.dart';

/// Lunes 21 de septiembre de 2026, 8:00: hora pico, con la flota en la calle.
final DateTime eightAm = DateTime(2026, 9, 21, 8);

/// El dataset real, leído del disco.
MockDataset loadTestDataset() => MockDataset.fromJsonStrings(<String, String>{
  for (final String name in MockAssets.files)
    name: File('${MockAssets.directory}/$name').readAsStringSync(),
});

class FixedLocation implements LocationService {
  const FixedLocation();

  @override
  Future<UserLocation> current() async =>
      const UserLocation(position: aguascalientesCenter);

  @override
  Future<void> openSettings(LocationIssue issue) async {}
}

class FixedSettings extends SimulatorSettings {
  FixedSettings(this.initial);

  final SimulatorConfig initial;

  @override
  SimulatorConfig build() => initial;
}

/// Un contenedor con el dataset real, el reloj fijo, sin red y con los
/// favoritos en memoria.
ProviderContainer makeContainer(
  MockDataset dataset, {
  SimulatorConfig config = SimulatorConfig.perfect,
  DateTime? now,
  FavoritesStore? favorites,
}) {
  final DateTime moment = now ?? eightAm;
  return ProviderContainer(
    overrides: [
      clockProvider.overrideWithValue(() => moment),
      mockDatasetProvider.overrideWith((Ref ref) async => dataset),
      simulatorSettingsProvider.overrideWith(() => FixedSettings(config)),
      basemapStyleProvider.overrideWith(
        (Ref ref, Brightness brightness) async => null,
      ),
      locationServiceProvider.overrideWithValue(const FixedLocation()),
      favoritesStoreProvider.overrideWithValue(
        favorites ?? InMemoryFavoritesStore(),
      ),
    ],
  );
}

/// Monta la app desde [location], con las pantallas de parada y ruta de
/// verdad y un mapa de cartón: estos tests no son del mapa.
Future<void> pumpAt(
  WidgetTester tester,
  ProviderContainer container,
  String location, {
  ThemeData? theme,
  double textScale = 1,
  Size size = const Size(412, 915),
  int frames = 10,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final GoRouter router = GoRouter(
    initialLocation: location,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoute.map.path,
        name: AppRoute.map.name,
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Text('mapa')),
      ),
      GoRoute(
        path: AppRoute.stop.path,
        name: AppRoute.stop.name,
        builder: (BuildContext context, GoRouterState state) =>
            StopScreen(stopId: state.pathParameters[AppParams.stopId]!),
      ),
      GoRoute(
        path: AppRoute.route.path,
        name: AppRoute.route.name,
        builder: (BuildContext context, GoRouterState state) =>
            RouteScreen(routeId: state.pathParameters[AppParams.routeId]!),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: theme ?? AppTheme.dark,
        routerConfig: router,
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await settle(tester, frames: frames);
}

/// Avanza cuadros fijos: con streams de 30 s abiertos, `pumpAndSettle` no
/// termina nunca.
Future<void> settle(WidgetTester tester, {int frames = 10}) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Suelta los streams y relojes **dentro** del test: el framework revisa que
/// no queden timers vivos antes de correr los `tearDown`.
Future<void> unmount(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(const SizedBox.shrink());
  container.dispose();
  await tester.pump();
}
