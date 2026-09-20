import 'package:flutter/material.dart';

import '../../core/config/freshness.dart';
import '../tokens/colors.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';
import 'freshness_indicator.dart';

/// La tira con luz de recorrido: la firma de la app.
///
/// La línea de la ruta con las paradas como marcas y el vehículo como bloque.
/// Carga la tesis entera del producto en un solo gráfico:
///
/// - **Lo recorrido va en `cantera`.** Es pasado, es tibio, es de donde vienes.
/// - **Lo que falta va en el índigo de marca.** Es sistema, es lo que promete.
/// - **El vehículo es la frontera**, con un halo encendido.
///
/// Y cuando el dato vence, **la luz se apaga**: se va el halo, el índigo se
/// vuelve gris y el trazo se puntea. La metáfora hace legible el estado sin
/// una palabra extra —pero el texto se queda igual, porque hay daltonismo y
/// hay sol directo, y el color nunca carga el significado solo.
class RouteStrip extends StatelessWidget {
  const RouteStrip({
    required this.stops,
    required this.vehicleProgress,
    required this.dataAge,
    this.height = 64,
    super.key,
  });

  /// Los nombres de las paradas en orden. Hacen falta al menos dos: una tira
  /// de una sola parada no es un recorrido.
  final List<String> stops;

  /// Dónde va el vehículo sobre la tira, de 0 a 1.
  final double vehicleProgress;

  /// Qué tan viejo es el reporte del vehículo. De aquí sale si la luz está
  /// encendida.
  final Duration dataAge;

  final double height;

  DataFreshness get _freshness => Freshness.classify(dataAge);

  @override
  Widget build(BuildContext context) {
    assert(stops.length >= 2, 'una tira necesita al menos dos paradas');

    final AppColors colors = context.colors;
    final DataFreshness freshness = _freshness;
    final bool lit = freshness != DataFreshness.unknown;
    final double progress = vehicleProgress.clamp(0.0, 1.0);

    return Semantics(
      label:
          'Recorrido de ${stops.first} a ${stops.last}. '
          '${lit ? 'Vehículo en camino' : 'Sin señal del vehículo'}, '
          '${FreshnessCopy.label(dataAge)}.',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            height: height - 20,
            width: double.infinity,
            child: CustomPaint(
              painter: _RouteStripPainter(
                stopCount: stops.length,
                progress: progress,
                past: colors.cantera,
                // Apagar la luz es cambiar de color, no bajarle la opacidad:
                // un índigo translúcido sobre el fondo sigue siendo índigo.
                ahead: lit ? colors.brand : colors.unknown,
                halo: freshness == DataFreshness.live
                    ? colors.live
                    : colors.stale,
                surface: colors.surface,
                lit: lit,
                dashed: !lit,
              ),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  stops.first,
                  style: AppTypography.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: Spacing.sm),
              // El estado va escrito, siempre. La tira lo dice con luz; esto
              // lo dice con palabras, y las dos cosas tienen que estar.
              Text(
                FreshnessCopy.label(dataAge),
                style: AppTypography.caption.copyWith(
                  color: FreshnessCopy.color(colors, freshness),
                ),
                maxLines: 1,
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(
                  stops.last,
                  textAlign: TextAlign.end,
                  style: AppTypography.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RouteStripPainter extends CustomPainter {
  const _RouteStripPainter({
    required this.stopCount,
    required this.progress,
    required this.past,
    required this.ahead,
    required this.halo,
    required this.surface,
    required this.lit,
    required this.dashed,
  });

  final int stopCount;
  final double progress;
  final Color past;
  final Color ahead;
  final Color halo;
  final Color surface;
  final bool lit;
  final bool dashed;

  static const double _line = 4;
  static const double _dot = 5;
  static const double _busWidth = 14;
  static const double _busHeight = 18;

  @override
  void paint(Canvas canvas, Size size) {
    final double y = size.height / 2;
    final double left = _busWidth;
    final double right = size.width - _busWidth;
    final double span = right - left;
    final double busX = left + span * progress;

    final Paint pastPaint = Paint()
      ..color = past
      ..strokeWidth = _line
      ..strokeCap = StrokeCap.round;

    final Paint aheadPaint = Paint()
      ..color = ahead
      ..strokeWidth = _line
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(left, y), Offset(busX, y), pastPaint);

    if (dashed) {
      // Sin dato, el trazo se puntea: lo que falta dejó de ser una promesa.
      const double dash = 6;
      const double gap = 5;
      double x = busX;
      while (x < right) {
        canvas.drawLine(
          Offset(x, y),
          Offset((x + dash).clamp(busX, right), y),
          aheadPaint,
        );
        x += dash + gap;
      }
    } else {
      canvas.drawLine(Offset(busX, y), Offset(right, y), aheadPaint);
    }

    // Las paradas: marcas del mismo color que el tramo en el que caen.
    for (int i = 0; i < stopCount; i++) {
      final double x = left + span * (i / (stopCount - 1));
      final bool passed = x <= busX;
      canvas
        ..drawCircle(Offset(x, y), _dot + 2, Paint()..color = surface)
        ..drawCircle(Offset(x, y), _dot, Paint()..color = passed ? past : ahead);
    }

    if (lit) {
      // El halo: la luz encendida del vehículo. Es lo primero que se va
      // cuando el dato vence.
      canvas.drawCircle(
        Offset(busX, y),
        _busHeight,
        Paint()..color = halo.withValues(alpha: 0.18),
      );
      canvas.drawCircle(
        Offset(busX, y),
        _busHeight * 0.66,
        Paint()..color = halo.withValues(alpha: 0.24),
      );
    }

    // El vehículo, rectangular como la señalética: no se redondea. Va del
    // color del sistema, no del estado: pintarlo del color de la frescura lo
    // convertiría en un cuadrito de estado más, y la luz que lo rodea ya dice
    // eso mejor.
    final Rect bus = Rect.fromCenter(
      center: Offset(busX, y),
      width: _busWidth,
      height: _busHeight,
    );
    canvas
      ..drawRect(bus.inflate(2), Paint()..color = surface)
      ..drawRect(bus, Paint()..color = ahead);
  }

  @override
  bool shouldRepaint(_RouteStripPainter old) =>
      old.progress != progress ||
      old.lit != lit ||
      old.dashed != dashed ||
      old.past != past ||
      old.ahead != ahead ||
      old.halo != halo ||
      old.stopCount != stopCount;
}
