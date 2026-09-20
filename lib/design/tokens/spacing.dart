import 'package:flutter/widgets.dart';

/// Escala de espaciado de 4, como en la sección 6.4 del spec. Nada intermedio.
abstract final class Spacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

/// Radios con jerarquía, no uno solo para todo.
///
/// Una placa de ruta no se redondea porque la señalética no redondea; una hoja
/// inferior sí, y mucho. El radio dice qué tipo de objeto es cada cosa.
abstract final class AppRadius {
  /// Placas de ruta.
  static const double plate = 0;

  /// Chips y botones.
  static const double chip = 8;

  /// Cards.
  static const double card = 16;

  /// Hoja inferior, solo esquinas superiores.
  static const double sheet = 28;

  static const BorderRadius chipRadius = BorderRadius.all(
    Radius.circular(chip),
  );
  static const BorderRadius cardRadius = BorderRadius.all(
    Radius.circular(card),
  );
  static const BorderRadius sheetRadius = BorderRadius.vertical(
    top: Radius.circular(sheet),
  );
}

/// Medidas que no se negocian.
abstract final class AppSizes {
  /// Área mínima de toque, como pide la sección 11 del spec.
  static const double minTouchTarget = 48;

  /// Grosor del contorno. No hay sombras: la jerarquía es superficie y borde.
  static const double outlineWidth = 1;
}
