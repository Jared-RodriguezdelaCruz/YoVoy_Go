import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_lifecycle_provider.g.dart';

/// El estado de la app: en pantalla, en segundo plano, cerrándose.
///
/// Existe por la regla 8 de la sección 7 del spec: **con la app en segundo
/// plano no se sondea nada.** Los providers de tiempo real lo miran y sueltan
/// sus streams cuando la app deja de verse.
@Riverpod(keepAlive: true)
class AppLifecycle extends _$AppLifecycle {
  @override
  AppLifecycleState build() {
    final AppLifecycleListener listener = AppLifecycleListener(
      onStateChange: set,
    );
    ref.onDispose(listener.dispose);
    return WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
  }

  /// Lo llama el listener. Público para poder simularlo en tests.
  void set(AppLifecycleState next) => state = next;
}

/// Si la app está a la vista. `inactive` cuenta como visible: es el instante
/// en que baja la cortina de notificaciones, y cortar el stream ahí haría
/// parpadear el mapa.
@Riverpod(keepAlive: true)
bool appInForeground(Ref ref) {
  final AppLifecycleState state = ref.watch(appLifecycleProvider);
  return state == AppLifecycleState.resumed ||
      state == AppLifecycleState.inactive;
}
