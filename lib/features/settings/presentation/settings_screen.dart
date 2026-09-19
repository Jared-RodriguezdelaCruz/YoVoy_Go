import 'package:flutter/material.dart';

import '../../../app/phase_placeholder.dart';

/// Ajustes, y el panel del simulador en builds de debug, como en la sección 8.6
/// del spec.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const PhasePlaceholder(title: 'Ajustes', specSection: '8.6', phase: 8);
}
