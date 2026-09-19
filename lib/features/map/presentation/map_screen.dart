import 'package:flutter/material.dart';

import '../../../app/phase_placeholder.dart';

/// Mapa a pantalla completa con hoja inferior arrastrable, como en la sección 8.1
/// del spec.
class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const PhasePlaceholder(title: 'Mapa', specSection: '8.1', phase: 5);
}
