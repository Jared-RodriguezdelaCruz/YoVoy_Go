import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'clock_provider.g.dart';

/// El reloj de la app.
///
/// Todo lo que pregunta "qué hora es" para calcular una edad, una posición o
/// un "sal en 6 min" pregunta aquí y no a `DateTime.now()` directo. Así un test
/// puede fijar la hora, y una imagen de referencia del mapa sale igual cada
/// vez que se genera.
@Riverpod(keepAlive: true)
DateTime Function() clock(Ref ref) => DateTime.now;
