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

/// La regla de reintento de Riverpod, menos para [NotFound]: pedir diez veces
/// una parada que no existe solo retrasa el "no existe".
Duration? retryUnlessNotFound(int retryCount, Object error) => error is NotFound
    ? null
    : ProviderContainer.defaultRetry(retryCount, error);
