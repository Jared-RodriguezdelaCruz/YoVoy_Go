import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/route_palette.dart';

/// El camión sobre el mapa.
///
/// Con `bearing` apunta hacia donde va; sin él **degrada a círculo**, no a una
/// flecha apuntando al norte. El `bearing` falta en buena parte de los
/// reportes reales, y una flecha que miente es peor que un punto honesto.
class VehicleMarker extends StatelessWidget {
  const VehicleMarker({
    required this.color,
    this.bearing,
    this.size = 28,
    this.isStale = false,
    super.key,
  });

  /// Color de la ruta a la que pertenece el vehículo.
  final Color color;

  /// Grados, 0 = norte. Nulo con frecuencia.
  final double? bearing;

  final double size;

  /// Con dato viejo el marcador se apaga: mismo lugar, menos peso visual.
  final bool isStale;

  /// La geometría del marcador, sin widget.
  ///
  /// La capa del mapa dibuja toda la flota con un solo `CustomPainter` (un
  /// widget por camión cuesta frames con 40 en pantalla), y llama aquí para
  /// que el camión del mapa y el de la galería sean exactamente el mismo.
  static void paintMarker(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color color,
    required Color haloColor,
    required Color contentColor,
    double? bearing,
  }) {
    // Halo: mantiene el marcador visible sobre cualquier tile.
    canvas
      ..drawCircle(center, radius, Paint()..color = haloColor)
      ..drawCircle(center, radius - 2, Paint()..color = color);

    final double? heading = bearing;
    if (heading == null) {
      // Sin dirección: un punto sólido. No se inventa hacia dónde va.
      canvas.drawCircle(center, radius * 0.28, Paint()..color = contentColor);
      return;
    }

    // Con dirección: un triángulo apuntando al rumbo reportado.
    final double angle = (heading - 90) * math.pi / 180;
    final double tip = radius * 0.62;
    final double back = radius * 0.42;

    Offset at(double distance, double offsetAngle) =>
        center +
        Offset(
          math.cos(angle + offsetAngle) * distance,
          math.sin(angle + offsetAngle) * distance,
        );

    final Path arrow = Path()
      ..moveTo(at(tip, 0).dx, at(tip, 0).dy)
      ..lineTo(at(back, 2.5).dx, at(back, 2.5).dy)
      ..lineTo(at(back * 0.45, math.pi).dx, at(back * 0.45, math.pi).dy)
      ..lineTo(at(back, -2.5).dx, at(back, -2.5).dy)
      ..close();

    canvas.drawPath(arrow, Paint()..color = contentColor);
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return Semantics(
      label: bearing == null
          ? 'Camión, sin dirección conocida'
          : 'Camión en movimiento',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _VehicleMarkerPainter(
            color: isStale ? color.withValues(alpha: 0.55) : color,
            haloColor: colors.surface,
            contentColor: RoutePalette.onColor(color),
            bearing: bearing,
          ),
        ),
      ),
    );
  }
}

class _VehicleMarkerPainter extends CustomPainter {
  const _VehicleMarkerPainter({
    required this.color,
    required this.haloColor,
    required this.contentColor,
    required this.bearing,
  });

  final Color color;
  final Color haloColor;
  final Color contentColor;
  final double? bearing;

  @override
  void paint(Canvas canvas, Size size) => VehicleMarker.paintMarker(
    canvas,
    center: size.center(Offset.zero),
    radius: size.shortestSide / 2,
    color: color,
    haloColor: haloColor,
    contentColor: contentColor,
    bearing: bearing,
  );

  @override
  bool shouldRepaint(_VehicleMarkerPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.haloColor != haloColor ||
      oldDelegate.contentColor != contentColor ||
      oldDelegate.bearing != bearing;
}
