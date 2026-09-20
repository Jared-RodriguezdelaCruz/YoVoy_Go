import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../tokens/colors.dart';

/// El trazo de una ruta: el objeto gráfico protagonista de la app.
///
/// Grueso, saturado y con halo de contraste, como pide la sección 6.1 del
/// spec. El halo no es decoración: es lo que mantiene la línea legible cuando
/// cruza una calle clara del mapa.
///
/// Recibe puntos ya proyectados a coordenadas del widget. El amarre a
/// `flutter_map` llega en la fase 5; así el componente se puede ver y probar
/// sin mapa.
class RouteLine extends StatelessWidget {
  const RouteLine({
    required this.points,
    required this.color,
    this.zoom = 14,
    this.dashed = false,
    this.haloColor,
    super.key,
  });

  /// Puntos en coordenadas locales del widget.
  final List<Offset> points;

  final Color color;

  /// Nivel de zoom del mapa. De él sale el grosor.
  final double zoom;

  /// Los tramos a pie se dibujan punteados.
  final bool dashed;

  /// Por defecto, la superficie del tema activo.
  final Color? haloColor;

  /// Grosor del trazo según el zoom.
  ///
  /// Lejos, la línea se adelgaza para que el mapa no se convierta en una
  /// mancha; cerca, engorda para que se pueda seguir con el pulgar encima.
  static double strokeWidthForZoom(double zoom) {
    if (zoom <= 11) {
      return 3;
    }
    if (zoom >= 17) {
      return 9;
    }
    return 3 + (zoom - 11) * 1;
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RouteLinePainter(
        points: points,
        color: color,
        haloColor: haloColor ?? context.colors.surface,
        strokeWidth: strokeWidthForZoom(zoom),
        dashed: dashed,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _RouteLinePainter extends CustomPainter {
  const _RouteLinePainter({
    required this.points,
    required this.color,
    required this.haloColor,
    required this.strokeWidth,
    required this.dashed,
  });

  final List<Offset> points;
  final Color color;
  final Color haloColor;
  final double strokeWidth;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) {
      return;
    }

    final Path path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final Offset point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }

    final Path drawable = dashed ? _dash(path) : path;

    canvas
      ..drawPath(
        drawable,
        Paint()
          ..color = haloColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth + 4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      )
      ..drawPath(
        drawable,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
  }

  /// Convierte el trazo en guiones, para los tramos a pie.
  Path _dash(Path source) {
    const double dashLength = 6;
    const double gapLength = 6;
    final Path result = Path();

    for (final PathMetric metric in source.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final double next = (distance + dashLength).clamp(0, metric.length);
        result.addPath(metric.extractPath(distance, next), Offset.zero);
        distance = next + gapLength;
      }
    }
    return result;
  }

  @override
  bool shouldRepaint(_RouteLinePainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.color != color ||
      oldDelegate.haloColor != haloColor ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.dashed != dashed;
}
