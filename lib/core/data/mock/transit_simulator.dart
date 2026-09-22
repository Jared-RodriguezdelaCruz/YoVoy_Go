import 'dart:math';

import 'package:latlong2/latlong.dart';

import '../../models/models.dart';
import 'mock_dataset.dart';
import 'simulator_config.dart';

/// Un sistema de transporte que se mueve, **con sus fallas**.
///
/// La sección 4.2 del spec es explícita: un mock de datos perfectos hace que
/// diseñes una UI que se rompe en producción. Así que aquí los camiones se
/// atrasan, el GPS miente unos metros, algunos desaparecen minutos enteros y
/// hay reportes sin `bearing`.
///
/// **Es determinista.** La posición de un vehículo es una función pura del
/// reloj: `positionsAt(t)` con la misma semilla y el mismo `t` da siempre lo
/// mismo. No hay estado acumulado que se desincronice, y un test puede
/// afirmar una coordenada exacta.
class TransitSimulator {
  TransitSimulator({
    required this.dataset,
    this.config = const SimulatorConfig(),
    DateTime? epoch,
    // El ancla del tiempo: todo se calcula como desplazamiento desde aquí, y
    // no desde "cuando arrancó la app".
  }) : epoch = epoch ?? DateTime.utc(2026, 1, 1) {
    _build();
  }

  /// El dataset sobre el que se mueve la flota.
  final MockDataset dataset;
  final SimulatorConfig config;
  final DateTime epoch;

  final List<_SimVehicle> _vehicles = <_SimVehicle>[];
  final Map<String, _Track> _tracks = <String, _Track>{};

  /// Todos los vehículos de la flota, tengan señal o no.
  int get fleetSize => _vehicles.length;

  /// Las rutas que el dataset dejó sin servicio a propósito.
  List<String> get routesWithoutService => <String>[
    for (final RouteService row in dataset.service)
      if (!row.active) row.routeId,
  ];

  void _build() {
    final Random random = Random(config.seed);

    for (final RouteService row in dataset.service) {
      if (!row.active || row.vehicles == 0) {
        continue;
      }

      // Se reparten entre los viajes de ida y vuelta: una ruta con servicio
      // tiene camiones en los dos sentidos, no todos en fila hacia el centro.
      final List<Trip> trips =
          dataset
              .tripsForRoute(row.routeId)
              .where((Trip trip) => trip.serviceId == 'ES')
              .toList(growable: false)
            ..sort((Trip a, Trip b) => a.id.compareTo(b.id));
      if (trips.isEmpty) {
        continue;
      }

      for (int i = 0; i < row.vehicles; i++) {
        final Trip trip = trips[i % trips.length];
        final _Track? track = _trackFor(trip);
        if (track == null || track.totalSeconds <= 0) {
          continue;
        }

        final double speedKmh =
            config.minSpeedKmh +
            random.nextDouble() * (config.maxSpeedKmh - config.minSpeedKmh);

        // Salidas escalonadas por el intervalo real de la ruta: es lo que hace
        // que se vean repartidos sobre el trazo y no amontonados.
        final double offset =
            (i ~/ trips.length) * row.headway.inSeconds.toDouble();

        _vehicles.add(
          _SimVehicle(
            id: '${row.routeId}-${(i + 1).toString().padLeft(2, '0')}',
            trip: trip,
            track: track,
            speedFactor: speedKmh / 30, // el track se arma a 30 km/h
            startOffsetSeconds: offset,
            losesSignal: random.nextDouble() < config.signalLossRate,
            signalSeed: random.nextInt(1 << 30),
          ),
        );
      }
    }
  }

  /// Arma —y cachea— la línea de tiempo de un viaje sobre su trazo.
  _Track? _trackFor(Trip trip) {
    final String? shapeId = trip.shapeId;
    if (shapeId == null) {
      return null;
    }
    final _Track? cached = _tracks[shapeId];
    if (cached != null) {
      return cached;
    }

    final Shape? shape = dataset.shape(shapeId);
    if (shape == null || shape.points.length < 2) {
      return null;
    }

    final List<StopTime> times = dataset.stopTimesForTrip(trip.id);
    final List<Stop> stops = <Stop>[
      for (final StopTime time in times)
        if (dataset.stop(time.stopId) case final Stop stop) stop,
    ];

    final _Track track = _Track.build(
      points: shape.points,
      stops: stops,
      dwellSeconds: (config.minDwell.inSeconds + config.maxDwell.inSeconds) / 2,
    );
    _tracks[shapeId] = track;
    return track;
  }

