import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/models.dart';

/// Un vehículo listo para dibujarse en un instante dado.
@immutable
class VehicleFrame {
  const VehicleFrame({
    required this.vehicle,
    required this.position,
    required this.age,
  });

  /// El último reporte que llegó de este vehículo.
  final VehiclePosition vehicle;

  /// Dónde se dibuja ahora: entre el reporte anterior y el último.
  final LatLng position;

  /// Qué tan viejo es [vehicle]. Crece mientras el vehículo no vuelva a
  /// reportar, y de él sale si el marcador se apaga.
  final Duration age;
}

/// Mueve los camiones entre reportes.
///
/// El feed llega cada 30 s y un marcador que se teletransporta se ve peor que
/// la app oficial (sección 7, regla 2). Esta clase guarda, por vehículo, desde
/// dónde viene y a dónde va, y responde dónde dibujarlo en cualquier instante.
/// No tiene reloj propio: quien la usa le pasa el tiempo del `Ticker`
/// compartido de la capa del mapa.
///
/// Dos reglas que no son obvias:
///
/// - **No extrapola.** Al terminar la ventana el vehículo se queda quieto en
///   su último punto conocido. Inventar hacia dónde siguió es mentir.
/// - **Un vehículo que desaparece no se borra.** Se queda en su último lugar y
///   su `age` sigue creciendo, para que la capa lo apague en vez de vaciar el
///   mapa (sección 9: el dato viejo se marca, no se borra). Solo se olvida
///   pasado [forgetAfter].
class VehicleInterpolator {
  VehicleInterpolator({
    this.window = const Duration(seconds: 30),
    this.jumpMeters = 1500,
    this.forgetAfter = const Duration(minutes: 10),
  });

  /// Lo que tarda un marcador en ir del reporte anterior al nuevo.
  final Duration window;

  /// Un salto más largo que esto no se anima: se dibuja directo en su lugar
  /// nuevo. Un camión deslizándose un kilómetro y medio sobre las casas en 30 s
  /// es peor que un salto honesto.
  final double jumpMeters;

  /// Cuánto tiempo sigue en el mapa un vehículo que dejó de reportar.
  final Duration forgetAfter;

  final Map<String, _Track> _tracks = <String, _Track>{};

  static const Distance _distance = Distance();

  int get length => _tracks.length;

  /// Recibe un lote nuevo del stream.
  ///
  /// [receivedAt] es el reloj local de cuando llegó, no el `timestamp` del
  /// reporte: la animación corre en el tiempo del teléfono.
  void update(List<VehiclePosition> batch, DateTime receivedAt) {
    final Set<String> present = <String>{};

    for (final VehiclePosition vehicle in batch) {
      present.add(vehicle.vehicleId);
      final _Track? previous = _tracks[vehicle.vehicleId];

      if (previous == null) {
        _tracks[vehicle.vehicleId] = _Track.still(vehicle, receivedAt);
        continue;
      }
      if (previous.vehicle.timestamp == vehicle.timestamp) {
        // El mismo reporte otra vez: no hay nada nuevo que animar.
        previous.missing = false;
        continue;
      }

      // Se arranca desde donde está dibujado ahora, no desde el reporte
      // anterior: si el lote llega a media animación no hay brinco hacia
      // atrás.
      final LatLng from = previous.positionAt(receivedAt, window);
      final bool jumps =
          previous.missing ||
          _distance.as(LengthUnit.Meter, from, vehicle.position) > jumpMeters;

      _tracks[vehicle.vehicleId] = jumps
          ? _Track.still(vehicle, receivedAt)
          : _Track(vehicle: vehicle, from: from, startedAt: receivedAt);
    }

    for (final MapEntry<String, _Track> entry in _tracks.entries) {
      if (!present.contains(entry.key)) {
        entry.value.missing = true;
      }
    }
    _tracks.removeWhere(
      (String id, _Track track) =>
          receivedAt.difference(track.vehicle.timestamp) > forgetAfter,
    );
  }

  /// Dónde va un vehículo en [now], o `null` si no se conoce.
  LatLng? positionOf(String vehicleId, DateTime now) =>
      _tracks[vehicleId]?.positionAt(now, window);

  /// El último reporte de un vehículo, si sigue en el mapa.
  VehiclePosition? vehicleOf(String vehicleId) => _tracks[vehicleId]?.vehicle;

  /// El reporte más reciente de toda la flota. De aquí sale el chip de
  /// frescura global: si hasta el más nuevo es viejo, el feed se detuvo.
  DateTime? get newestReport {
    DateTime? newest;
    for (final _Track track in _tracks.values) {
      final DateTime at = track.vehicle.timestamp;
      if (newest == null || at.isAfter(newest)) {
        newest = at;
      }
    }
    return newest;
  }

  /// Todos los vehículos en [now], con su posición y su edad.
  ///
  /// Con [interpolate] en `false` cada uno va directo a su último reporte: es
  /// lo que se usa cuando el sistema pide reducir el movimiento.
  List<VehicleFrame> frameAt(DateTime now, {bool interpolate = true}) =>
      <VehicleFrame>[
        for (final _Track track in _tracks.values)
          VehicleFrame(
            vehicle: track.vehicle,
            position: interpolate
                ? track.positionAt(now, window)
                : track.vehicle.position,
            age: track.vehicle.ageAt(now),
          ),
      ];
}

class _Track {
  _Track({required this.vehicle, required this.from, required this.startedAt});

  _Track.still(this.vehicle, this.startedAt) : from = vehicle.position;

  final VehiclePosition vehicle;
  final LatLng from;
  final DateTime startedAt;

  /// No vino en el último lote. Cuando vuelva, salta: el mundo siguió andando
  /// mientras no lo veíamos, y deslizarlo fingiría que lo vimos pasar.
  bool missing = false;

  LatLng positionAt(DateTime now, Duration window) {
    final int total = window.inMicroseconds;
    if (total <= 0) {
      return vehicle.position;
    }
    final double t = (now.difference(startedAt).inMicroseconds / total).clamp(
      0.0,
      1.0,
    );
    if (t >= 1) {
      return vehicle.position;
    }
    final LatLng to = vehicle.position;
    return LatLng(
      from.latitude + (to.latitude - from.latitude) * t,
      from.longitude + (to.longitude - from.longitude) * t,
    );
  }
}
