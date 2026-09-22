import 'package:flutter/material.dart';

import '../../core/models/enums.dart';
import '../tokens/colors.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// Qué tan lleno viene el camión: una, dos o tres figuras, y la palabra.
///
/// Como el indicador de NS, pero con la palabra siempre al lado. El color
/// acompaña y nunca carga el significado solo: hay daltonismo, y hay sol
/// directo. Sin dato no pinta nada, porque "no sé qué tan lleno viene" no le
/// sirve a nadie en una fila de arribos.
class OccupancyIndicator extends StatelessWidget {
  const OccupancyIndicator({
    required this.status,
    this.large = false,
    super.key,
  });

  final OccupancyStatus? status;

  /// Para el modo paradero.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final OccupancyStatus? value = status;
    if (value == null) {
      return const SizedBox.shrink();
    }
    final AppColors colors = context.colors;
    final OccupancyLevel level = OccupancyLevel.of(value);
    final Color color = level == OccupancyLevel.full
        ? colors.alert
        : colors.textSecondary;
    final double iconSize = large ? 22 : 14;

    return Semantics(
      label: level.word,
      excludeSemantics: true,
      // Un solo texto con las figuras dentro: en un renglón angosto la
      // palabra baja a la siguiente línea en vez de desbordarse.
      child: Text.rich(
        TextSpan(
          children: <InlineSpan>[
            for (int i = 0; i < 3; i++)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Icon(
                  i < level.figures ? Icons.person : Icons.person_outline,
                  size: iconSize,
                  color: i < level.figures ? color : colors.outline,
                ),
              ),
            WidgetSpan(child: SizedBox(width: large ? Spacing.sm : Spacing.xs)),
            TextSpan(text: level.word),
          ],
        ),
        style: (large ? AppTypography.body : AppTypography.caption).copyWith(
          color: color,
        ),
      ),
    );
  }
}

/// Los seis valores de GTFS-Realtime, en los tres grados que se pueden leer
/// de un vistazo.
enum OccupancyLevel {
  empty(1, 'va vacío'),
  filling(2, 'va llenándose'),
  full(3, 'va lleno');

  const OccupancyLevel(this.figures, this.word);

  final int figures;
  final String word;

  static OccupancyLevel of(OccupancyStatus status) => switch (status) {
    OccupancyStatus.empty || OccupancyStatus.manySeatsAvailable => empty,
    OccupancyStatus.fewSeatsAvailable ||
    OccupancyStatus.standingRoomOnly => filling,
    OccupancyStatus.crushedStandingRoomOnly || OccupancyStatus.full => full,
  };
}
