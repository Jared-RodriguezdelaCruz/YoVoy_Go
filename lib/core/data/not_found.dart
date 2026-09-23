import 'package:riverpod_annotation/riverpod_annotation.dart';

/// Se pidió algo que la red no tiene: un enlace viejo o mal escrito.
///
/// Es distinto de "el servicio no respondió": reintentar no lo arregla, y la
/// pantalla lo dice de otra forma.
abstract class NotFound implements Exception {
  const NotFound(this.id);

  final String id;

  @override
  String toString() => '$runtimeType($id)';
}

/// Cuántas veces se reintenta solo antes de decírselo al usuario.
///
/// Riverpod reintenta diez veces por default, con espera creciente hasta 6.4 s:
/// **38 segundos de esqueleto** antes de que la pantalla diga nada. Se vio en
/// la fase 9, revisando los cuatro estados con el simulador fallando el 100 %
/// de las llamadas: el estado de error existía desde la fase 6 y era
/// inalcanzable en la práctica.
///
/// Tres intentos son 1.4 s más la latencia. Pasados esos, reintentar deja de
/// ser trabajo de la app y pasa a ser una decisión del usuario, que para eso
/// tiene el botón (§9 del spec: qué falló, en su idioma, con reintentar).
const int maxAutoRetries = 3;

/// La regla de reintento de toda la app, menos para [NotFound]: pedir tres
/// veces una parada que no existe solo retrasa el "no existe".
///
/// Se instala en el `ProviderScope` (`main.dart`), así que la siguen **todos**
/// los providers, no solo los que la nombran.
Duration? retryUnlessNotFound(int retryCount, Object error) => error is NotFound
    ? null
    : ProviderContainer.defaultRetry(
        retryCount,
        error,
        maxRetries: maxAutoRetries,
      );
