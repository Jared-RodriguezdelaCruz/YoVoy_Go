import 'package:flutter/material.dart';

import 'colors.dart';

/// El contraste al máximo: fondo y texto puros, en el sentido del tema del
/// sistema. De noche no se deslumbra a nadie con blanco.
///
/// Es la paleta de las pantallas que se leen con el sol de frente y el
/// teléfono en una mano: el modo paradero y el modo viaje.
AppColors maxContrastColors(AppColors base, Brightness brightness) {
  final bool dark = brightness == Brightness.dark;
  final Color ground = dark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
  final Color ink = dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
  return base.copyWith(
    surface: ground,
    surfaceRaised: ground,
    // El hundido es el de la tira y los chips: se queda apenas separado del
    // fondo, para que la forma se lea.
    surfaceSunken: dark ? const Color(0xFF111111) : const Color(0xFFF0F0F0),
    textPrimary: ink,
    textSecondary: dark ? const Color(0xFFE0E0E0) : const Color(0xFF222222),
  );
}
