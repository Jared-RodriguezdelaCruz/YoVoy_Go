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
      // Mientras la pantalla no existe, estos son los únicos caminos a la
      // galería y al panel del simulador. Desaparecen con el placeholder.
      action: kDebugMode
          ? Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: () => context.goNamed(AppRoute.gallery.name),
                  icon: const Icon(Icons.palette_outlined),
                  label: const Text('Ver el design system'),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.goNamed(AppRoute.simulator.name),
                  icon: const Icon(Icons.directions_bus_outlined),
                  label: const Text('Ver el simulador'),
                ),
              ],
            )
          : null,
    );
  }
}
