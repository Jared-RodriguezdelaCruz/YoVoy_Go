import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:yovoy_go/core/models/models.dart';
import 'package:yovoy_go/features/route/application/vehicle_placement.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 9, 21, 14);

  // Cuatro paradas en fila hacia el norte, a unos 110 m una de otra.
  final List<Stop> stops = <Stop>[
    for (int i = 0; i < 4; i++)
      Stop(id: 'P$i', name: 'Parada $i', lat: 21.88 + i * 0.001, lon: -102.29),
  ];

  VehiclePosition bus(
    String id, {
    int? sequence,
    LatLng position = const LatLng(21.88, -102.29),
    Duration age = const Duration(seconds: 20),
  }) => VehiclePosition(
    vehicleId: id,
    tripId: 'T',
    routeId: 'R',
    position: position,
    timestamp: now.subtract(age),
    currentStopSequence: sequence,
  );

  test('usa current_stop_sequence, que cuenta desde 1', () {
    final List<PlacedVehicle> placed = placeVehicles(
      stops: stops,
      vehicles: <VehiclePosition>[bus('a', sequence: 2)],
      now: now,
    );

    expect(placed.single.afterIndex, 1);
    expect(placed.single.age, const Duration(seconds: 20));
  });

  test('una secuencia fuera de rango no saca al camión de la tira', () {
    final List<PlacedVehicle> placed = placeVehicles(
      stops: stops,
      vehicles: <VehiclePosition>[
        bus('alto', sequence: 99),
        bus('bajo', sequence: 0),
      ],
      now: now,
    );

    expect(
      placed.map((PlacedVehicle p) => p.afterIndex),
      containsAll(<int>[3, 0]),
    );
  });

  test('sin secuencia, cae en la parada más cercana', () {
    final List<PlacedVehicle> placed = placeVehicles(
      stops: stops,
      vehicles: <VehiclePosition>[
        bus('sin', position: const LatLng(21.8821, -102.29)),
      ],
      now: now,
    );

    expect(placed.single.afterIndex, 2);
  });

  test('dos camiones en el mismo tramo quedan los dos, en orden', () {
    final List<PlacedVehicle> placed = placeVehicles(
      stops: stops,
      vehicles: <VehiclePosition>[
        bus('c', sequence: 3),
        bus('a', sequence: 1),
        bus('b', sequence: 1),
      ],
      now: now,
    );

    expect(placed, hasLength(3));
    expect(placed.map((PlacedVehicle p) => p.afterIndex), <int>[0, 0, 2]);
  });

  test('sin paradas no hay dónde ponerlos', () {
    expect(
      placeVehicles(
        stops: const <Stop>[],
        vehicles: <VehiclePosition>[bus('a', sequence: 1)],
        now: now,
      ),
      isEmpty,
    );
  });
}
