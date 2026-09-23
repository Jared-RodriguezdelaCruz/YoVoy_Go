import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/data/not_found.dart';
import 'core/perf/frame_stats.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FrameStats.start();
  runApp(
    const ProviderScope(
      // La regla de reintento va aquí y no provider por provider: la red
      // estática, los arribos y las alertas no la declaraban, y con ellas
      // colgadas la pantalla se quedaba 38 s en esqueleto sin decir nada.
      retry: retryUnlessNotFound,
      child: YoVoyGoApp(),
    ),
  );
}
