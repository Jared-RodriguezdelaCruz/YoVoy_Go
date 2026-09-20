import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:yovoy_go/core/models/converters/duration_seconds_converter.dart';
import 'package:yovoy_go/core/models/converters/epoch_date_time_converter.dart';
import 'package:yovoy_go/core/models/converters/gtfs_time_converter.dart';
import 'package:yovoy_go/core/models/converters/lat_lng_converter.dart';

void main() {
  group('GtfsTimeConverter', () {
    const GtfsTimeConverter converter = GtfsTimeConverter();

    test('lee una hora normal', () {
      expect(
        converter.fromJson('07:04:30'),
        const Duration(hours: 7, minutes: 4, seconds: 30),
      );
    });

    test('lee horas mayores a 24, que GTFS sí permite', () {
      // Un viaje que sale a las 23:50 y llega a la 1:30 sigue siendo el mismo
      // día de servicio. Un parseo de reloj revienta aquí.
      expect(
        converter.fromJson('25:30:00'),
        const Duration(hours: 25, minutes: 30),
      );
    });

    test('round-trip conserva la hora extendida', () {
      expect(converter.toJson(converter.fromJson('26:05:09')), '26:05:09');
    });

    test('rechaza formato inválido', () {
      expect(() => converter.fromJson('7:04'), throwsFormatException);
    });

    test('la variante nullable deja pasar el nulo', () {
      expect(const NullableGtfsTimeConverter().fromJson(null), isNull);
      expect(const NullableGtfsTimeConverter().toJson(null), isNull);
    });
  });

  group('LatLngConverter', () {
    test('round-trip conserva las coordenadas', () {
      const LatLngConverter converter = LatLngConverter();
      final LatLng aguascalientes = LatLng(21.8853, -102.2916);

      final LatLng recovered = converter.fromJson(
        converter.toJson(aguascalientes),
      );

      expect(recovered.latitude, aguascalientes.latitude);
      expect(recovered.longitude, aguascalientes.longitude);
    });

    test('la lista vacía sobrevive el round-trip', () {
      const LatLngListConverter converter = LatLngListConverter();
      expect(converter.fromJson(converter.toJson(<LatLng>[])), isEmpty);
    });
  });

  group('DurationSecondsConverter', () {
    test('round-trip en segundos', () {
      const DurationSecondsConverter converter = DurationSecondsConverter();
      expect(converter.toJson(converter.fromJson(245)), 245);
    });

    test('la variante nullable deja pasar el nulo', () {
      expect(const NullableDurationSecondsConverter().fromJson(null), isNull);
    });
  });

  group('EpochDateTimeConverter', () {
    test('conserva el instante en UTC', () {
      const EpochDateTimeConverter converter = EpochDateTimeConverter();
      final DateTime moment = DateTime.utc(2026, 9, 20, 7, 4);

      expect(converter.fromJson(converter.toJson(moment)), moment);
      expect(converter.fromJson(0).isUtc, isTrue);
    });
  });

  group('GtfsDateConverter', () {
    const GtfsDateConverter converter = GtfsDateConverter();

    test('lee el formato YYYYMMDD', () {
      expect(converter.fromJson('20260920'), DateTime.utc(2026, 9, 20));
    });

    test('escribe con ceros a la izquierda', () {
      expect(converter.toJson(DateTime.utc(2026, 1, 5)), '20260105');
    });

    test('rechaza una longitud distinta de ocho', () {
      expect(() => converter.fromJson('2026-09-20'), throwsFormatException);
    });
  });
}
