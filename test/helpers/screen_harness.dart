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
import 'package:yovoy_go/core/device/screen_awake.dart';
import 'package:yovoy_go/core/history/history_providers.dart';
import 'package:yovoy_go/core/history/history_store.dart';
import 'package:yovoy_go/core/location/location_service.dart';
import 'package:yovoy_go/core/models/models.dart';
import 'package:yovoy_go/core/transit/live_providers.dart';
import 'package:yovoy_go/core/transit/reliability.dart';
import 'package:yovoy_go/design/theme.dart';
import 'package:yovoy_go/features/favorites/application/favorites_providers.dart';
import 'package:yovoy_go/features/favorites/data/favorites_store.dart';
import 'package:yovoy_go/features/favorites/presentation/favorites_screen.dart';
import 'package:yovoy_go/features/map/application/accessibility_filter.dart';
import 'package:yovoy_go/features/map/application/basemap_style.dart';
import 'package:yovoy_go/features/planner/application/trip_request.dart';
import 'package:yovoy_go/features/planner/presentation/itinerary_screen.dart';
import 'package:yovoy_go/features/planner/presentation/planner_screen.dart';
import 'package:yovoy_go/features/planner/presentation/ride_screen.dart';
import 'package:yovoy_go/features/route/presentation/route_screen.dart';
import 'package:yovoy_go/features/settings/application/settings_providers.dart';
import 'package:yovoy_go/features/settings/data/settings_store.dart';
import 'package:yovoy_go/features/settings/presentation/about_screen.dart';
import 'package:yovoy_go/features/settings/presentation/settings_screen.dart';
import 'package:yovoy_go/features/stop/presentation/stop_board_screen.dart';
import 'package:yovoy_go/features/stop/presentation/stop_screen.dart';

/// Lunes 21 de septiembre de 2026, 8:00: hora pico, con la flota en la calle.
final DateTime eightAm = DateTime(2026, 9, 21, 8);

/// El dataset real, leído del disco.
MockDataset loadTestDataset() => MockDataset.fromJsonStrings(<String, String>{
  for (final String name in MockAssets.files)
    name: File('${MockAssets.directory}/$name').readAsStringSync(),
});

class FixedLocation implements LocationService {
  const FixedLocation([
    this.location = const UserLocation(position: aguascalientesCenter),
  ]);

  final UserLocation location;

  @override
  Future<UserLocation> current() async => location;

  @override
  Future<void> openSettings(LocationIssue issue) async {}
}

class FixedSettings extends SimulatorSettings {
  FixedSettings(this.initial);

  final SimulatorConfig initial;

  @override
  SimulatorConfig build() => initial;
}

/// Un contenedor con el dataset real, el reloj fijo, sin red, sin tocar el
/// disco ni la pantalla del teléfono.
ProviderContainer makeContainer(
  MockDataset dataset, {
  SimulatorConfig config = SimulatorConfig.perfect,
  DateTime? now,
  FavoritesStore? favorites,
  AccessibilityFilterStore? accessibility,
  ReliabilityHistory? reliability,
  HistoryStore? history,
  SettingsStore? settings,
  ScreenAwake? screenAwake,
  UserLocation? location,
  List<VehiclePosition>? vehicles,
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
      locationServiceProvider.overrideWithValue(
        location == null ? const FixedLocation() : FixedLocation(location),
      ),
      favoritesStoreProvider.overrideWithValue(
        favorites ?? InMemoryFavoritesStore(),
      ),
      accessibilityFilterStoreProvider.overrideWithValue(
        accessibility ?? InMemoryAccessibilityFilterStore(),
      ),
      if (reliability != null)
        reliabilityHistoryProvider.overrideWithValue(reliability),
      historyStoreProvider.overrideWithValue(history ?? InMemoryHistoryStore()),
      settingsStoreProvider.overrideWithValue(
        settings ?? InMemorySettingsStore(),
      ),
      screenAwakeProvider.overrideWithValue(screenAwake ?? FakeScreenAwake()),
      // Una flota a la medida, para poner un camión justo donde el test lo
      // necesita.
      if (vehicles != null)
        vehicleFeedProvider.overrideWith(
          (Ref ref) => Stream<List<VehiclePosition>>.value(vehicles),
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
        path: AppRoute.stopBoard.path,
        name: AppRoute.stopBoard.name,
        builder: (BuildContext context, GoRouterState state) =>
            StopBoardScreen(stopId: state.pathParameters[AppParams.stopId]!),
      ),
      GoRoute(
        path: AppRoute.route.path,
        name: AppRoute.route.name,
        builder: (BuildContext context, GoRouterState state) => RouteScreen(
          routeId: state.pathParameters[AppParams.routeId]!,
          fromStopId: state.uri.queryParameters[AppParams.fromStop],
        ),
      ),
      GoRoute(
        path: AppRoute.planner.path,
        name: AppRoute.planner.name,
        builder: (BuildContext context, GoRouterState state) => PlannerScreen(
          request: TripRequest.fromQuery(state.uri.queryParameters),
        ),
      ),
      GoRoute(
        path: AppRoute.plannerOption.path,
        name: AppRoute.plannerOption.name,
        builder: (BuildContext context, GoRouterState state) => ItineraryScreen(
          request: TripRequest.fromQuery(state.uri.queryParameters),
          index: int.parse(state.pathParameters[AppParams.option]!),
        ),
      ),
      GoRoute(
        path: AppRoute.ride.path,
        name: AppRoute.ride.name,
        builder: (BuildContext context, GoRouterState state) => RideScreen(
          request: TripRequest.fromQuery(state.uri.queryParameters),
          index: int.parse(state.pathParameters[AppParams.option]!),
        ),
      ),
      GoRoute(
        path: AppRoute.favorites.path,
        name: AppRoute.favorites.name,
        builder: (BuildContext context, GoRouterState state) =>
            const FavoritesScreen(),
      ),
      GoRoute(
        path: AppRoute.settings.path,
        name: AppRoute.settings.name,
        builder: (BuildContext context, GoRouterState state) =>
            const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoute.about.path,
        name: AppRoute.about.name,
        builder: (BuildContext context, GoRouterState state) =>
            const AboutScreen(),
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
