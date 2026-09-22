import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

part 'screen_awake.g.dart';

/// Mantener la pantalla encendida, y soltarla.
///
/// Solo lo usa el modo paradero: quien espera el camión con el teléfono en la
/// mano no debería tener que tocarlo cada treinta segundos para que no se
/// apague. La interfaz existe para que los tests no toquen el canal de la
/// plataforma.
abstract interface class ScreenAwake {
  Future<void> keepOn();

  Future<void> release();
}

/// La implementación real, con `wakelock_plus`.
final class WakelockScreenAwake implements ScreenAwake {
  const WakelockScreenAwake();

  @override
  Future<void> keepOn() => WakelockPlus.enable();

  @override
  Future<void> release() => WakelockPlus.disable();
}

/// Para tests: recuerda si la pantalla quedó encendida.
final class FakeScreenAwake implements ScreenAwake {
  bool on = false;

  @override
  Future<void> keepOn() async => on = true;

  @override
  Future<void> release() async => on = false;
}

@Riverpod(keepAlive: true)
ScreenAwake screenAwake(Ref ref) => const WakelockScreenAwake();
