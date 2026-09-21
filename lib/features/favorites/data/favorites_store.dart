import 'package:shared_preferences/shared_preferences.dart';

/// Dónde viven las paradas favoritas.
///
/// Una lista de ids no necesita una base de datos: `shared_preferences`
/// basta y es el paquete oficial de Flutter. La interfaz existe para que los
/// tests no toquen el disco y para que la fase 8 pueda cambiar de idea sin
/// tocar las pantallas.
abstract interface class FavoritesStore {
  Future<Set<String>> loadStops();

  Future<void> saveStops(Set<String> stopIds);
}

/// La implementación real, en el almacenamiento del teléfono.
final class SharedPreferencesFavoritesStore implements FavoritesStore {
  const SharedPreferencesFavoritesStore();

  /// La clave con la que se guardan. Cambiarla borra los favoritos de todos.
  static const String stopsKey = 'favorites.stops';

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
}

/// Para tests: se olvida con el proceso.
final class InMemoryFavoritesStore implements FavoritesStore {
  InMemoryFavoritesStore([Set<String>? initial])
    : _stops = <String>{...?initial};

  final Set<String> _stops;

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
}
