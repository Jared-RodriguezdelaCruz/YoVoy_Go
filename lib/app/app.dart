import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      // TODO(fase 3): reemplazar por los temas de design/theme.dart, como en la
      // sección 6 del spec (design system).
      // El oscuro es el default de la app; el claro es obligatorio.
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.dark,
    );
  }
}
