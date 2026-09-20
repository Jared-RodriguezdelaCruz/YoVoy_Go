import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/phase_placeholder.dart';
import '../../../app/routes.dart';

/// Mapa a pantalla completa con hoja inferior arrastrable, como en la sección 8.1
/// del spec.
class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PhasePlaceholder(
      title: 'Mapa',
      specSection: '8.1',
      phase: 5,
      // Mientras la pantalla no existe, este es el único camino a la galería
      // del design system. Desaparece con el placeholder.
      action: kDebugMode
          ? OutlinedButton.icon(
              onPressed: () => context.goNamed(AppRoute.gallery.name),
              icon: const Icon(Icons.palette_outlined),
              label: const Text('Ver el design system'),
            )
          : null,
    );
  }
}