  /// Las posiciones tal como las reportaría el sistema en [now].
  ///
  /// El reloj se redondea hacia abajo a la cadencia de reporte: entre un
  /// reporte y el siguiente la posición **no cambia**, y el `dataAge` crece.
  /// Es lo que obliga a la UI a interpolar y lo que hace visible la frescura.
  List<VehiclePosition> positionsAt(DateTime now, {String? routeId}) {
    final DateTime reportedAt = lastReportBefore(now);
    final double elapsed = reportedAt.difference(epoch).inMilliseconds / 1000.0;

    final List<VehiclePosition> positions = <VehiclePosition>[];
    for (final _SimVehicle vehicle in _vehicles) {
      if (routeId != null && vehicle.trip.routeId != routeId) {
        continue;
      }
      if (_hasLostSignal(vehicle, elapsed)) {
        // Desaparece del feed. Cuando vuelva va a estar más adelante, porque
        // la posición es función del reloj y el mundo siguió andando.
        continue;
      }

      final double seconds =
          (elapsed * vehicle.speedFactor + vehicle.startOffsetSeconds) %
          vehicle.track.totalSeconds;
      final _TrackSample sample = vehicle.track.sampleAt(seconds);

      final Random noise = Random(
        _stableHash(vehicle.id, reportedAt.millisecondsSinceEpoch, 0),
      );

      positions.add(
        VehiclePosition(
          vehicleId: vehicle.id,
          tripId: vehicle.trip.id,
          routeId: vehicle.trip.routeId,
          position: _withNoise(sample, noise),
          timestamp: reportedAt,
          bearing: noise.nextDouble() < config.missingBearingRate
              ? null
              : sample.bearing,
          speed: sample.moving ? 30 * vehicle.speedFactor / 3.6 : 0,
          currentStopSequence: sample.stopIndex + 1,
          occupancyStatus: _occupancy(vehicle, reportedAt),
        ),
      );
    }
    return positions;
  }

  /// Una semilla que da lo mismo en cada corrida.
  ///
  /// `Object.hash` no sirve aquí: Dart lo siembra al azar en cada proceso, y
  /// la promesa de este simulador es que `positionsAt(t)` sea igual siempre.
  /// Es FNV-1a de 32 bits sobre el id, el instante y un canal, que separa los
  /// dados de ruido de los de ocupación.
  static int _stableHash(String id, int millis, int channel) {
    int hash = 0x811c9dc5;
    void mix(int byte) {
      hash = ((hash ^ (byte & 0xff)) * 0x01000193) & 0xffffffff;
    }

    for (final int unit in id.codeUnits) {
      mix(unit);
      mix(unit >> 8);
    }
    for (int shift = 0; shift < 64; shift += 8) {
      mix(millis >> shift);
    }
    mix(channel);
    return hash;
  }

  /// Qué tan lleno va un vehículo en un reporte.
  ///
  /// Sale de su propio generador y no de `noise`: sacar un número más de ese
  /// movería el ruido de posición y el `bearing` de toda la flota. En horas
  /// pico la moneda se carga hacia lleno.
  OccupancyStatus? _occupancy(_SimVehicle vehicle, DateTime reportedAt) {
    final Random dice = Random(
      _stableHash(vehicle.id, reportedAt.millisecondsSinceEpoch, 1),
    );
    if (dice.nextDouble() < config.missingOccupancyRate) {
      return null;
    }
    final int hour = reportedAt.toLocal().hour;
    final bool rush =
        (hour >= 7 && hour < 9) ||
        (hour >= 13 && hour < 15) ||
        (hour >= 18 && hour < 20);
    // De 0 (vacío) a 1 (lleno). En pico, uno de cada cuatro va lleno; fuera
    // de pico, ninguno. Una lista donde todos van llenos no informa nada.
    final double load = rush
        ? 0.2 + dice.nextDouble() * 0.8
        : dice.nextDouble() * 0.8;
    return switch (load) {
      < 0.25 => OccupancyStatus.empty,
      < 0.45 => OccupancyStatus.manySeatsAvailable,
      < 0.65 => OccupancyStatus.fewSeatsAvailable,
      < 0.8 => OccupancyStatus.standingRoomOnly,
      < 0.93 => OccupancyStatus.crushedStandingRoomOnly,
      _ => OccupancyStatus.full,
    };
  }

