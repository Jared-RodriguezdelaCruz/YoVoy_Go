import 'package:latlong2/latlong.dart';

import '../../models/models.dart';
import '../transit_repository.dart';

/// El repositorio contra el feed real, **sin implementar**.
///
/// Existe en la v1 a propósito, como pide la sección 4.1 del spec: para que la
/// forma del código ya contemple su llegada. Cada método dice qué endpoint de
/// GTFS-Realtime lo alimentaría el día que exista.
///
/// Lo que ya se sabe del lado real: el feed estático oficial existe y está
/// empaquetado en `assets/mock/` (fase 4a). Lo que falta es el tiempo real —la
/// app oficial refresca posiciones cada 30 s—, y eso entra por aquí sin tocar
/// los modelos.
class RemoteTransitRepository implements TransitRepository {
  const RemoteTransitRepository({this.baseUrl = ''});

  /// La raíz del feed. Vacía mientras no exista.
  final String baseUrl;

  @override
  Future<List<TransitRoute>> getRoutes() {
    // TODO(api): GET /gtfs/routes.txt del feed estático, cacheado en disco.
    throw UnimplementedError('getRoutes: no hay API real todavía');
  }

  @override
  Future<TransitRoute> getRoute(String routeId) {
    // TODO(api): la misma routes.txt, filtrada en cliente.
    throw UnimplementedError('getRoute: no hay API real todavía');
  }

  @override
  Future<Shape> getShape(String shapeId) {
    // TODO(api): GET /gtfs/shapes.txt, agrupado por shape_id.
    throw UnimplementedError('getShape: no hay API real todavía');
  }

  @override
  Future<List<Stop>> getStopsNear(LatLng center, {double radiusMeters = 500}) {
    // TODO(api): GET /gtfs/stops.txt e índice espacial local. El feed no
    // ofrece búsqueda por radio: se resuelve en el cliente.
    throw UnimplementedError('getStopsNear: no hay API real todavía');
  }

  @override
  Future<List<Stop>> getStopsForRoute(String routeId) {
    // TODO(api): stop_times.txt + trips.txt, cruzados por trip_id.
    throw UnimplementedError('getStopsForRoute: no hay API real todavía');
  }

  @override
  Future<List<Arrival>> getArrivals(String stopId) {
    // TODO(api): GET /gtfs-rt/trip-updates (protobuf `FeedMessage`), con
    // frequencies.txt como respaldo cuando no haya predicción.
    throw UnimplementedError('getArrivals: no hay API real todavía');
  }

  @override
  Stream<List<VehiclePosition>> watchVehicles({String? routeId}) {
    // TODO(api): GET /gtfs-rt/vehicle-positions cada 30 s, que es la cadencia
    // real del sistema. No pedir más seguido: no hay dato nuevo.
    throw UnimplementedError('watchVehicles: no hay API real todavía');
  }

  @override
  Stream<List<ServiceAlert>> watchAlerts() {
    // TODO(api): GET /gtfs-rt/service-alerts, con sondeo espaciado.
    throw UnimplementedError('watchAlerts: no hay API real todavía');
  }

  @override
  Future<List<Itinerary>> planTrip({
    required LatLng from,
    required LatLng to,
    DateTime? departAt,
  }) {
    // TODO(api): un motor de ruteo (OTP o similar). No hay endpoint GTFS que
    // lo resuelva: es un servicio aparte.
    throw UnimplementedError('planTrip: no hay API real todavía');
  }
}
