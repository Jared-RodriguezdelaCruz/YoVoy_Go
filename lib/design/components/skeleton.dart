import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/spacing.dart';

/// El estado de carga: la forma del contenido real, no un spinner centrado
/// (sección 9).
class SheetSkeleton extends StatelessWidget {
  const SheetSkeleton({this.lines = 3, super.key});

  final int lines;

  @override
  Widget build(BuildContext context) {
    final Color block = context.colors.surfaceSunken;

    Widget bar(double widthFactor, double height) => FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: block,
          borderRadius: AppRadius.chipRadius,
        ),
      ),
    );

    return Semantics(
      label: 'Cargando',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          bar(0.55, 22),
          for (int i = 1; i < lines; i++) ...<Widget>[
            const SizedBox(height: Spacing.sm),
            bar(i.isOdd ? 0.85 : 0.7, 16),
          ],
        ],
      ),
    );
  }
}
