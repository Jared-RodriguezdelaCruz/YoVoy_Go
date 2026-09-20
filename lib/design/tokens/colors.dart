import 'package:flutter/material.dart';

/// Paleta de la app, disponible en los dos temas.
///
/// Los valores son los de la sección 6.2 del spec, uno por uno, y cada uno
/// está verificado contra su superficie en `test/design/route_palette_test.dart`.
///
/// Dos reglas sostienen toda la paleta:
///
/// 1. **Un color, un significado.** El índigo de marca identifica a la app y
///    marca la acción primaria; **no** significa "camión llegando". Los
///    colores de tiempo real son otros cuatro, aparte.
/// 2. **El índigo es del sistema, lo cálido es tuyo.** [brand] y los cuatro
///    semánticos son la voz del sistema; [cantera] marca únicamente lo que el
///    teléfono aprendió del usuario. El color dice de quién es el dato.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.outline,
    required this.lumen,
    required this.textPrimary,
    required this.textSecondary,
    required this.brand,
    required this.onBrand,
    required this.cantera,
    required this.onCantera,
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

  /// La luz que encienden las superficies elevadas.
  ///
  /// Es el tope del gradiente del que habla la sección 6.4 del spec: un 4 %
  /// que baja desde el borde superior, más un filo de 1 px. Prohibir la sombra
  /// no obliga a que todo sea plano. Lo usa `LitSurface`.
  final Color lumen;

  final Color textPrimary;
  final Color textSecondary;

  /// Índigo institucional.
  ///
  /// Extraído con cuentagotas el 20 de septiembre de 2026 del splash y el
  /// ícono de la app oficial (`com.mx.nrtec.agsstopbus`) y de la fotografía
  /// oficial de la Tarjeta Soluciones YoVoy: `#3A3578` en las tres fuentes.
  /// **Yo Voy no es verde.** El `#00854A` que este proyecto usó tres fases
  /// salió de una hoja en blanco y además nunca pasó 4.5:1.
  ///
  /// El hex cambia por tema porque el índigo institucional es oscuro: sobre la
  /// superficie oscura da 1.74:1 y no se lee. El tema oscuro usa el mismo
  /// índigo aclarado.
  final Color brand;

  /// Texto y contenido sobre [brand].
  final Color onBrand;

  /// El rosa de la piedra con la que está construida Aguascalientes.
  ///
  /// **Solo marca lo que el teléfono aprendió de ti**: favoritos, rutas de
  /// siempre, "sal en 6 min", historial. Nunca es decoración ni ambiente, y
  /// nunca aparece en la misma fila que un estado de frescura: [cantera] y
  /// [stale] son los dos cálidos del sistema y los separan 26° de tono.
  final Color cantera;

  /// Texto y contenido sobre [cantera].
  final Color onCantera;

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
    surface: Color(0xFF0E1016),
    surfaceRaised: Color(0xFF171A24),
    surfaceSunken: Color(0xFF080910),
    outline: Color(0xFF2A2E3D),
    lumen: Color(0x0AFFFFFF),
    textPrimary: Color(0xFFF2F3F7),
    textSecondary: Color(0xFFA2A7BD),
    brand: Color(0xFF8179DC),
    onBrand: Color(0xFF0E1016),
    cantera: Color(0xFFE0A98F),
    onCantera: Color(0xFF0E1016),
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
    surface: Color(0xFFF5F6FA),
    surfaceRaised: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFE7E9F2),
    outline: Color(0xFFC9CDDD),
    lumen: Color(0x0AFFFFFF),
    textPrimary: Color(0xFF0E1016),
    textSecondary: Color(0xFF565C70),
    brand: Color(0xFF3A3578),
    onBrand: Color(0xFFFFFFFF),
    cantera: Color(0xFF8A4B32),
    onCantera: Color(0xFFFFFFFF),
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
    Color? lumen,
    Color? textPrimary,
    Color? textSecondary,
    Color? brand,
    Color? onBrand,
    Color? cantera,
    Color? onCantera,
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
      lumen: lumen ?? this.lumen,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      brand: brand ?? this.brand,
      onBrand: onBrand ?? this.onBrand,
      cantera: cantera ?? this.cantera,
      onCantera: onCantera ?? this.onCantera,
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
      lumen: Color.lerp(lumen, other.lumen, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      onBrand: Color.lerp(onBrand, other.onBrand, t)!,
      cantera: Color.lerp(cantera, other.cantera, t)!,
      onCantera: Color.lerp(onCantera, other.onCantera, t)!,
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
