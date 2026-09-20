import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/spacing.dart';

/// Una superficie elevada **encendida**.
///
/// La sección 6.4 del spec prohíbe las sombras, y con razón: en tema oscuro la
/// sombra gris genérica no comunica nada y cuesta render. Pero prohibir la
/// sombra no obliga a que todo sea plano.
///
/// Esto es lo que la sustituye: un gradiente vertical del 4 % que baja desde
/// el borde superior, más un filo de 1 px un punto más claro que la
/// superficie. Un tablero encendido, una lámpara en un cuarto.
///
/// En render cuesta un `LinearGradient`: cero `saveLayer`, cero
/// `BackdropFilter`, nada de lo que prohíbe la sección 7.
class LitSurface extends StatelessWidget {
  const LitSurface({
    required this.child,
    this.padding = const EdgeInsets.all(Spacing.lg),
    this.borderRadius = AppRadius.cardRadius,
    this.outlined = true,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  /// El contorno de 1 px alrededor. Se apaga cuando la superficie ya está
  /// contenida por otra que sí lo lleva.
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: borderRadius,
        border: outlined
            ? Border.all(color: colors.outline, width: AppSizes.outlineWidth)
            : null,
        // La luz baja desde arriba y se acaba a dos tercios: más abajo ya no
        // hay lámpara, hay panel.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const <double>[0, 0.64],
          colors: <Color>[
            Color.alphaBlend(colors.lumen, colors.surfaceRaised),
            colors.surfaceRaised,
          ],
        ),
      ),
      child: Stack(
        children: <Widget>[
          Padding(padding: padding, child: child),
          // El filo: una línea de 1 px arriba, lo que en un objeto real sería
          // el canto que devuelve la luz.
          Positioned(
            top: 0,
            left: borderRadius.topLeft.x,
            right: borderRadius.topRight.x,
            child: Container(
              height: AppSizes.outlineWidth,
              color: Color.alphaBlend(
                colors.lumen,
                Color.alphaBlend(colors.lumen, colors.surfaceRaised),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
