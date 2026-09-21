import 'dart:async';
import 'dart:math';

import 'package:latlong2/latlong.dart';

import '../../config/freshness.dart';
import '../../models/models.dart';
import '../transit_repository.dart';
import 'mock_dataset.dart';
import 'simulator_config.dart';
import 'transit_simulator.dart';

/// El repositorio que alimenta la app en la v1.
///
/// Lee el dataset real de `assets/mock/` —48 rutas de Aguascalientes— y lo
/// sirve **con las fallas de un sistema real**: latencia, errores, señal
/// perdida, datos viejos. La sección 4.2 del spec lo pide así, y no es
/// pesimismo: es la única forma de que la UI se diseñe contra lo que va a
/// encontrarse.
class MockTransitRepository implements TransitRepository {
  MockTransitRepository({
    required MockDataset dataset,
    SimulatorConfig config = const SimulatorConfig(),
    TransitSimulator? simulator,
    DateTime Function()? clock,
  }) : _dataset = dataset,
       _config = config,
       _clock = clock ?? DateTime.now,
       _simulator =
           simulator ?? TransitSimulator(dataset: dataset, config: config),
       _faults = Random(config.seed);

  final MockDataset _dataset;
  SimulatorConfig _config;
  final DateTime Function() _clock;
  TransitSimulator _simulator;

  /// El generador de desgracias: latencia y errores. Va aparte del simulador
  /// para que cambiar la tasa de error no mueva a los camiones de lugar.
  Random _faults;

  MockDataset get dataset => _dataset;
  TransitSimulator get simulator => _simulator;
  SimulatorConfig get config => _config;

  /// Cambia los parámetros en caliente, desde el panel de debug.
  ///
  /// El simulador se reconstruye solo si cambió algo que afecta al movimiento:
  /// subirle la tasa de error no tiene por qué teletransportar la flota.
  void updateConfig(SimulatorConfig next) {
    final bool movementChanged =
        next.seed != _config.seed ||
        next.minSpeedKmh != _config.minSpeedKmh ||
        next.maxSpeedKmh != _config.maxSpeedKmh ||
        next.minDwell != _config.minDwell ||
        next.maxDwell != _config.maxDwell ||
        next.signalLossRate != _config.signalLossRate ||
        next.reportInterval != _config.reportInterval;

    _config = next;
    _faults = Random(next.seed);
    if (movementChanged) {
      _simulator = TransitSimulator(
        dataset: _dataset,
        config: next,
        epoch: _simulator.epoch,
      );
    }
  }

  // -- El contrato ----------------------------------------------------------

  /// La red se arma una vez: sus índices no cambian mientras la app vive.
  late final TransitNetwork _network = TransitNetwork(
    routes: _dataset.routes,
    trips: _dataset.trips,
    shapes: _dataset.shapes,
    stops: _dataset.stops,
    stopIdsByTrip: <String, List<String>>{
      for (final Trip trip in _dataset.trips)
        trip.id: <String>[
          for (final StopTime time in _dataset.stopTimesForTrip(trip.id))
            time.stopId,
        ],
    },
  );

  @override
  Future<TransitNetwork> getNetwork() => _call('la red', () => _network);

  @override
  Future<List<TransitRoute>> getRoutes() =>
      _call('las rutas', () => _dataset.routes);

  @override
  Future<TransitRoute> getRoute(String routeId) =>
      _call('la ruta $routeId', () {
        final TransitRoute? route = _dataset.route(routeId);
        if (route == null) {
          throw StateError('no existe la ruta $routeId');
        }
        return route;
      });

  @override
  Future<Shape> getShape(String shapeId) => _call('el trazo $shapeId', () {
    final Shape? shape = _dataset.shape(shapeId);
    if (shape == null) {
      throw StateError('no existe el trazo $shapeId');
    }
    return shape;
  });

