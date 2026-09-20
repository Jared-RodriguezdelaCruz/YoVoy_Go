import 'package:flutter/material.dart';

/// Los seis roles tipográficos de la sección 6.3 del spec.
///
/// Una sola familia en dos anchos, ya empaquetada en `assets/fonts/`:
/// `BarlowSemiCondensed` para números, códigos de ruta y datos densos;
/// `Barlow` para texto corrido.
///
/// Los números llevan [FontFeature.tabularFigures]: un contador que cambia de
/// ancho al pasar de 9 a 10 se ve barato y salta.
abstract final class AppTypography {
  /// Texto corrido, etiquetas y botones.
  static const String family = 'Barlow';

  /// Números, códigos de ruta, ETAs.
  static const String condensedFamily = 'BarlowSemiCondensed';

  static const List<FontFeature> _tabular = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  /// El número grande de minutos. Su lugar natural es el modo paradero.
  static const TextStyle etaDisplay = TextStyle(
    fontFamily: condensedFamily,
    fontSize: 48,
    fontWeight: FontWeight.w700,
    height: 1,
    fontFeatures: _tabular,
  );

  /// Código de ruta dentro de su placa.
  static const TextStyle routeBadge = TextStyle(
    fontFamily: condensedFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.1,
    fontFeatures: _tabular,
  );

  /// Nombre de parada, encabezado de hoja.
  static const TextStyle title = TextStyle(
    fontFamily: family,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  /// Texto general.
  static const TextStyle body = TextStyle(
    fontFamily: family,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.35,
  );

  /// Etiquetas de control.
  static const TextStyle label = TextStyle(
    fontFamily: family,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  /// Metadatos, frescura del dato.
  static const TextStyle caption = TextStyle(
    fontFamily: family,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.3,
  );

  /// Los minutos dentro de un chip: mismo ancho condensado, tamaño de lista.
  static const TextStyle eta = TextStyle(
    fontFamily: condensedFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.1,
    fontFeatures: _tabular,
  );

  /// Los seis roles mapeados sobre el `TextTheme` de Material, para que los
  /// widgets de fábrica hereden la tipografía sin configurarlos uno por uno.
  static TextTheme textTheme({
    required Color primary,
    required Color secondary,
  }) {
    return TextTheme(
      displayLarge: etaDisplay.copyWith(color: primary),
      displayMedium: etaDisplay.copyWith(color: primary),
      displaySmall: etaDisplay.copyWith(color: primary),
      headlineLarge: title.copyWith(fontSize: 28, color: primary),
      headlineMedium: title.copyWith(fontSize: 26, color: primary),
      headlineSmall: title.copyWith(fontSize: 24, color: primary),
      titleLarge: title.copyWith(color: primary),
      titleMedium: title.copyWith(fontSize: 18, color: primary),
      titleSmall: label.copyWith(color: primary),
      bodyLarge: body.copyWith(color: primary),
      bodyMedium: body.copyWith(fontSize: 15, color: primary),
      bodySmall: caption.copyWith(color: secondary),
      labelLarge: label.copyWith(color: primary),
      labelMedium: label.copyWith(color: secondary),
      labelSmall: caption.copyWith(color: secondary),
    );
  }
}
