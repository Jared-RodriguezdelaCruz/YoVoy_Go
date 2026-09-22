import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/models.dart';

part 'accessibility_filter.g.dart';

/// Dónde se recuerda si el usuario pidió ver solo paradas accesibles.
///
/// Para quien lo necesita es lo primero que filtra, no una preferencia de un
/// día: se guarda en el teléfono igual que los favoritos.
abstract interface class AccessibilityFilterStore {
  Future<bool> load();

  Future<void> save({required bool accessibleOnly});
}

final class SharedPreferencesAccessibilityFilterStore
    implements AccessibilityFilterStore {
  const SharedPreferencesAccessibilityFilterStore();

  static const String key = 'filters.accessibleOnly';

  @override
  Future<bool> load() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    return preferences.getBool(key) ?? false;
  }

  @override
  Future<void> save({required bool accessibleOnly}) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setBool(key, accessibleOnly);
  }
}

/// Para tests: se olvida con el proceso.
final class InMemoryAccessibilityFilterStore
    implements AccessibilityFilterStore {
  InMemoryAccessibilityFilterStore({this.value = false});

  bool value;

  @override
  Future<bool> load() async => value;

  @override
  Future<void> save({required bool accessibleOnly}) async =>
      value = accessibleOnly;
}

@Riverpod(keepAlive: true)
AccessibilityFilterStore accessibilityFilterStore(Ref ref) =>
    const SharedPreferencesAccessibilityFilterStore();

/// Si el mapa muestra solo las paradas accesibles.
@Riverpod(keepAlive: true)
class AccessibleOnly extends _$AccessibleOnly {
  @override
  Future<bool> build() => ref.watch(accessibilityFilterStoreProvider).load();

  Future<void> toggle() async {
    final bool next = !(await future);
    state = AsyncData<bool>(next);
    await ref.read(accessibilityFilterStoreProvider).save(accessibleOnly: next);
  }
}

/// Si [stop] pasa el filtro. Las paradas sin verificar **no** pasan: quien
/// necesita una rampa no puede apostar a que haya una.
bool passesAccessibilityFilter(Stop stop, {required bool accessibleOnly}) =>
    !accessibleOnly || stop.wheelchairBoarding == WheelchairBoarding.accessible;
