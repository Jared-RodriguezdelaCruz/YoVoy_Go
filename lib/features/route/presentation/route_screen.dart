import 'package:flutter/material.dart';

import '../../../app/phase_placeholder.dart';

/// Detalle de ruta: trazo, paradas en secuencia y vehículos activos, como en la
/// sección 8.3 del spec.
class RouteScreen extends StatelessWidget {
  const RouteScreen({required this.routeId, super.key});

  final String routeId;

  @override
  Widget build(BuildContext context) => PhasePlaceholder(
    title: 'Ruta',
    specSection: '8.3',
    phase: 6,
    detail: 'routeId: $routeId',
  );
}
