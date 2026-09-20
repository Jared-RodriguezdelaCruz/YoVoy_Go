import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// Cuando algo falló.
///
/// Dice qué falló y ofrece reintentar. Sin disculpas y sin el párrafo largo
/// de siempre: "Sin señal de esta ruta", no "Lo sentimos, no fue posible
/// obtener la información en este momento".
class ErrorState extends StatelessWidget {
  const ErrorState({
    required this.title,
    required this.message,
    required this.onRetry,
    this.retryLabel = 'Reintentar',
    super.key,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.error_outline, size: 40, color: colors.alert),
            const SizedBox(height: Spacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.title.copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: Spacing.xl),
            FilledButton(onPressed: onRetry, child: Text(retryLabel)),
          ],
        ),
      ),
    );
  }
}
