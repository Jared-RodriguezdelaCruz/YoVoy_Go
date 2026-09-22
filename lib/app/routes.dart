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

  /// Modo paradero: una parada, un número enorme y la tira de la ruta. Es la
  /// feature 3 de `FEATURES.md`.
  static const AppRoute stopBoard = AppRoute._(
    'stopBoard',
    '/stop/:${AppParams.stopId}/board',
  );

  /// Detalle de ruta, como en la sección 8.3 del spec.
  static const AppRoute route = AppRoute._(
    'route',
    '/route/:${AppParams.routeId}',
  );

  /// Planificador, como en la sección 8.4 del spec. La petición va en la
  /// query: `?from=here&to=P606&at=8:30`.
  static const AppRoute planner = AppRoute._('planner', '/planner');

  /// Detalle de un itinerario: la línea de tiempo y el mapa. Lleva la misma
  /// query que el planificador, para poder rearmarse solo.
  static const AppRoute plannerOption = AppRoute._(
    'plannerOption',
    '/planner/option/:${AppParams.option}',
  );

  /// Modo viaje: vas a bordo y la app te dice cuándo bajarte. Es la feature 5
  /// de `FEATURES.md`.
  static const AppRoute ride = AppRoute._(
    'ride',
    '/planner/option/:${AppParams.option}/ride',
  );

  /// Favoritos, como en la sección 8.5 del spec.
  static const AppRoute favorites = AppRoute._('favorites', '/favorites');

  /// Ajustes, como en la sección 8.6 del spec.
  static const AppRoute settings = AppRoute._('settings', '/settings');

  /// "Acerca de": el aviso de app independiente de la sección 10 y la
  /// atribución de los datos.
  static const AppRoute about = AppRoute._('about', '/settings/about');

  /// Galería del design system. Solo se monta en builds de debug.
  static const AppRoute gallery = AppRoute._('gallery', '/debug/gallery');

  /// Panel de control del simulador. Solo en builds de debug.
  static const AppRoute simulator = AppRoute._('simulator', '/debug/simulator');
}

/// Nombres de los parámetros de path.
abstract final class AppParams {
  static const String stopId = 'stopId';
  static const String routeId = 'routeId';

  /// El índice de una opción del planificador, en su orden.
  static const String option = 'option';

  /// Query de la ruta: la parada desde la que se llegó. Con ella la ruta
  /// puede decir qué tan puntual ha sido **en esa parada**.
  static const String fromStop = 'from';
}

/// Paths concretos, ya resueltos.
abstract final class AppPaths {
  static String stop(String stopId) => '/stop/$stopId';
  static String stopBoard(String stopId) => '/stop/$stopId/board';
  static String route(String routeId) => '/route/$routeId';
  static String plannerOption(int index) => '/planner/option/$index';
  static String ride(int index) => '/planner/option/$index/ride';
  static const String favorites = '/favorites';
  static const String settings = '/settings';
  static const String about = '/settings/about';
}
