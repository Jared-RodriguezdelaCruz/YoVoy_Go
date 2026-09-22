import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// "suele llegar 3 min tarde · según 14 observaciones tuyas".
///
/// Es lo que una app oficial nunca va a publicar sobre sí misma. Sin texto no
/// ocupa espacio: con pocas observaciones la app calla en vez de presumir.
class ReliabilityNote extends StatelessWidget {
  const ReliabilityNote({required this.text, super.key});

  final String? text;

  @override
  Widget build(BuildContext context) {
    final String? value = text;
    if (value == null) {
      return const SizedBox.shrink();
    }
    final AppColors colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 1),
            // No en cantera, aunque sea algo que el teléfono aprendió: va en
            // la fila del `EtaChip`, y cantera no comparte fila con un estado
            // de frescura (DESIGN.md).
            child: Icon(Icons.history, size: 14, color: colors.textSecondary),
          ),
          const SizedBox(width: Spacing.xs),
          Expanded(
            child: Text(
              value,
              style: AppTypography.caption.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
