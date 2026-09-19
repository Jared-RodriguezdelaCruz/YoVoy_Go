import 'package:flutter/material.dart';

import '../../../app/phase_placeholder.dart';

/// Planificador de viaje, como en la sección 8.4 del spec.
class PlannerScreen extends StatelessWidget {
  const PlannerScreen({super.key});

  @override
  Widget build(BuildContext context) => const PhasePlaceholder(
    title: 'Planificador',
    specSection: '8.4',
    phase: 7,
  );
}
