import 'package:flutter/material.dart' show ThemeMode;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/settings_store.dart';

part 'settings_providers.g.dart';

@Riverpod(keepAlive: true)
SettingsStore settingsStore(Ref ref) => const SharedPreferencesSettingsStore();

/// Los ajustes del usuario, leídos una vez y recordados.
///
/// `keepAlive`: los lee la raíz de la app, que nunca se desmonta. Cada cambio
/// se ve al instante y el disco se entera después, como en el resto de la app.
@Riverpod(keepAlive: true)
class Settings extends _$Settings {
  @override
  Future<AppSettings> build() => ref.watch(settingsStoreProvider).load();

  Future<void> setThemeMode(ThemeMode mode) =>
      _update((AppSettings current) => current.copyWith(themeMode: mode));

  Future<void> setTextScale(double scale) =>
      _update((AppSettings current) => current.copyWith(textScale: scale));

  Future<void> setReduceMotion({required bool reduce}) =>
      _update((AppSettings c) => c.copyWith(reduceMotion: reduce));

  Future<void> _update(AppSettings Function(AppSettings current) change) async {
    final AppSettings next = change(await future);
    state = AsyncData<AppSettings>(next);
    await ref.read(settingsStoreProvider).save(next);
  }
}

/// Los ajustes ya resueltos, con los valores por defecto mientras el disco
/// responde: la app no parpadea al arrancar.
@Riverpod(keepAlive: true)
AppSettings appSettings(Ref ref) =>
    ref.watch(settingsProvider).value ?? AppSettings.defaults;