  /// El instante del último reporte antes de [now].
  DateTime lastReportBefore(DateTime now) {
    final int interval = config.reportInterval.inMilliseconds;
    if (interval <= 0) {
      return now.toUtc();
    }
    final int since = now.toUtc().difference(epoch).inMilliseconds;
    return epoch.add(Duration(milliseconds: (since ~/ interval) * interval));
  }

  /// Cuánto le falta a un vehículo para llegar a una parada, o `null` si ya
  /// pasó por ella en esta vuelta.
  Duration? timeToStop({
    required VehiclePosition vehicle,
    required String stopId,
    required DateTime now,
  }) {
    final _SimVehicle? sim = _vehicles
        .where((_SimVehicle v) => v.id == vehicle.vehicleId)
        .firstOrNull;
    if (sim == null) {
      return null;
    }

    final int stopIndex = sim.track.indexOfStop(stopId);
    if (stopIndex < 0) {
      return null;
    }

    final double elapsed =
        lastReportBefore(now).difference(epoch).inMilliseconds / 1000.0;
    final double seconds =
        (elapsed * sim.speedFactor + sim.startOffsetSeconds) %
        sim.track.totalSeconds;
    final double arrival = sim.track.arrivalSecondsAt(stopIndex);

    if (arrival < seconds) {
      // Ya pasó: el siguiente paso es hasta la vuelta que viene.
      return Duration(
        seconds:
            ((sim.track.totalSeconds - seconds + arrival) / sim.speedFactor)
                .round(),
      );
    }
    return Duration(seconds: ((arrival - seconds) / sim.speedFactor).round());
  }

  bool _hasLostSignal(_SimVehicle vehicle, double elapsed) {
    if (!vehicle.losesSignal || config.signalLossRate <= 0) {
      return false;
    }
    // Ventanas de silencio repetidas, deterministas por vehículo: cada 12
    // minutos se juega si desaparece y por cuánto.
    const double window = 720;
    final int slot = (elapsed / window).floor();
    final Random random = Random(vehicle.signalSeed ^ slot);
    if (random.nextDouble() > 0.5) {
      return false;
    }

    final double start = random.nextDouble() * window;
    final double length =
        config.minSignalLoss.inSeconds +
        random.nextDouble() *
            (config.maxSignalLoss.inSeconds - config.minSignalLoss.inSeconds);
    final double offset = elapsed - slot * window;
    return offset >= start && offset < start + length;
  }

  LatLng _withNoise(_TrackSample sample, Random random) {
    final double range = config.gpsNoiseMaxMeters - config.gpsNoiseMinMeters;
    if (config.gpsNoiseMaxMeters <= 0) {
      return sample.position;
    }

    // Perpendicular al trazo, que es como miente un GPS urbano: el error te
    // saca del carril, no te adelanta media cuadra.
    final double meters =
        (config.gpsNoiseMinMeters + random.nextDouble() * range) *
        (random.nextBool() ? 1 : -1);
    final double heading = (sample.bearing + 90) * pi / 180;
    final double dLat = meters * cos(heading) / 110574;
    final double dLon =
        meters *
        sin(heading) /
        (111320 * cos(sample.position.latitude * pi / 180));

    return LatLng(
      sample.position.latitude + dLat,
      sample.position.longitude + dLon,
    );
  }
}

/// Un vehículo del simulador: su viaje, su trazo y sus manías.
class _SimVehicle {
  _SimVehicle({
    required this.id,
    required this.trip,
    required this.track,
    required this.speedFactor,
    required this.startOffsetSeconds,
    required this.losesSignal,
    required this.signalSeed,
  });

  final String id;
  final Trip trip;
  final _Track track;

  /// Qué tan rápido va respecto a los 30 km/h con los que se armó el trazo.
  final double speedFactor;

  final double startOffsetSeconds;
  final bool losesSignal;
  final int signalSeed;
}

/// Una muestra del trazo: dónde está, hacia dónde mira y si va andando.
class _TrackSample {
  const _TrackSample({
    required this.position,
    required this.bearing,
    required this.moving,
    required this.stopIndex,
  });

  final LatLng position;
  final double bearing;
  final bool moving;
  final int stopIndex;
}

/// El trazo de un viaje convertido en línea de tiempo.
///
/// Se recorre a 30 km/h de referencia, con una espera en cada parada; cada
/// vehículo le aplica encima su propio factor de velocidad. Así el trazo se
/// arma una vez por `shape` y no una vez por camión: son 92 trazos para 323
/// vehículos.
class _Track {
  _Track._({
    required this.points,
    required this.cumulative,
    required this.stopDistances,
    required this.stopIds,
    required this.timeline,
    required this.totalSeconds,
  });

