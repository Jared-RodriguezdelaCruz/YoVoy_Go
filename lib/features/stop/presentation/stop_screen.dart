import 'package:flutter/material.dart';

import '../../../app/phase_placeholder.dart';

/// Detalle de parada: arribos ordenados por ETA, como en la sección 8.2 del spec.
class StopScreen extends StatelessWidget {
  const StopScreen({required this.stopId, super.key});

  final String stopId;

  @override
  Widget build(BuildContext context) => PhasePlaceholder(
    title: 'Parada',
    specSection: '8.2',
    phase: 6,
    detail: 'stopId: $stopId',
  );
}
