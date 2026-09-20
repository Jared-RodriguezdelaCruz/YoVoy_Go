/// Rutas de la app, derivadas de la sección 8 del spec (pantallas).
///
/// Ningún widget arma un path con strings sueltos: se navega por nombre con
/// [AppRoute.name] o con los helpers de [AppPaths].
library;

/// Una ruta declarada en el router: su nombre y su patrón de path.
final class AppRoute {
  const AppRoute._(this.name, this.path);

  /// Nombre estable para `goNamed` / `pushNamed`.
  final String name;

  /// Patrón que registra `go_router` (puede incluir parámetros).
  final String path;

  /// Mapa (inicio), como en la sección 8.1 del spec.
  static const AppRoute map = AppRoute._('map', '/');

  /// Detalle de parada, como en la sección 8.2 del spec.
  static const AppRoute stop = AppRoute._('stop', '/stop/:${AppParams.stopId}');

  /// Detalle de ruta, como en la sección 8.3 del spec.
  static const AppRoute route = AppRoute._(
    'route',
    '/route/:${AppParams.routeId}',
  );

  /// Planificador, como en la sección 8.4 del spec.
  static const AppRoute planner = AppRoute._('planner', '/planner');

  /// Favoritos, como en la sección 8.5 del spec.
  static const AppRoute favorites = AppRoute._('favorites', '/favorites');

  /// Ajustes, como en la sección 8.6 del spec.
  static const AppRoute settings = AppRoute._('settings', '/settings');

  /// Galería del design system. Solo se monta en builds de debug.
  static const AppRoute gallery = AppRoute._('gallery', '/debug/gallery');

  /// Panel de control del simulador. Solo en builds de debug.
  static const AppRoute simulator = AppRoute._(
    'simulator',
    '/debug/simulator',
  );
}

/// Nombres de los parámetros de path.
abstract final class AppParams {
  static const String stopId = 'stopId';
  static const String routeId = 'routeId';
}

/// Paths concretos, ya resueltos.
abstract final class AppPaths {
  static String stop(String stopId) => '/stop/$stopId';
  static String route(String routeId) => '/route/$routeId';
}