  @override
  Future<List<Stop>> getStopsNear(LatLng center, {double radiusMeters = 500}) =>
      _call('las paradas cercanas', () {
        final List<({Stop stop, double distance})> near =
            <({Stop stop, double distance})>[];
        for (final Stop stop in _dataset.stops) {
          final double distance = _meters(center, stop.position);
          if (distance <= radiusMeters) {
            near.add((stop: stop, distance: distance));
          }
        }
        near.sort(
          (
            ({Stop stop, double distance}) a,
            ({Stop stop, double distance}) b,
          ) => a.distance.compareTo(b.distance),
        );
        return <Stop>[
          for (final ({Stop stop, double distance}) row in near) row.stop,
        ];
      });

  @override
  Future<List<Stop>> getStopsForRoute(String routeId) =>
      _call('las paradas de la ruta $routeId', () {
        final List<Trip> trips = _dataset.tripsForRoute(routeId);
        if (trips.isEmpty) {
          return const <Stop>[];
        }
        // El sentido de ida: la lista de paradas de una ruta se lee en un
        // orden, no en los dos a la vez.
        final Trip outbound = trips.firstWhere(
          (Trip trip) => trip.directionId == 0,
          orElse: () => trips.first,
        );
        return <Stop>[
          for (final StopTime time in _dataset.stopTimesForTrip(outbound.id))
            if (_dataset.stop(time.stopId) case final Stop stop) stop,
        ];
      });

  @override
  Future<List<Arrival>> getArrivals(String stopId) =>
      _call('los arribos de la parada $stopId', () => _arrivalsAt(stopId));

  @override
  Stream<List<VehiclePosition>> watchVehicles({String? routeId}) =>
      _ticker<List<VehiclePosition>>(
        () => _simulator.positionsAt(_clock(), routeId: routeId),
      );

  @override
  Stream<List<ServiceAlert>> watchAlerts() => _ticker<List<ServiceAlert>>(() {
    final DateTime now = _clock();
    return <ServiceAlert>[
      for (final ServiceAlert alert in _dataset.alerts)
        if (alert.isActiveAt(now)) alert,
    ];
  });

  @override
  Future<List<Itinerary>> planTrip({
    required LatLng from,
    required LatLng to,
    DateTime? departAt,
  }) => _call('el viaje', () {
    for (final PrecookedTrip pair in _dataset.precookedTrips) {
      final bool matches =
          _meters(from, pair.from) <= pair.matchRadiusMeters &&
          _meters(to, pair.to) <= pair.matchRadiusMeters;
      if (matches) {
        return pair.itineraries;
      }
    }
    // Ni cerca de ningún par: no hay ruta que ofrecer, y decirlo es la
    // respuesta correcta (§4.3).
    return const <Itinerary>[];
  });

  // -- Lo que decide qué ve el usuario --------------------------------------

