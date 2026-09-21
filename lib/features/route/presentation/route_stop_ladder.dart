import 'package:flutter/material.dart';

import '../../../core/config/freshness.dart';
import '../../../core/models/models.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/colors.dart';
import '../../../design/tokens/spacing.dart';
import '../../../design/tokens/typography.dart';
import '../application/vehicle_placement.dart';

/// La tira con luz de recorrido, puesta de pie.
///
/// Es `RouteStrip` con todas las paradas de un sentido: la línea baja por el
/// margen, cada parada es una marca y cada camión es el mismo bloque
/// rectangular, dibujado **entre** la parada por la que pasó y la que sigue.
/// La regla de la luz es la misma: con dato vigente el bloque lleva halo; con
/// el dato vencido el halo se va, el bloque se vuelve gris y el tramo que
/// tiene delante se puntea, porque dejó de ser una promesa.
///
/// Cada fila es su propio `CustomPaint`, así que la lista se construye
/// perezosa aunque la ruta tenga 80 paradas.
class RouteStopLadder extends StatelessWidget {
  const RouteStopLadder({
    required this.stops,
    required this.vehicles,
    required this.color,
    required this.onStopTap,
    super.key,
  });

  final List<Stop> stops;
  final List<PlacedVehicle> vehicles;

  /// El color de la ruta.
  final Color color;
  final ValueChanged<Stop> onStopTap;

  @override
  Widget build(BuildContext context) {
    final Map<int, List<PlacedVehicle>> bySegment =
        <int, List<PlacedVehicle>>{};
    for (final PlacedVehicle placed in vehicles) {
      bySegment
          .putIfAbsent(placed.afterIndex, () => <PlacedVehicle>[])
          .add(placed);
    }

    return SliverList.builder(
      itemCount: stops.length,
      itemBuilder: (BuildContext context, int index) => LadderRow(
        stop: stops[index],
        position: index == 0
            ? LadderPosition.first
            : index == stops.length - 1
            ? LadderPosition.last
            : LadderPosition.middle,
        vehicles: bySegment[index] ?? const <PlacedVehicle>[],
        color: color,
        onTap: () => onStopTap(stops[index]),
      ),
    );
  }
}

/// Dónde cae una fila en la tira: la primera no tiene línea arriba y la
/// última no la tiene abajo.
enum LadderPosition { first, middle, last }

/// Una parada de la tira, con los camiones que van entre ella y la
/// siguiente.
class LadderRow extends StatelessWidget {
  const LadderRow({
    required this.stop,
    required this.position,
    required this.vehicles,
    required this.color,
    required this.onTap,
    super.key,
  });

  final Stop stop;
  final LadderPosition position;
  final List<PlacedVehicle> vehicles;
  final Color color;
  final VoidCallback onTap;

  /// El ancho del margen donde se pinta la tira.
  static const double gutter = 56;

  /// A qué altura de la fila va la marca de la parada: el centro de la
  /// primera línea del nombre, que crece con el texto del sistema.
  static double markYFor(BuildContext context) =>
      Spacing.md +
      MediaQuery.textScalerOf(context).scale(AppTypography.body.fontSize!) *
          AppTypography.body.height! /
          2;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final bool terminal = position != LadderPosition.middle;

    final String vehicleText = switch (vehicles.length) {
      0 => '',
      1 => _describe(vehicles.single.age),
      final int n => '$n camiones · ${_describe(_freshest(vehicles))}',
    };

