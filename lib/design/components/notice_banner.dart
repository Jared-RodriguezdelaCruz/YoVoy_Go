import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// Una franja de aviso de una sola línea, sin nada que tocar.
///
/// Es la forma de [AlertBanner] —filo de color a la izquierda, ícono junto al
/// texto— sin lo que allá sobra: una alerta de servicio se expande porque trae
/// un párrafo detrás, y estos avisos se leen completos de un golpe.
///
/// El ícono acompaña al texto, nunca lo sustituye: la sección 11 del spec pide
/// que el color no sea el único portador de significado, y una franja que solo
/// se distinguiera por su filo no diría nada en blanco y negro.
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({
    required this.icon,
    required this.text,
    required this.edge,
    this.semanticsLabel,
    super.key,
  });

  final IconData icon;
  final String text;

  /// El color del filo y del ícono.
  final Color edge;

  /// Lo que se le dice al lector de pantalla, si el texto escrito no basta.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return Semantics(
      container: true,
      label: semanticsLabel,
      excludeSemantics: semanticsLabel != null,
      child: Material(
        color: colors.surfaceRaised,
        borderRadius: AppRadius.chipRadius,
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: edge, width: 3)),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md,
            vertical: Spacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, size: 18, color: edge),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(
                  text,
                  style: AppTypography.label.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
