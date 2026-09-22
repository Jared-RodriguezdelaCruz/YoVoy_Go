import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/theme.dart';
import '../features/settings/application/settings_providers.dart';
import '../features/settings/data/settings_store.dart';
import 'router.dart';

/// Raíz de la app: router, locale, tema y lo que el usuario eligió en ajustes.
class YoVoyGoApp extends ConsumerWidget {
  const YoVoyGoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings settings = ref.watch(appSettingsProvider);

    return MaterialApp.router(
      title: 'Yo Voy Go',
      debugShowCheckedModeBanner: false,
      routerConfig: ref.watch(appRouterProvider),
      locale: const Locale('es', 'MX'),
      supportedLocales: const <Locale>[Locale('es', 'MX')],
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // El oscuro es el default de la app; el claro es obligatorio, como dice
      // la sección 6.2 del spec: el mapa de día se usa más.
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.themeMode,
      builder: (BuildContext context, Widget? child) =>
          _Preferences(settings: settings, child: child ?? const SizedBox()),
    );
  }
}

/// Aplica a todo el árbol lo que se eligió en ajustes.
///
/// Se hace aquí y no pantalla por pantalla: la escala de texto y la reducción
/// de movimiento son cosas del `MediaQuery`, y cada widget ya sabe obedecerlas
/// —`AppMotion.resolve` lee `disableAnimations`, y los layouts leen la escala
/// para decidir cuándo apilarse—.
class _Preferences extends StatelessWidget {
  const _Preferences({required this.settings, required this.child});

  final AppSettings settings;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    // La escala del sistema, medida sobre un tamaño cualquiera, por la de la
    // app. Se topa en 200 %: más allá no hay layout que aguante, y el spec
    // solo promete hasta ahí.
    final double system = media.textScaler.scale(100) / 100;
    final double scale = (system * settings.textScale).clamp(
      minTextScale,
      maxTextScale,
    );

    return MediaQuery(
      data: media.copyWith(
        textScaler: TextScaler.linear(scale),
        disableAnimations: media.disableAnimations || settings.reduceMotion,
      ),
      child: child,
    );
  }
}
