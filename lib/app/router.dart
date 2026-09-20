import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../design/gallery/design_gallery_screen.dart';
import '../features/debug/presentation/simulator_screen.dart';
import '../features/favorites/presentation/favorites_screen.dart';
import '../features/map/presentation/map_screen.dart';
import '../features/planner/presentation/planner_screen.dart';
import '../features/route/presentation/route_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/stop/presentation/stop_screen.dart';
import 'routes.dart';

part 'router.g.dart';

/// Router de la app.
///
/// `keepAlive` porque el router vive tanto como la app: como dice la sección 5
/// del spec, `autoDispose` no se desactiva en providers con polling o stream,
/// y este no es ninguno de los dos.
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: AppRoute.map.path,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoute.map.path,
        name: AppRoute.map.name,
        builder: (BuildContext context, GoRouterState state) =>
            const MapScreen(),
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
      GoRoute(
        path: AppRoute.planner.path,
        name: AppRoute.planner.name,
        builder: (BuildContext context, GoRouterState state) =>
            const PlannerScreen(),
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
      // Rutas de debug: existen solo mientras se construye la app.
      if (kDebugMode)
        GoRoute(
          path: AppRoute.gallery.path,
          name: AppRoute.gallery.name,
          builder: (BuildContext context, GoRouterState state) =>
              const DesignGalleryScreen(),
        ),
      if (kDebugMode)
        GoRoute(
          path: AppRoute.simulator.path,
          name: AppRoute.simulator.name,
          builder: (BuildContext context, GoRouterState state) =>
              const SimulatorScreen(),
        ),
    ],
    // Como en la sección 9 del spec (estados obligatorios): ningún estado se
    // resuelve con la pantalla roja por defecto.
    errorBuilder: (BuildContext context, GoRouterState state) =>
        _RouteNotFoundScreen(location: state.uri.toString()),
  );
}

class _RouteNotFoundScreen extends StatelessWidget {
  const _RouteNotFoundScreen({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Esta pantalla no existe',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(location, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.goNamed(AppRoute.map.name),
                child: const Text('Ir al mapa'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