    return Semantics(
      button: true,
      label: <String>[
        stop.name,
        if (terminal) 'terminal',
        if (vehicles.isNotEmpty)
          vehicles.length == 1
              ? 'un camión acaba de pasar, ${_describe(vehicles.single.age)}'
              : '${vehicles.length} camiones acaban de pasar',
        'Ver la parada',
      ].join('. '),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: <Widget>[
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: gutter,
              child: CustomPaint(
                painter: _LadderPainter(
                  markY: markYFor(context),
                  position: position,
                  vehicles: <({Duration age})>[
                    for (final PlacedVehicle v in vehicles) (age: v.age),
                  ],
                  line: color,
                  surface: colors.surface,
                  unknown: colors.unknown,
                  live: colors.live,
                  stale: colors.stale,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                gutter,
                Spacing.md,
                Spacing.lg,
                // Con camión, la fila crece para que el bloque tenga su
                // tramo entre esta parada y la siguiente.
                vehicles.isEmpty ? Spacing.md : Spacing.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    stop.name,
                    style: (terminal ? AppTypography.label : AppTypography.body)
                        .copyWith(
                          color: colors.textPrimary,
                          fontWeight: terminal ? FontWeight.w700 : null,
                        ),
                  ),
                  if (vehicles.isNotEmpty) ...<Widget>[
                    const SizedBox(height: Spacing.xs),
                    Text(
                      vehicleText,
                      style: AppTypography.caption.copyWith(
                        color: FreshnessCopy.color(
                          colors,
                          Freshness.classify(_freshest(vehicles)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Duration _freshest(List<PlacedVehicle> vehicles) => vehicles
      .map((PlacedVehicle v) => v.age)
      .reduce((Duration a, Duration b) => a < b ? a : b);

  static String _describe(Duration age) =>
      Freshness.classify(age) == DataFreshness.unknown
      ? 'camión sin señal, ${FreshnessCopy.age(age)}'
      : 'camión ${FreshnessCopy.label(age)}';
}

class _LadderPainter extends CustomPainter {
  const _LadderPainter({
    required this.markY,
    required this.position,
    required this.vehicles,
    required this.line,
    required this.surface,
    required this.unknown,
    required this.live,
    required this.stale,
  });

  final double markY;
  final LadderPosition position;
  final List<({Duration age})> vehicles;
  final Color line;
  final Color surface;
  final Color unknown;
  final Color live;
  final Color stale;

  static const double _stroke = 4;
  static const double _mark = 6;
  static const double _terminal = 8;
  static const double _busWidth = 18;
  static const double _busHeight = 14;

  @override
  void paint(Canvas canvas, Size size) {
    final double x = size.width / 2;
    final Paint stroke = Paint()
      ..color = line
      ..strokeWidth = _stroke;

    // Hacia arriba, hasta el tramo de la fila anterior.
    if (position != LadderPosition.first) {
      canvas.drawLine(Offset(x, 0), Offset(x, markY), stroke);
    }

    // Hacia abajo: el tramo hasta la siguiente parada. Si el camión que lo
    // recorre perdió la señal, se puntea.
    final bool anyLit = vehicles.any(
      (({Duration age}) v) =>
          Freshness.classify(v.age) != DataFreshness.unknown,
    );
    final bool dashed = vehicles.isNotEmpty && !anyLit;
    if (position != LadderPosition.last) {
      if (dashed) {
        const double dash = 6;
        const double gap = 5;
        final Paint dim = Paint()
          ..color = unknown
          ..strokeWidth = _stroke;
        for (double y = markY; y < size.height; y += dash + gap) {
          canvas.drawLine(
            Offset(x, y),
            Offset(x, (y + dash).clamp(markY, size.height)),
            dim,
          );
        }
      } else {
        canvas.drawLine(Offset(x, markY), Offset(x, size.height), stroke);
      }
    }

    // La parada: hueca en medio, llena en las terminales, como en un
    // diagrama de línea.
    final bool terminal = position != LadderPosition.middle;
    final double radius = terminal ? _terminal : _mark;
    canvas
      ..drawCircle(Offset(x, markY), radius + 2, Paint()..color = surface)
      ..drawCircle(Offset(x, markY), radius, Paint()..color = line);
    if (!terminal) {
      canvas.drawCircle(
        Offset(x, markY),
        radius - 2.5,
        Paint()..color = surface,
      );
    }

    if (vehicles.isEmpty) {
      return;
    }

    // Los camiones: en la última parada, llegando a ella; en las demás, a
    // medio tramo. Varios en el mismo tramo se escalonan para no taparse.
    final double baseY = position == LadderPosition.last
        ? markY
        : markY + (size.height - markY) * 0.55;
    for (int i = 0; i < vehicles.length; i++) {
      final DataFreshness freshness = Freshness.classify(vehicles[i].age);
      final bool lit = freshness != DataFreshness.unknown;
      final Offset center = Offset(x, baseY + i * (_busHeight * 0.7));

      if (lit) {
        final Color halo = freshness == DataFreshness.live ? live : stale;
        canvas
          ..drawCircle(
            center,
            _busWidth,
            Paint()..color = halo.withValues(alpha: 0.18),
          )
          ..drawCircle(
            center,
            _busWidth * 0.66,
            Paint()..color = halo.withValues(alpha: 0.24),
          );
      }

      // Rectangular como la señalética, igual que en la tira horizontal.
      final Rect bus = Rect.fromCenter(
        center: center,
        width: _busWidth,
        height: _busHeight,
      );
      canvas
        ..drawRect(bus.inflate(2), Paint()..color = surface)
        ..drawRect(bus, Paint()..color = lit ? line : unknown);
    }
  }

  @override
  bool shouldRepaint(_LadderPainter old) =>
      old.markY != markY ||
      old.position != position ||
      old.line != line ||
      old.surface != surface ||
      !_sameAges(old.vehicles, vehicles);

  static bool _sameAges(List<({Duration age})> a, List<({Duration age})> b) {
    if (a.length != b.length) {
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}
