import 'dart:ui';

import 'package:latlong2/latlong.dart';

/// Algo que se puede tocar en el mapa.
sealed class MapHit {
  const MapHit(this.point);

  /// Dónde se dibujó, en píxeles del mapa.
  final Offset point;
}

final class VehicleHit extends MapHit {
  const VehicleHit(
    super.point, {
    required this.vehicleId,
    required this.routeId,
  });

  final String vehicleId;
  final String routeId;
}

final class ClusterHit extends MapHit {
  const ClusterHit(super.point, {required this.center});

  /// Adónde acercar el zoom al tocarlo.
  final LatLng center;
}

final class StopHit extends MapHit {
  const StopHit(super.point, {required this.stopId});

  final String stopId;
}

/// Lo que la capa de marcadores dibujó en su último frame.
///
/// La capa dibuja todo con un solo `CustomPainter`, así que no hay widgets a
/// los que colgarles un `GestureDetector`. En cambio, cada frame anota aquí
/// dónde quedó cada cosa, y el `onTap` del mapa pregunta. Así el mapa conserva
/// sus propios gestos —arrastrar, pellizcar, doble toque— sin pelear por
/// ellos con 40 detectores.
class MapHitRegistry {
  final List<MapHit> _hits = <MapHit>[];

  /// El radio de toque: 24 px alrededor del centro dan los 48 dp de área mínima
  /// que pide la sección 11 del spec.
  static const double radius = 24;

  void clear() => _hits.clear();

  void add(MapHit hit) => _hits.add(hit);

  int get length => _hits.length;

  /// Lo dibujado en el último frame, de solo lectura.
  List<MapHit> get all => List<MapHit>.unmodifiable(_hits);

  /// Lo más cercano a [point] dentro de [radius].
  ///
  /// Un camión le gana a una parada a la misma distancia: el camión es lo que
  /// se mueve, y si el dedo cayó entre los dos, lo más probable es que se
  /// buscara el camión.
  MapHit? hitAt(Offset point) {
    MapHit? best;
    double bestScore = double.infinity;
    for (final MapHit hit in _hits) {
      final double distance = (hit.point - point).distance;
      if (distance > radius) {
        continue;
      }
      final double score = hit is StopHit ? distance + 8 : distance;
      if (score < bestScore) {
        bestScore = score;
        best = hit;
      }
    }
    return best;
  }
}
