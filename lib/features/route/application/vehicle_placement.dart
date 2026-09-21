import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/models/models.dart';

/// Un camión colocado sobre la lista de paradas de su sentido.
@immutable
class PlacedVehicle {
  const PlacedVehicle({
    required this.vehicle,
    required this.afterIndex,
    required this.age,
  });

  final VehiclePosition vehicle;

  /// El índice de la última parada por la que pasó. El camión se dibuja
  /// entre esta y la siguiente; en la última, se dibuja llegando a ella.
  final int afterIndex;

  /// Qué tan viejo es su reporte. De aquí sale si su luz está encendida.
  final Duration age;
}

/// Coloca cada camión entre dos paradas de [stops].
///
/// Con `current_stop_sequence` (que cuenta desde 1) se usa tal cual, acotado
/// a la lista: un dato fuera de rango no puede sacar al camión de la
/// pantalla. Sin él, se toma la parada más cercana en línea recta. Es menos
/// exacto, pero es lo que se sabe; y ocultar el camión sería peor.
///
/// El resultado va en el orden de la ruta: primero los que van más atrás.
List<PlacedVehicle> placeVehicles({
  required List<Stop> stops,
  required List<VehiclePosition> vehicles,
  required DateTime now,
}) {
  if (stops.isEmpty) {
    return const <PlacedVehicle>[];
  }
  const Distance distance = Distance();
  final int last = stops.length - 1;

  int nearest(LatLng position) {
    int best = 0;
    double bestMeters = double.infinity;
    for (int i = 0; i < stops.length; i++) {
      final double meters = distance.as(
        LengthUnit.Meter,
        position,
        stops[i].position,
      );
      if (meters < bestMeters) {
        best = i;
        bestMeters = meters;
      }
    }
    return best;
  }

  final List<PlacedVehicle> placed = <PlacedVehicle>[
    for (final VehiclePosition vehicle in vehicles)
      PlacedVehicle(
        vehicle: vehicle,
        afterIndex: switch (vehicle.currentStopSequence) {
          final int sequence => (sequence - 1).clamp(0, last),
          null => nearest(vehicle.position),
        },
        age: vehicle.ageAt(now),
      ),
  ];
  placed.sort(
    (PlacedVehicle a, PlacedVehicle b) => a.afterIndex.compareTo(b.afterIndex),
  );
  return placed;
}
