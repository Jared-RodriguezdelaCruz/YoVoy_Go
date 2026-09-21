import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:yovoy_go/core/models/models.dart';
import 'package:yovoy_go/features/map/application/vehicle_interpolator.dart';

/// El interpolador: que los camiones no se teletransporten, y que tampoco
/// inventen por dónde anduvieron.
void main() {
  final DateTime t0 = DateTime.utc(2026, 9, 20, 12);

  VehiclePosition report(String id, LatLng at, DateTime when) =>
      VehiclePosition(
        vehicleId: id,
        tripId: 'T',
        routeId: 'R_01',
        position: at,
        timestamp: when,
      );

  const LatLng a = LatLng(21.880, -102.300);
  const LatLng b = LatLng(21.882, -102.298); // ~300 m

  test('a los 15 s de un reporte nuevo el camión va a la mitad', () {
    final VehicleInterpolator tracker = VehicleInterpolator()
      ..update(<VehiclePosition>[report('V1', a, t0)], t0)
      ..update(<VehiclePosition>[
        report('V1', b, t0.add(const Duration(seconds: 30))),
      ], t0.add(const Duration(seconds: 30)));

    final LatLng mid = tracker.positionOf(
      'V1',
      t0.add(const Duration(seconds: 45)),
    )!;
    expect(mid.latitude, closeTo((a.latitude + b.latitude) / 2, 1e-9));
    expect(mid.longitude, closeTo((a.longitude + b.longitude) / 2, 1e-9));
  });

  test('al terminar la ventana se queda quieto: no extrapola', () {
    final VehicleInterpolator tracker = VehicleInterpolator()
      ..update(<VehiclePosition>[report('V1', a, t0)], t0)
      ..update(<VehiclePosition>[
        report('V1', b, t0.add(const Duration(seconds: 30))),
      ], t0.add(const Duration(seconds: 30)));

    for (final int s in <int>[60, 90, 300]) {
      expect(
        tracker.positionOf('V1', t0.add(Duration(seconds: s))),
        b,
        reason: 'a los $s s tiene que seguir en su último reporte',
      );
    }
  });

  test('el primer reporte de un camión no se anima desde ningún lado', () {
    final VehicleInterpolator tracker = VehicleInterpolator()
      ..update(<VehiclePosition>[report('V1', a, t0)], t0);
    expect(tracker.positionOf('V1', t0), a);
  });

  test('un salto de más de 1.5 km no se desliza sobre las casas', () {
    const LatLng far = LatLng(21.900, -102.300); // ~2.2 km al norte
    final VehicleInterpolator tracker = VehicleInterpolator()
      ..update(<VehiclePosition>[report('V1', a, t0)], t0)
      ..update(<VehiclePosition>[
        report('V1', far, t0.add(const Duration(seconds: 30))),
      ], t0.add(const Duration(seconds: 30)));
    expect(tracker.positionOf('V1', t0.add(const Duration(seconds: 31))), far);
  });

  test('el que pierde señal se queda en su lugar y envejece', () {
    final VehicleInterpolator tracker = VehicleInterpolator()
      ..update(<VehiclePosition>[report('V1', a, t0)], t0)
      ..update(const <VehiclePosition>[], t0.add(const Duration(minutes: 2)));

    final VehicleFrame frame = tracker
        .frameAt(t0.add(const Duration(minutes: 4)))
        .single;
    expect(frame.position, a);
    expect(frame.age, const Duration(minutes: 4));
  });

  test('cuando vuelve después de perder señal, salta', () {
    final VehicleInterpolator tracker = VehicleInterpolator()
      ..update(<VehiclePosition>[report('V1', a, t0)], t0)
      ..update(const <VehiclePosition>[], t0.add(const Duration(seconds: 30)))
      ..update(<VehiclePosition>[
        report('V1', b, t0.add(const Duration(seconds: 60))),
      ], t0.add(const Duration(seconds: 60)));
    // Deslizarlo fingiría que lo vimos pasar por en medio.
    expect(tracker.positionOf('V1', t0.add(const Duration(seconds: 61))), b);
  });

  test('pasados 10 minutos sin reportar, se olvida', () {
    final VehicleInterpolator tracker = VehicleInterpolator()
      ..update(<VehiclePosition>[report('V1', a, t0)], t0)
      ..update(const <VehiclePosition>[], t0.add(const Duration(minutes: 11)));
    expect(tracker.length, 0);
    expect(tracker.vehicleOf('V1'), isNull);
  });

  test('el mismo lote otra vez no reinicia la animación', () {
    final VehicleInterpolator tracker = VehicleInterpolator()
      ..update(<VehiclePosition>[report('V1', a, t0)], t0);
    final List<VehiclePosition> second = <VehiclePosition>[
      report('V1', b, t0.add(const Duration(seconds: 30))),
    ];
    tracker
      ..update(second, t0.add(const Duration(seconds: 30)))
      ..update(second, t0.add(const Duration(seconds: 40)));
    expect(tracker.positionOf('V1', t0.add(const Duration(seconds: 60))), b);
  });

  test('sin interpolar, cada camión va directo a su último reporte', () {
    final VehicleInterpolator tracker = VehicleInterpolator()
      ..update(<VehiclePosition>[report('V1', a, t0)], t0)
      ..update(<VehiclePosition>[
        report('V1', b, t0.add(const Duration(seconds: 30))),
      ], t0.add(const Duration(seconds: 30)));
    final VehicleFrame frame = tracker
        .frameAt(t0.add(const Duration(seconds: 31)), interpolate: false)
        .single;
    expect(frame.position, b);
  });

  test('el reporte más nuevo de la flota es el del chip global', () {
    final VehicleInterpolator tracker = VehicleInterpolator()
      ..update(<VehiclePosition>[
        report('V1', a, t0),
        report('V2', b, t0.add(const Duration(seconds: 30))),
      ], t0.add(const Duration(seconds: 30)));
    expect(tracker.newestReport, t0.add(const Duration(seconds: 30)));
    expect(VehicleInterpolator().newestReport, isNull);
  });
}
