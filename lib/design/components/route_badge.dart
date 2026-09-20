import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/route_palette.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// Tamaños de la placa de ruta.
enum RouteBadgeSize {
  /// Dentro de una lista densa.
  small(fontSize: 15, minWidth: 30, verticalPadding: 2),

  /// El default: filas de arribos, callouts.
  medium(fontSize: 20, minWidth: 38, verticalPadding: 3),

  /// Encabezado de la pantalla de ruta.
  large(fontSize: 28, minWidth: 52, verticalPadding: 5);

  const RouteBadgeSize({
    required this.fontSize,
    required this.minWidth,
    required this.verticalPadding,
  });

  final double fontSize;
  final double minWidth;
  final double verticalPadding;
}

/// La placa con el código de una ruta: "20", "31-A".
///
/// Rectangular y sin radio a propósito, como en la sección 6.4 del spec: la
/// señalética no redondea. El color de texto se mide contra la placa, que es
/// lo que permite que una placa ámbar y una azul marino usen el mismo widget
/// sin que ninguna quede ilegible.
class RouteBadge extends StatelessWidget {
  const RouteBadge({
    required this.shortName,
    required this.routeId,
    this.gtfsColor,
    this.gtfsTextColor,
    this.size = RouteBadgeSize.medium,
    super.key,
  });

  /// El código que la gente dice en voz alta.
  final String shortName;

  /// De aquí sale el color cuando GTFS no trae uno. La misma ruta, el mismo
  /// color siempre.
  final String routeId;

  /// `route_color` de GTFS, hexadecimal sin `#`.
  final String? gtfsColor;

  /// `route_text_color` de GTFS. Se respeta solo si es legible sobre la placa:
  /// el feed oficial trae varias combinaciones que no llegan a 4.5:1.
  final String? gtfsTextColor;

  final RouteBadgeSize size;

  @override
  Widget build(BuildContext context) {
    final Color background = RoutePalette.colorForRoute(
      routeId: routeId,
      gtfsColor: gtfsColor,
    );
    final Color foreground = RoutePalette.inkFor(
      background,
      gtfsTextColor: gtfsTextColor,
    );
    final AppColors colors = context.colors;

    // En tema claro, los tonos brillantes se disuelven contra el fondo. La
    // placa sigue legible por dentro, pero deja de tener forma: por eso el
    // contorno aparece solo cuando hace falta, no siempre.
    final bool outlined = RoutePalette.needsOutline(background, colors.surface);

    return Semantics(
      label: 'Ruta $shortName',
      excludeSemantics: true,
      // `DecoratedBox` y no `Container` con `alignment`: un Container alineado
      // se estira hasta el ancho que le den, y dentro de un `Wrap` eso
      // convierte la placa en una banda de lado a lado. El `widthFactor: 1`
      // centra el texto sin dejar que la placa crezca.
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.plate),
          border: outlined
              ? Border.all(color: colors.outline, width: AppSizes.outlineWidth)
              : null,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: size.minWidth),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: Spacing.sm,
                vertical: size.verticalPadding,
              ),
              child: Text(
                shortName,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: AppTypography.routeBadge.copyWith(
                  fontSize: size.fontSize,
                  color: foreground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
