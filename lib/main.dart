import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/perf/frame_stats.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FrameStats.start();
  runApp(const ProviderScope(child: YoVoyGoApp()));
}
