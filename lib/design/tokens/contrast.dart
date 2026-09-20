import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// Contraste, calculado y no supuesto.
///
/// La sección 11 del spec pide 4.5:1 en texto y 3:1 en gráficos. Aquí está la
/// única implementación de esa cuenta, para que las decisiones de color de la
/// app —qué texto va sobre una placa, cuándo una placa necesita contorno— se
/// tomen con el número en la mano.
abstract final class Contrast {
  /// Piso para texto.
  static const double minText = 4.5;

  /// Piso para elementos gráficos.
  static const double minGraphic = 3;

  /// Razón de contraste WCAG entre dos colores opacos. Va de 1 a 21.
  static double ratio(Color a, Color b) {
    final double la = a.computeLuminance() + 0.05;
    final double lb = b.computeLuminance() + 0.05;
    return math.max(la, lb) / math.min(la, lb);
  }

  /// De dos colores de texto, el que se lee mejor sobre [background].
  ///
  /// Elegir por un umbral fijo de luminancia falla justo en los tonos medios,
  /// que son la mitad de la paleta de rutas. Medir los dos y quedarse con el
  /// mejor no falla nunca.
  static Color bestOn(Color background, Color a, Color b) =>
      ratio(a, background) >= ratio(b, background) ? a : b;
}
