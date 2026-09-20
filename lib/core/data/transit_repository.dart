import 'package:latlong2/latlong.dart';

import '../models/models.dart';

/// El contrato de datos de la app, tal cual lo fija la sección 4.1 del spec.
///
/// Dos implementaciones: `MockTransitRepository`, que lee `assets/mock/` y
/// simula el sistema **con sus fallas**, y `RemoteTransitRepository`, que hoy
/// es un esqueleto.
///
/// La regla que sostiene esta interfaz: **ninguna capa superior sabe cuál está
/// activa.** Ningún widget importa una implementación concreta; todo pasa por
/// `transitRepositoryProvider`.
abstract interface class TransitRepository {
  /// Todas las rutas del sistema.
  Future<List<TransitRoute>> getRoutes();

  /// Una ruta por id. Lanza [StateError] si no existe.
  Future<TransitRoute> getRoute(String routeId);

  /// El trazo de una ruta. Puede venir sin puntos: eso no es un error.
  Future<Shape> getShape(String shapeId);

  /// Paradas dentro de [radiusMeters] de [center], de la más cercana a la más
  /// lejana.
  Future<List<Stop>> getStopsNear(LatLng center, {double radiusMeters});

  /// Las paradas de una ruta, en el orden en que las recorre.
  Future<List<Stop>> getStopsForRoute(String routeId);

  /// Los próximos arribos a una parada.
  ///
  /// Cada [Arrival] trae su `confidence` y su `dataAge`: de ahí sale si la UI
  /// puede mostrar minutos o tiene que decir "sin señal".
  Future<List<Arrival>> getArrivals(String stopId);

  /// Posiciones de los vehículos, renovadas a la cadencia real del sistema.
  ///
  /// Sin [routeId] entrega todos. El stream emite cada 30 s, que es lo que
  /// tarda el sistema real: la UI interpola entre reportes (§7).
  Stream<List<VehiclePosition>> watchVehicles({String? routeId});

  /// Alertas de servicio vigentes.
  Stream<List<ServiceAlert>> watchAlerts();

  /// Itinerarios de [from] a [to].
  ///
  /// Devuelve lista vacía cuando no hay ruta: la pantalla de resultados vacíos
  /// es tan importante como la de resultados.
  Future<List<Itinerary>> planTrip({
    required LatLng from,
    required LatLng to,
    DateTime? departAt,
  });
}
