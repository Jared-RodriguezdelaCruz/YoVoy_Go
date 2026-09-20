import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/theme.dart';
import 'router.dart';

/// Raíz de la app: router, locale y tema.
class YoVoyGoApp extends ConsumerWidget {
  const YoVoyGoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      // TODO(fase 8): que el modo salga de ajustes en vez de estar fijo.
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
    );
  }
}
