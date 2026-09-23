import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart' as plugin;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connectivity.g.dart';

/// Si el teléfono tiene alguna interfaz de red.
enum NetworkStatus {
  online,
  offline;

  bool get isOffline => this == NetworkStatus.offline;
}

/// Vigila la conexión.
///
/// **Lo que esto sabe y lo que no.** `connectivity_plus` reporta la *interfaz*
/// —wifi, datos, ethernet—, no que haya internet del otro lado: un wifi de
/// cafetería sin salida se reporta como conectado. Por eso la app solo dice
/// "sin conexión" cuando no hay **ninguna** interfaz, que es lo único que este
/// paquete puede afirmar, y el texto de la franja no promete más que eso.
/// Averiguar si de verdad hay internet exigiría pegarle a un servidor, y esta
/// app no tiene ninguno.
///
/// La interfaz existe para que los tests no toquen el canal de la plataforma,
/// igual que [ScreenAwake] y [LocationService].
abstract interface class ConnectivityMonitor {
  /// El estado actual y cada cambio. La primera emisión es inmediata.
  Stream<NetworkStatus> watch();
}

/// La implementación real, con `connectivity_plus`.
final class PluginConnectivityMonitor implements ConnectivityMonitor {
  const PluginConnectivityMonitor();

  static NetworkStatus statusOf(List<plugin.ConnectivityResult> results) =>
      results.isEmpty ||
          results.every(
            (plugin.ConnectivityResult r) =>
                r == plugin.ConnectivityResult.none,
          )
      ? NetworkStatus.offline
      : NetworkStatus.online;

  @override
  Stream<NetworkStatus> watch() async* {
    final plugin.Connectivity connectivity = plugin.Connectivity();
    // El stream del paquete solo emite cuando algo cambia. Sin esta primera
    // lectura, un teléfono que arranca sin datos se vería conectado hasta que
    // alguien encendiera el wifi.
    yield statusOf(await connectivity.checkConnectivity());
    yield* connectivity.onConnectivityChanged.map(statusOf);
  }
}

/// Para tests: el estado que el test decida, y los cambios que empuje.
final class FakeConnectivityMonitor implements ConnectivityMonitor {
  FakeConnectivityMonitor([NetworkStatus initial = NetworkStatus.online])
    : _status = initial;

  NetworkStatus _status;
  final StreamController<NetworkStatus> _changes =
      StreamController<NetworkStatus>.broadcast();

  /// Simula que la red se fue o volvió.
  void set(NetworkStatus status) {
    _status = status;
    _changes.add(status);
  }

  @override
  Stream<NetworkStatus> watch() async* {
    yield _status;
    yield* _changes.stream;
  }
}

@Riverpod(keepAlive: true)
ConnectivityMonitor connectivityMonitor(Ref ref) =>
    const PluginConnectivityMonitor();

/// El estado de la red, para quien quiera pintarlo.
///
/// `keepAlive` a propósito: es una sola suscripción para toda la app, y
/// soltarla y rearmarla cada vez que se abre una pantalla costaría más que
/// mantenerla.
@Riverpod(keepAlive: true)
Stream<NetworkStatus> networkStatus(Ref ref) =>
    ref.watch(connectivityMonitorProvider).watch();