  /// Los arribos a una parada, con su confianza y su edad.
  ///
  /// **Aquí vive la regla del producto.** Un arribo es `live` cuando hay un
  /// vehículo reportando; `scheduled` cuando solo hay frecuencia —"pasa cada
  /// 20 min", que responde la pregunta real sin prometer un minuto exacto—; y
  /// `unknown` cuando la ruta no tiene servicio o el último reporte ya venció.
  /// Quien decide si se pinta el número es `Arrival.showsNumericEta`, no esta
  /// función ni el widget.
  List<Arrival> _arrivalsAt(String stopId) {
    final Stop? stop = _dataset.stop(stopId);
    if (stop == null) {
      throw StateError('no existe la parada $stopId');
    }

    final DateTime now = _clock();
    final Set<String> servicesToday = _dataset.servicesOn(now);
    final Duration timeOfDay = Duration(
      hours: now.hour,
      minutes: now.minute,
      seconds: now.second,
    );

    // Qué rutas pasan por aquí, y con qué letrero.
    final Map<String, Trip> tripByRoute = <String, Trip>{};
    for (final String tripId in _dataset.tripsForStop(stopId)) {
      final Trip? trip = _dataset.trip(tripId);
      if (trip == null || !servicesToday.contains(trip.serviceId)) {
        continue;
      }
      tripByRoute.putIfAbsent(trip.routeId, () => trip);
    }

    final List<Arrival> arrivals = <Arrival>[];
    for (final MapEntry<String, Trip> entry in tripByRoute.entries) {
      final TransitRoute? route = _dataset.route(entry.key);
      if (route == null) {
        continue;
      }

      final List<VehiclePosition> vehicles = _simulator.positionsAt(
        now,
        routeId: entry.key,
      );

      ({VehiclePosition vehicle, Duration eta})? best;
      for (final VehiclePosition vehicle in vehicles) {
        final Duration? eta = _simulator.timeToStop(
          vehicle: vehicle,
          stopId: stopId,
          now: now,
        );
        if (eta == null) {
          continue;
        }
        if (best == null || eta < best.eta) {
          best = (vehicle: vehicle, eta: eta);
        }
      }

      final ({VehiclePosition vehicle, Duration eta})? closest = best;
      if (closest != null) {
        final Duration age = closest.vehicle.ageAt(now);
        final bool expired = Freshness.classify(age) == DataFreshness.unknown;
        arrivals.add(
          Arrival(
            routeId: route.id,
            routeShortName: route.shortName,
            headsign: entry.value.headsign,
            // Con el dato vencido no se manda un número que después haya que
            // esconder: el arribo dice que no sabe.
            eta: expired ? null : closest.eta,
            confidence: expired ? EtaConfidence.unknown : EtaConfidence.live,
            dataAge: age,
            vehicleId: closest.vehicle.vehicleId,
            occupancyStatus: closest.vehicle.occupancyStatus,
          ),
        );
        continue;
      }

      // Sin vehículo: queda la frecuencia. Media frecuencia es la espera
      // esperada de quien llega al azar a un paradero.
      final Frequency? frequency = _dataset.frequency(entry.value.id);
      final bool running = frequency != null && frequency.coversTime(timeOfDay);
      arrivals.add(
        Arrival(
          routeId: route.id,
          routeShortName: route.shortName,
          headsign: entry.value.headsign,
          eta: running
              ? Duration(seconds: frequency.headway.inSeconds ~/ 2)
              : null,
          confidence: running ? EtaConfidence.scheduled : EtaConfidence.unknown,
          // Un horario no envejece: su edad es cero, y por eso el chip lo
          // muestra sin advertencia de frescura.
          dataAge: Duration.zero,
        ),
      );
    }

    arrivals.sort((Arrival a, Arrival b) {
      final Duration first = a.eta ?? const Duration(days: 1);
      final Duration second = b.eta ?? const Duration(days: 1);
      return first.compareTo(second);
    });
    return arrivals;
  }

  // -- Las fallas -----------------------------------------------------------

  /// Envuelve toda lectura: latencia primero, error después, dato al final.
  Future<T> _call<T>(String what, T Function() body) async {
    final int span =
        _config.maxLatency.inMilliseconds - _config.minLatency.inMilliseconds;
    final Duration latency = Duration(
      milliseconds:
          _config.minLatency.inMilliseconds +
          (span <= 0 ? 0 : _faults.nextInt(span + 1)),
    );
    if (latency > Duration.zero) {
      await Future<void>.delayed(latency);
    }

    if (_faults.nextDouble() < _config.errorRate) {
      throw TransitDataException('no se pudieron cargar $what');
    }

    return body();
  }

  /// Un stream que emite ya y después a la cadencia de reporte.
  ///
  /// La primera emisión es inmediata a propósito: una pantalla que espera 30 s
  /// para mostrar algo está rota, aunque el dato sea correcto.
  Stream<T> _ticker<T>(T Function() read) async* {
    yield read();
    yield* Stream<void>.periodic(_config.reportInterval).map((_) => read());
  }
}

double _meters(LatLng a, LatLng b) {
  final double latMid = (a.latitude + b.latitude) / 2 * pi / 180;
  final double x = (b.longitude - a.longitude) * cos(latMid) * 111320;
  final double y = (b.latitude - a.latitude) * 110574;
  return sqrt(x * x + y * y);
}
