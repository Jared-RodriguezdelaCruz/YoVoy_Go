import 'package:flutter/material.dart';

import 'tokens/colors.dart';
import 'tokens/spacing.dart';
import 'tokens/typography.dart';

/// Los temas de la app: señalética de transporte sobre Material 3.
///
/// Material 3 pone la infraestructura —tamaños de toque, accesibilidad,
/// componentes—; la capa visual viene de la sección 6 del spec: color plano,
/// jerarquía por peso y tamaño, y **sin sombras**. En tema oscuro la sombra
/// gris genérica no comunica nada y cuesta render, así que la jerarquía se
/// resuelve con superficie y contorno de 1 px.
abstract final class AppTheme {
  /// Tema oscuro. Es el default de la app.
  static ThemeData get dark => _build(AppColors.dark, Brightness.dark);

  /// Tema claro. Obligatorio: el mapa de día se usa más.
  static ThemeData get light => _build(AppColors.light, Brightness.light);

  static ThemeData _build(AppColors colors, Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;

    final ColorScheme scheme =
        (isDark ? const ColorScheme.dark() : const ColorScheme.light())
            .copyWith(
              brightness: brightness,
              primary: colors.brand,
              onPrimary: colors.onBrand,
              secondary: colors.brand,
              onSecondary: colors.onBrand,
              error: colors.alert,
              onError: const Color(0xFFFFFFFF),
              surface: colors.surface,
              onSurface: colors.textPrimary,
              onSurfaceVariant: colors.textSecondary,
              surfaceContainerLowest: colors.surfaceSunken,
              surfaceContainerLow: colors.surface,
              surfaceContainer: colors.surfaceRaised,
              surfaceContainerHigh: colors.surfaceRaised,
              surfaceContainerHighest: colors.surfaceRaised,
              outline: colors.outline,
              outlineVariant: colors.outline,
            );

    final TextTheme textTheme = AppTypography.textTheme(
      primary: colors.textPrimary,
      secondary: colors.textSecondary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: textTheme,
      fontFamily: AppTypography.family,
      scaffoldBackgroundColor: colors.surface,
      canvasColor: colors.surface,
      splashColor: colors.brand.withValues(alpha: 0.12),
      highlightColor: colors.brand.withValues(alpha: 0.08),
      extensions: <ThemeExtension<dynamic>>[colors],
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.title.copyWith(color: colors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: colors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardRadius,
          side: BorderSide(color: colors.outline, width: AppSizes.outlineWidth),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.outline,
        thickness: AppSizes.outlineWidth,
        space: AppSizes.outlineWidth,
      ),
      iconTheme: IconThemeData(color: colors.textSecondary, size: 20),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.sheetRadius,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.brand,
          foregroundColor: colors.onBrand,
          minimumSize: const Size(0, AppSizes.minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
          textStyle: AppTypography.label,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.chipRadius,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          minimumSize: const Size(0, AppSizes.minTouchTarget),
          side: BorderSide(color: colors.outline, width: AppSizes.outlineWidth),
          textStyle: AppTypography.label,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.chipRadius,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.brand,
          minimumSize: const Size(0, AppSizes.minTouchTarget),
          textStyle: AppTypography.label,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colors.textSecondary,
        textColor: colors.textPrimary,
        minVerticalPadding: Spacing.md,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.surfaceRaised,
        contentTextStyle: AppTypography.body.copyWith(
          color: colors.textPrimary,
        ),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.chipRadius),
      ),
    );
  }
}
