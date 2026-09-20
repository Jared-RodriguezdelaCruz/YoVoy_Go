import 'package:flutter/widgets.dart';

/// Motion de la app, como en la sección 6.5 del spec.
///
/// La expresividad se gasta en el tiempo real y en nada más: el vehículo y el
/// contador de ETA se mueven; el resto está quieto. Motion en cada card cuesta
/// frames y además es el default genérico.
abstract final class AppMotion {
  /// Para todo lo que se mueve por acción del usuario.
  static const Duration standard = Duration(milliseconds: 200);

  /// Cambio del número de ETA: slide vertical corto. Único movimiento que no
  /// dispara el usuario.
  static const Duration eta = Duration(milliseconds: 150);

  /// Pulso del indicador en vivo. **Uno solo por pantalla**, en el chip de
  /// frescura global, nunca uno por fila de la lista.
  static const Duration pulse = Duration(seconds: 2);

  static const Curve curve = Curves.easeOutCubic;

  /// La duración que corresponde según la preferencia de accesibilidad.
  ///
  /// Si el sistema pide reducir movimiento, todo lo anterior se vuelve
  /// transición instantánea. Ningún widget decide esto por su cuenta: todos
  /// pasan por aquí.
  static Duration resolve(BuildContext context, Duration duration) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;

  /// Si las animaciones continuas —el pulso— deben correr.
  static bool allowsLooping(BuildContext context) =>
      !MediaQuery.disableAnimationsOf(context);
}
