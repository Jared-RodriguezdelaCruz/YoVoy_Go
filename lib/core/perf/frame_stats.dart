import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Cuenta cuadros y los resume en el log, para medir el presupuesto de la
/// sección 7 del spec: **60 fps con 40 vehículos visibles, nunca menos de 30**.
///
/// Solo se enciende a propósito, en un build de profile:
///
/// ```bash
/// flutter run --profile --dart-define=FRAME_STATS=true
/// adb logcat -s flutter | grep "\[cuadros\]"
/// ```
///
/// En debug los números no valen nada (el código corre sin compilar), y en
/// release nadie los lee.
abstract final class FrameStats {
  static const bool enabled = bool.fromEnvironment('FRAME_STATS');

  /// Un cuadro de 60 fps: 16.7 ms.
  static const Duration budget = Duration(microseconds: 16667);

  static final List<FrameTiming> _window = <FrameTiming>[];

  static void start({Duration every = const Duration(seconds: 10)}) {
    if (!enabled) {
      return;
    }
    DateTime last = DateTime.now();
    SchedulerBinding.instance.addTimingsCallback((List<FrameTiming> timings) {
      _window.addAll(timings);
      final DateTime now = DateTime.now();
      if (now.difference(last) < every || _window.isEmpty) {
        return;
      }
      debugPrint(summarize(_window, now.difference(last)));
      _window.clear();
      last = now;
    });
  }

  /// El resumen de una ventana de cuadros, en una línea.
  @visibleForTesting
  static String summarize(List<FrameTiming> frames, Duration span) {
    List<int> sorted(Duration Function(FrameTiming) of) =>
        frames.map((FrameTiming f) => of(f).inMicroseconds).toList()..sort();
    int p(List<int> values, double q) =>
        values[((values.length - 1) * q).round()];
    String ms(int micros) => (micros / 1000).toStringAsFixed(1);

    final List<int> build = sorted((FrameTiming f) => f.buildDuration);
    final List<int> raster = sorted((FrameTiming f) => f.rasterDuration);
    // Un cuadro se pasa cuando el hilo de UI **o** el de raster tardan más que
    // el presupuesto. El `totalSpan` no sirve para esto: incluye la espera
    // del vsync, y con él todo cuadro parece tarde.
    final List<int> worst = sorted(
      (FrameTiming f) => f.buildDuration > f.rasterDuration
          ? f.buildDuration
          : f.rasterDuration,
    );
    final int over = worst.where((int t) => t > budget.inMicroseconds).length;
    final double fps = frames.length / (span.inMilliseconds / 1000);

    return '[cuadros] ${frames.length} en ${span.inSeconds} s '
        '(${fps.toStringAsFixed(0)} fps) · '
        'build p50 ${ms(p(build, 0.5))} / p90 ${ms(p(build, 0.9))} ms · '
        'raster p50 ${ms(p(raster, 0.5))} / p90 ${ms(p(raster, 0.9))} ms · '
        'peor ${ms(worst.last)} ms · '
        '${(over * 100 / frames.length).toStringAsFixed(1)} % sobre 16.7 ms';
  }
}
