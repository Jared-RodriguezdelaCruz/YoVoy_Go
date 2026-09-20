import 'package:flutter_test/flutter_test.dart';
import 'package:yovoy_go/core/models/models.dart';

void main() {
  group('VehiclePosition', () {
    Map<String, dynamic> reporte({bool conBearing = true}) => <String, dynamic>{
      'vehicle_id': 'v7',
      'trip_id': 't1',
      'route_id': 'r20',
      'position': <String, dynamic>{'lat': 21.8853, 'lon': -102.2916},
      'timestamp': 1789000000,
      if (conBearing) 'bearing': 137.5,
      'speed': 8.3,
      'occupancy_status': 'FEW_SEATS_AVAILABLE',
      'current_stop_sequence': 4,
    };

    test('round-trip JSON', () {
      final VehiclePosition vehicle = VehiclePosition.fromJson(reporte());

      expect(vehicle.bearing, 137.5);
      expect(vehicle.occupancyStatus, OccupancyStatus.fewSeatsAvailable);
      expect(vehicle.toJson()['timestamp'], 1789000000);
    });

    test('un reporte sin bearing es válido', () {
      // Pasa en ~15 % de los reportes reales: el marcador degrada a círculo,
      // no a una flecha apuntando al norte.
      final VehiclePosition vehicle = VehiclePosition.fromJson(
        reporte(conBearing: false),
      );

      expect(vehicle.bearing, isNull);
    });

    test('ageAt mide contra el timestamp del vehículo', () {
      final VehiclePosition vehicle = VehiclePosition.fromJson(reporte());
      final DateTime ahora = vehicle.timestamp.add(const Duration(minutes: 2));

      expect(vehicle.ageAt(ahora), const Duration(minutes: 2));
    });
  });

  group('StopTimeUpdate', () {
    test('round-trip JSON con retraso', () {
      final StopTimeUpdate update = StopTimeUpdate.fromJson(<String, dynamic>{
        'trip_id': 't1',
        'stop_id': 's101',
        'stop_sequence': 4,
        'arrival_delay': 180,
        'predicted_arrival': 1789000180,
      });

      expect(update.arrivalDelay, const Duration(minutes: 3));
      expect(update.toJson()['arrival_delay'], 180);
    });

    test('sin predicción los campos quedan nulos', () {
      final StopTimeUpdate update = StopTimeUpdate.fromJson(<String, dynamic>{
        'trip_id': 't1',
        'stop_id': 's101',
        'stop_sequence': 4,
      });

      expect(update.arrivalDelay, isNull);
      expect(update.predictedArrival, isNull);
    });
  });

  group('ServiceAlert', () {
    final DateTime inicio = DateTime.utc(2026, 9, 20, 6);

    test('round-trip JSON', () {
      final ServiceAlert alert = ServiceAlert.fromJson(<String, dynamic>{
        'id': 'a1',
        'header': 'Desvío por obra en López Mateos',
        'affected_route_ids': <String>['r20'],
        'affected_stop_ids': <String>[],
        'cause': 'CONSTRUCTION',
        'effect': 'DETOUR',
        'description': 'La ruta 20 no entra al Centro hasta nuevo aviso.',
        'active_period': <String, dynamic>{'start': 1789012800, 'end': null},
      });

      expect(alert.cause, AlertCause.construction);
      expect(alert.effect, AlertEffect.detour);
      expect(alert.affectedRouteIds, <String>['r20']);
      expect(alert.toJson()['header'], 'Desvío por obra en López Mateos');
    });

    test('un periodo sin fin sigue vigente', () {
      final ServiceAlert alert = ServiceAlert(
        id: 'a1',
        header: 'Desvío',
        activePeriod: ActivePeriod(start: inicio),
      );

      expect(alert.isActiveAt(inicio.add(const Duration(days: 30))), isTrue);
      expect(
        alert.isActiveAt(inicio.subtract(const Duration(hours: 1))),
        isFalse,
      );
    });

    test('una alerta sin periodo se considera vigente', () {
      const ServiceAlert alert = ServiceAlert(id: 'a2', header: 'Aviso');

      expect(alert.isActiveAt(DateTime.utc(2030)), isTrue);
    });

    test('un periodo cerrado deja de aplicar al terminar', () {
      final ServiceAlert alert = ServiceAlert(
        id: 'a3',
        header: 'Cierre temporal',
        activePeriod: ActivePeriod(
          start: inicio,
          end: inicio.add(const Duration(hours: 4)),
        ),
      );

      expect(alert.isActiveAt(inicio.add(const Duration(hours: 2))), isTrue);
      expect(alert.isActiveAt(inicio.add(const Duration(hours: 5))), isFalse);
    });
  });
}
