import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/tokens/colors.dart';
import '../../../design/tokens/spacing.dart';
import '../../../design/tokens/typography.dart';
import '../application/accessibility_filter.dart';

/// "Solo accesibles": para quien lo necesita es el primer filtro, no un
/// ícono en la ficha de cada parada.
///
/// Es un solo interruptor para toda la app: el mapa y el planificador leen y
/// guardan el mismo valor.
class AccessibleOnlyChip extends ConsumerWidget {
  const AccessibleOnlyChip({
    this.onMessage = 'Mostrando solo paradas verificadas como accesibles',
    this.offMessage =
        'Ocultar las paradas que no están verificadas como accesibles',
    super.key,
  });

  /// El tooltip con el filtro activo y apagado. Cambia con lo que filtra:
  /// paradas en el mapa, viajes en el planificador.
  final String onMessage;
  final String offMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = context.colors;
    final bool on = ref.watch(accessibleOnlyProvider).value ?? false;

    return Tooltip(
      message: on ? onMessage : offMessage,
      child: FilterChip(
        selected: on,
        onSelected: (_) => ref.read(accessibleOnlyProvider.notifier).toggle(),
        avatar: Icon(
          Icons.accessible,
          size: 18,
          color: on ? colors.onBrand : colors.textSecondary,
        ),
        showCheckmark: false,
        label: const Text('Solo accesibles'),
        labelStyle: AppTypography.label.copyWith(
          color: on ? colors.onBrand : colors.textPrimary,
        ),
        backgroundColor: colors.surfaceRaised,
        selectedColor: colors.brand,
        side: BorderSide(color: on ? colors.brand : colors.outline),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.chipRadius),
        materialTapTargetSize: MaterialTapTargetSize.padded,
      ),
    );
  }
}
