import 'package:shared_preferences/shared_preferences.dart';

/// Dónde viven las paradas y las rutas favoritas.
///
/// Una lista de ids no necesita una base de datos: `shared_preferences`
/// basta y es el paquete oficial de Flutter. La interfaz existe para que los
/// tests no toquen el disco y para que la fase 8 pueda cambiar de idea sin
/// tocar las pantallas.
abstract interface class FavoritesStore {
  Future<Set<String>> loadStops();

  Future<void> saveStops(Set<String> stopIds);

  Future<Set<String>> loadRoutes();

  Future<void> saveRoutes(Set<String> routeIds);
}

/// La implementación real, en el almacenamiento del teléfono.
final class SharedPreferencesFavoritesStore implements FavoritesStore {
  const SharedPreferencesFavoritesStore();

  /// Las claves con las que se guardan. Cambiarlas borra los favoritos de
  /// todos.
  static const String stopsKey = 'favorites.stops';
  static const String routesKey = 'favorites.routes';

  @override
  Future<Set<String>> loadStops() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    return preferences.getStringList(stopsKey)?.toSet() ?? <String>{};
  }

  @override
  Future<void> saveStops(Set<String> stopIds) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(stopsKey, stopIds.toList()..sort());
  }

  @override
  Future<Set<String>> loadRoutes() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    return preferences.getStringList(routesKey)?.toSet() ?? <String>{};
  }

  @override
  Future<void> saveRoutes(Set<String> routeIds) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(routesKey, routeIds.toList()..sort());
  }
}

/// Para tests: se olvida con el proceso.
final class InMemoryFavoritesStore implements FavoritesStore {
  InMemoryFavoritesStore([Set<String>? initial, Set<String>? routes])
    : _stops = <String>{...?initial},
      _routes = <String>{...?routes};

  final Set<String> _stops;
  final Set<String> _routes;

  /// Cuántas veces se guardó: los tests verifican que tocar guarde.
  int saves = 0;

  @override
  Future<Set<String>> loadStops() async => <String>{..._stops};

  @override
  Future<void> saveStops(Set<String> stopIds) async {
    saves++;
    _stops
      ..clear()
      ..addAll(stopIds);
  }

  @override
  Future<Set<String>> loadRoutes() async => <String>{..._routes};

  @override
  Future<void> saveRoutes(Set<String> routeIds) async {
    saves++;
    _routes
      ..clear()
      ..addAll(routeIds);
  }
}
