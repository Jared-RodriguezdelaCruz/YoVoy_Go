/// Los componentes compartidos de la sección 6.6 del spec, en un solo import.
///
/// Se construyen antes que cualquier pantalla: si cada pantalla inventa su
/// forma de pintar un ETA, la app deja de tener un vocabulario.
library;

export 'alert_banner.dart';
export 'empty_state.dart';
export 'error_state.dart';
export 'eta_chip.dart';
export 'freshness_indicator.dart';
export 'lit_surface.dart';
export 'notice_banner.dart';
export 'occupancy_indicator.dart';
export 'offline_banner.dart';
export 'reliability_note.dart';
export 'route_badge.dart';
export 'route_line.dart';
export 'route_sequence.dart';
export 'route_strip.dart';
export 'schedule_note.dart';
export 'skeleton.dart';
export 'stop_tile.dart';
export 'vehicle_marker.dart';
