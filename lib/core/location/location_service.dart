import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'location_service.g.dart';

/// Plaza de la Patria: el centro de Aguascalientes, y adonde se va el mapa
/// cuando no hay ubicación.
const LatLng aguascalientesCenter = LatLng(21.8818, -102.2960);

/// Por qué no hay ubicación. El botón lo dice en lugar de fallar en silencio.
enum LocationIssue {
  /// El GPS del teléfono está apagado.
  serviceDisabled,

  /// El usuario dijo que no, por ahora.
  denied,

  /// El usuario dijo que no para siempre: solo se cambia en ajustes.
  deniedForever,

  /// Había permiso, pero el teléfono no respondió a tiempo.
  unavailable,
}

/// Dónde está el usuario, o dónde suponemos que está.
@immutable
class UserLocation {
  const UserLocation({required this.position, this.issue});

  const UserLocation.fallback(LocationIssue this.issue)
    : position = aguascalientesCenter;

  final LatLng position;

  /// `null` cuando la posición es real.
  final LocationIssue? issue;

  /// La posición es el centro de la ciudad, no el usuario.
  bool get isFallback => issue != null;
}

/// De dónde sale la ubicación. Detrás de una interfaz para que los tests no
/// toquen el GPS.
abstract interface class LocationService {
  Future<UserLocation> current();

  /// Abre los ajustes que resuelven [issue]: los de ubicación del teléfono si
  /// el GPS está apagado, los de la app si el permiso quedó bloqueado.
  Future<void> openSettings(LocationIssue issue);
}

/// La ubicación real, con `geolocator`.
///
/// Solo pide el permiso "mientras se usa la app". Nada corre en segundo plano:
/// una app de transporte no tiene por qué saber dónde estás cuando no la
/// estás viendo.
class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  @override
  Future<void> openSettings(LocationIssue issue) async {
    if (issue == LocationIssue.serviceDisabled) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }

  @override
  Future<UserLocation> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const UserLocation.fallback(LocationIssue.serviceDisabled);
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    switch (permission) {
      case LocationPermission.denied:
        return const UserLocation.fallback(LocationIssue.denied);
      case LocationPermission.deniedForever:
        return const UserLocation.fallback(LocationIssue.deniedForever);
      case LocationPermission.whileInUse:
      case LocationPermission.always:
      case LocationPermission.unableToDetermine:
        break;
    }

    try {
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          timeLimit: Duration(seconds: 10),
        ),
      );
      return UserLocation(
        position: LatLng(position.latitude, position.longitude),
      );
    } on Exception {
      // Bajo techo o con el GPS frío la primera lectura puede no llegar. La
      // última conocida sirve mejor que nada.
      final Position? last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        return UserLocation(position: LatLng(last.latitude, last.longitude));
      }
      return const UserLocation.fallback(LocationIssue.unavailable);
    }
  }
}

@Riverpod(keepAlive: true)
LocationService locationService(Ref ref) => const GeolocatorLocationService();

/// La ubicación del usuario. Se vuelve a pedir con `ref.invalidate`, que es lo
/// que hace el botón de "mi ubicación".
@Riverpod(keepAlive: true)
Future<UserLocation> userLocation(Ref ref) =>
    ref.watch(locationServiceProvider).current();
