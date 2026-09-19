import 'package:flutter/material.dart';

import '../../../app/phase_placeholder.dart';

/// Paradas y rutas guardadas, persistidas localmente, como en la sección 8.5
/// del spec.
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const PhasePlaceholder(title: 'Favoritos', specSection: '8.5', phase: 8);
}