  factory _Track.build({
    required List<LatLng> points,
    required List<Stop> stops,
    required double dwellSeconds,
  }) {
    final List<double> cumulative = <double>[0];
    for (int i = 1; i < points.length; i++) {
      cumulative.add(cumulative[i - 1] + _meters(points[i - 1], points[i]));
    }

    // Cada parada se proyecta al punto más cercano del trazo: es lo que
    // permite saber cuándo un camión "llega" a ella sin inventar horarios.
    final List<double> stopDistances = <double>[];
    final List<String> stopIds = <String>[];
    for (final Stop stop in stops) {
      double best = double.infinity;
      int bestIndex = 0;
      for (int i = 0; i < points.length; i++) {
        final double d = _meters(points[i], stop.position);
        if (d < best) {
          best = d;
          bestIndex = i;
        }
      }
      final double distance = cumulative[bestIndex];
      // El orden del trazo manda: una parada que "retrocede" es ruido de la
      // proyección, no una vuelta en U.
      if (stopDistances.isEmpty || distance > stopDistances.last) {
        stopDistances.add(distance);
        stopIds.add(stop.id);
      }
    }

    const double referenceSpeed = 30 / 3.6; // m/s
    final List<double> timeline = <double>[];
    double seconds = 0;
    int nextStop = 0;
    for (int i = 0; i < points.length; i++) {
      if (i > 0) {
        seconds += (cumulative[i] - cumulative[i - 1]) / referenceSpeed;
      }
      while (nextStop < stopDistances.length &&
          stopDistances[nextStop] <= cumulative[i]) {
        seconds += dwellSeconds;
        nextStop++;
      }
      timeline.add(seconds);
    }

    return _Track._(
      points: points,
      cumulative: cumulative,
      stopDistances: stopDistances,
      stopIds: stopIds,
      timeline: timeline,
      totalSeconds: seconds <= 0 ? 1 : seconds,
    );
  }

  final List<LatLng> points;
  final List<double> cumulative;
  final List<double> stopDistances;
  final List<String> stopIds;

  /// Segundo en que el vehículo de referencia alcanza cada punto del trazo.
  final List<double> timeline;

  final double totalSeconds;

  _TrackSample sampleAt(double seconds) {
    int low = 0;
    int high = timeline.length - 1;
    while (low < high) {
      final int mid = (low + high) ~/ 2;
      if (timeline[mid] < seconds) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    final int index = low.clamp(1, points.length - 1);

    final double previous = timeline[index - 1];
    final double span = timeline[index] - previous;
    // Un span mucho mayor que el tramo significa que ahí hay una parada: el
    // vehículo está detenido, no avanzando lentísimo.
    final double t = span <= 0 ? 0 : ((seconds - previous) / span).clamp(0, 1);

    final LatLng from = points[index - 1];
    final LatLng to = points[index];
    final LatLng position = LatLng(
      from.latitude + (to.latitude - from.latitude) * t,
      from.longitude + (to.longitude - from.longitude) * t,
    );

    int stopIndex = 0;
    for (int i = 0; i < stopDistances.length; i++) {
      if (stopDistances[i] <= cumulative[index]) {
        stopIndex = i;
      }
    }

    return _TrackSample(
      position: position,
      bearing: _bearing(from, to),
      moving: span < 12,
      stopIndex: stopIndex,
    );
  }

  int indexOfStop(String stopId) => stopIds.indexOf(stopId);

  double arrivalSecondsAt(int stopIndex) {
    final double distance = stopDistances[stopIndex];
    for (int i = 0; i < cumulative.length; i++) {
      if (cumulative[i] >= distance) {
        return timeline[i];
      }
    }
    return totalSeconds;
  }
}

double _meters(LatLng a, LatLng b) {
  final double latMid = (a.latitude + b.latitude) / 2 * pi / 180;
  final double x = (b.longitude - a.longitude) * cos(latMid) * 111320;
  final double y = (b.latitude - a.latitude) * 110574;
  return sqrt(x * x + y * y);
}

double _bearing(LatLng from, LatLng to) {
  final double dLon = (to.longitude - from.longitude) * pi / 180;
  final double lat1 = from.latitude * pi / 180;
  final double lat2 = to.latitude * pi / 180;
  final double y = sin(dLon) * cos(lat2);
  final double x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
  return (atan2(y, x) * 180 / pi + 360) % 360;
}
