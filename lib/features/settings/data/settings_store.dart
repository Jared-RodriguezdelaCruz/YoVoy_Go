import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

/// Lo que el usuario eligió en ajustes, como lo pide la sección 8.6 del spec.
@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.dark,
    this.textScale = 1,
    this.reduceMotion = false,
  });

  /// Lo que ve quien nunca abre ajustes: el oscuro es el default de la app.
  static const AppSettings defaults = AppSettings();

  final ThemeMode themeMode;

  /// La escala **propia de la app**, que se multiplica por la del sistema.
  /// Sirve a quien no quiere agrandar todo el teléfono.
  final double textScale;

  final bool reduceMotion;

  AppSettings copyWith({
    ThemeMode? themeMode,
    double? textScale,
    bool? reduceMotion,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    textScale: textScale ?? this.textScale,
    reduceMotion: reduceMotion ?? this.reduceMotion,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.themeMode == themeMode &&
      other.textScale == textScale &&
      other.reduceMotion == reduceMotion;

  @override
  int get hashCode => Object.hash(themeMode, textScale, reduceMotion);
}

/// Las escalas que ofrece ajustes, con su nombre.
///
/// Cuatro pasos y no un deslizador: un deslizador invita a buscar el número
/// perfecto, y aquí lo único que importa es "más grande".
const List<(double scale, String label)> textScaleChoices = <(double, String)>[
  (0.9, 'Chico'),
  (1, 'Normal'),
  (1.15, 'Grande'),
  (1.35, 'Enorme'),
];

/// El techo de la escala total, sistema incluido.
///
/// La sección 11 del spec exige aguantar el 200 % del sistema sin romper
/// layouts; más allá de eso no hay promesa que cumplir, así que se topa.
const double maxTextScale = 2;

/// El piso, por si el sistema viene en muy chico y la app se vuelve ilegible.
const double minTextScale = 0.85;

/// Dónde se recuerdan los ajustes.
abstract interface class SettingsStore {
  Future<AppSettings> load();

  Future<void> save(AppSettings settings);
}

final class SharedPreferencesSettingsStore implements SettingsStore {
  const SharedPreferencesSettingsStore();

  static const String themeKey = 'settings.themeMode';
  static const String textScaleKey = 'settings.textScale';
  static const String reduceMotionKey = 'settings.reduceMotion';

  @override
  Future<AppSettings> load() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    return AppSettings(
      themeMode: _modeFrom(preferences.getString(themeKey)),
      textScale: preferences.getDouble(textScaleKey) ?? 1,
      reduceMotion: preferences.getBool(reduceMotionKey) ?? false,
    );
  }

  @override
  Future<void> save(AppSettings settings) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString(themeKey, settings.themeMode.name);
    await preferences.setDouble(textScaleKey, settings.textScale);
    await preferences.setBool(reduceMotionKey, settings.reduceMotion);
  }

  static ThemeMode _modeFrom(String? name) =>
      ThemeMode.values
          .where((ThemeMode mode) => mode.name == name)
          .firstOrNull ??
      AppSettings.defaults.themeMode;
}

/// Para tests: se olvida con el proceso.
final class InMemorySettingsStore implements SettingsStore {
  InMemorySettingsStore([this.settings = AppSettings.defaults]);

  AppSettings settings;

  /// Cuántas veces se guardó.
  int saves = 0;

  @override
  Future<AppSettings> load() async => settings;

  @override
  Future<void> save(AppSettings next) async {
    saves++;
    settings = next;
  }
}
