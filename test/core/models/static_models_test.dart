import 'package:flutter_test/flutter_test.dart';
import 'package:yovoy_go/core/models/models.dart';

void main() {
  group('Agency', () {
    test('round-trip JSON', () {
      const Map<String, dynamic> json = <String, dynamic>{
        'agency_id': 'cmov',
        'agency_name': 'Coordinación de Movilidad',
        'agency_url': 'https://example.mx',
        'agency_timezone': 'America/Mexico_City',
      };

      expect(Agency.fromJson(json).toJson(), json);
    });
  });

  group('TransitRoute', () {
    test('round-trip JSON con color', () {
      const Map<String, dynamic> json = <String, dynamic>{
        'route_id': 'r20',
        'route_short_name': '20',
        'route_long_name': 'Centro — Bonanza',
        'route_type': 3,
        'route_color': '00854A',
        'route_text_color': 'FFFFFF',
      };

      expect(TransitRoute.fromJson(json).toJson(), json);
    });

    test('el color ausente es nulo, no un default inventado', () {
      final TransitRoute route = TransitRoute.fromJson(<String, dynamic>{
        'route_id': 'r31',
        'route_short_name': '31',
        'route_long_name': 'Insurgentes — Morelos',
      });

      expect(route.color, isNull);
      expect(route.textColor, isNull);
      // El tipo sí tiene default: en la v1 todo es autobús.
      expect(route.type, 3);
    });
  });

  group('Stop', () {
    test('round-trip JSON', () {
      const Map<String, dynamic> json = <String, dynamic>{
        'stop_id': 's101',
        'stop_name': 'Bonanza',
        'stop_lat': 21.8853,
        'stop_lon': -102.2916,
        'stop_code': 'B-12',
        'wheelchair_boarding': 1,
      };

      final Stop stop = Stop.fromJson(json);

      expect(stop.toJson(), json);
      expect(stop.wheelchairBoarding, WheelchairBoarding.accessible);
      expect(stop.position.latitude, 21.8853);
    });

    test(
      'sin wheelchair_boarding queda en unknown, que no es "no accesible"',
      () {
        final Stop stop = Stop.fromJson(<String, dynamic>{
          'stop_id': 's102',
          'stop_name': 'CBTIS',
          'stop_lat': 21.88,
          'stop_lon': -102.29,
        });

        expect(stop.wheelchairBoarding, WheelchairBoarding.unknown);
        expect(stop.code, isNull);
      },
    );
  });

  group('Trip', () {
    test('round-trip JSON', () {
      const Map<String, dynamic> json = <String, dynamic>{
        'trip_id': 't1',
        'route_id': 'r20',
        'service_id': 'entre_semana',
        'trip_headsign': 'Centro',
        'direction_id': 0,
        'shape_id': 'sh20_0',
      };

      expect(Trip.fromJson(json).toJson(), json);
    });
  });

  group('StopTime', () {
    test('acepta una hora después de la medianoche', () {
      final StopTime stopTime = StopTime.fromJson(<String, dynamic>{
        'trip_id': 't1',
        'stop_id': 's101',
        'stop_sequence': 4,
        'arrival_time': '25:30:00',
        'departure_time': '25:31:00',
      });

      expect(stopTime.arrivalTime, const Duration(hours: 25, minutes: 30));
      expect(stopTime.toJson()['departure_time'], '25:31:00');
    });
  });

  group('Shape', () {
    test('round-trip conserva el orden de los puntos', () {
      const Map<String, dynamic> json = <String, dynamic>{
        'shape_id': 'sh20_0',
        'points': <Map<String, dynamic>>[
          <String, dynamic>{'lat': 21.88, 'lon': -102.29},
          <String, dynamic>{'lat': 21.89, 'lon': -102.30},
        ],
      };

      final Shape shape = Shape.fromJson(json);

      expect(shape.points.first.latitude, 21.88);
      expect(shape.toJson(), json);
    });

    test('una ruta sin trazo es lista vacía, no error', () {
      final Shape shape = Shape.fromJson(<String, dynamic>{
        'shape_id': 'sh_sin_trazo',
      });

      expect(shape.points, isEmpty);
    });
  });

  group('Calendar', () {
    final Calendar entreSemana = Calendar.fromJson(<String, dynamic>{
      'service_id': 'entre_semana',
      'days': <String>['monday', 'tuesday', 'wednesday', 'thursday', 'friday'],
      'start_date': '20260101',
      'end_date': '20261231',
    });

    test('round-trip JSON', () {
      expect(entreSemana.toJson()['start_date'], '20260101');
      expect(entreSemana.days, hasLength(5));
    });

    test('corre un martes dentro del periodo', () {
      expect(entreSemana.runsOn(DateTime.utc(2026, 9, 22)), isTrue);
    });

    test('no corre un domingo', () {
      expect(entreSemana.runsOn(DateTime.utc(2026, 9, 20)), isFalse);
    });

    test('no corre fuera del periodo', () {
      expect(entreSemana.runsOn(DateTime.utc(2027, 1, 5)), isFalse);
    });
  });

  group('Frequency', () {
    final Frequency r01 = Frequency.fromJson(<String, dynamic>{
      'trip_id': 'R_01_ES_0',
      'start_time': '05:50:00',
      'end_time': '23:30:00',
      'headway_secs': 1199,
      'exact_times': false,
    });

    test('round-trip JSON', () {
      expect(r01.headway, const Duration(seconds: 1199));
      expect(r01.startTime, const Duration(hours: 5, minutes: 50));
      expect(r01.toJson()['end_time'], '23:30:00');
    });

    test('la ventana cubre el servicio, no la madrugada', () {
      expect(r01.coversTime(const Duration(hours: 7)), isTrue);
      expect(r01.coversTime(const Duration(hours: 4)), isFalse);
    });

    test('la flota sale del intervalo y de la vuelta', () {
      // Dos horas y media de vuelta con 20 minutos de intervalo: ocho
      // unidades. El número no se elige a ojo, se cuenta.
      expect(r01.vehiclesFor(const Duration(seconds: 8850)), 8);
      expect(r01.vehiclesFor(Duration.zero), 0);
    });

    test('sin intervalo no hay flota que repartir', () {
      final Frequency rota = r01.copyWith(headway: Duration.zero);

      expect(rota.vehiclesFor(const Duration(hours: 2)), 0);
    });
  });
}
