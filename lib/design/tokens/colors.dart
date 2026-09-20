import 'package:flutter/material.dart';

/// Paleta de la app, disponible en los dos temas.
///
/// Los valores del tema oscuro son los de la sección 6.2 del spec, uno por
/// uno. Los del claro son su equivalente invertido: mismos roles, mismos
/// significados, distinta superficie.
///
/// Regla que sostiene toda la paleta: **un color, un significado.** El verde
/// de marca identifica a la app y marca la acción primaria; **no** significa
/// "camión llegando". Los colores de tiempo real son otros cuatro, aparte.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.outline,
    required this.textPrimary,
    required this.textSecondary,
    required this.brand,
    required this.onBrand,
    required this.live,
    required this.stale,
    required this.unknown,
    required this.alert,
  });

  /// Base de la app.
  final Color surface;

  /// Superficie elevada: hoja inferior, cards.
  final Color surfaceRaised;

  /// Superficie hundida: campos, huecos.
  final Color surfaceSunken;

  /// Borde de 1 px. La jerarquía se resuelve con superficie y borde, nunca con
  /// sombra.
  final Color outline;

  final Color textPrimary;
  final Color textSecondary;

  /// Verde institucional.
  ///
  /// TODO(marca): `#00854A` es un PLACEHOLDER. La sección 6.2 del spec pide
  /// extraer el verde real con cuentagotas de las unidades o de la app
  /// oficial. No inventar el hex.
  final Color brand;

  /// Texto y contenido sobre [brand].
  final Color onBrand;

  /// Dato de menos de 60 s.
  final Color live;

  /// Dato de 60 a 180 s.
  final Color stale;

  /// Sin dato utilizable.
  final Color unknown;

  /// Alerta de servicio.
  final Color alert;

  /// Tema oscuro, el default de la app.
  static const AppColors dark = AppColors(
    surface: Color(0xFF0E1412),
    surfaceRaised: Color(0xFF17201C),
    surfaceSunken: Color(0xFF080C0A),
    outline: Color(0xFF2C3A33),
    textPrimary: Color(0xFFF2F5F3),
    textSecondary: Color(0xFF9BABA3),
    brand: Color(0xFF00854A),
    onBrand: Color(0xFFFFFFFF),
    live: Color(0xFF3DDC84),
    stale: Color(0xFFF2B705),
    unknown: Color(0xFF7A8A82),
    alert: Color(0xFFE5484D),
  );

  /// Tema claro. Obligatorio: el mapa de día se usa más.
  ///
  /// Los cuatro semánticos se oscurecen respecto al tema oscuro. No es
  /// capricho: `#3DDC84` sobre blanco da 2:1 y sería ilegible al sol, que es
  /// justo la situación para la que se diseña esta app.
  static const AppColors light = AppColors(
    surface: Color(0xFFF4F7F5),
    surfaceRaised: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFE6EBE8),
    outline: Color(0xFFC6D2CC),
    textPrimary: Color(0xFF0E1412),
    textSecondary: Color(0xFF566159),
    brand: Color(0xFF00854A),
    onBrand: Color(0xFFFFFFFF),
    live: Color(0xFF0F7A3E),
    stale: Color(0xFF8A6100),
    unknown: Color(0xFF5E6C65),
    alert: Color(0xFFC42A2F),
  );

  @override
  AppColors copyWith({
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceSunken,
    Color? outline,
    Color? textPrimary,
    Color? textSecondary,
    Color? brand,
    Color? onBrand,
    Color? live,
    Color? stale,
    Color? unknown,
    Color? alert,
  }) {
    return AppColors(
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      outline: outline ?? this.outline,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      brand: brand ?? this.brand,
      onBrand: onBrand ?? this.onBrand,
      live: live ?? this.live,
      stale: stale ?? this.stale,
      unknown: unknown ?? this.unknown,
      alert: alert ?? this.alert,
    );
  }

  @override
  AppColors lerp(covariant AppColors? other, double t) {
    if (other == null) {
      return this;
    }
    return AppColors(
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      surfaceSunken: Color.lerp(surfaceSunken, other.surfaceSunken, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      onBrand: Color.lerp(onBrand, other.onBrand, t)!,
      live: Color.lerp(live, other.live, t)!,
      stale: Color.lerp(stale, other.stale, t)!,
      unknown: Color.lerp(unknown, other.unknown, t)!,
      alert: Color.lerp(alert, other.alert, t)!,
    );
  }
}

/// Acceso corto a la paleta desde cualquier widget.
extension AppColorsContext on BuildContext {
  /// Los colores del tema activo.
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.dark;
}
