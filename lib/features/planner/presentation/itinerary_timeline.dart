import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/data/transit_network.dart';
import '../../../core/models/models.dart';
import '../../../core/transit/live_providers.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/colors.dart';
import '../../../design/tokens/route_palette.dart';
import '../../../design/tokens/spacing.dart';
import '../../../design/tokens/typography.dart';
import '../application/leg_timing.dart';
import '../application/no_route_help.dart';
import '../application/ride_session.dart';

/// El itinerario como línea de tiempo vertical (§8.4): cada tramo con su
/// hora, la caminata punteada y cada camión en el color de su ruta.
class ItineraryTimeline extends ConsumerWidget {
  const ItineraryTimeline({
    required this.itinerary,
    required this.departAt,
    this.leavesNow = false,
    super.key,
  });

  final Itinerary itinerary;
  final DateTime departAt;

  /// Si se sale ahora, cada subida trae el arribo en vivo de su camión.
  final bool leavesNow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TransitNetwork? network = ref.watch(transitNetworkProvider).value;
    final List<LegTimes> times = legTimes(itinerary, departAt);
    final List<Leg> legs = itinerary.legs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int i = 0; i < legs.length; i++)
          legs[i].isWalk
              ? WalkLegRow(
                  leg: legs[i],
                  start: times[i].start,
                  meters: legMeters(legs[i]),
                )
              : BusLegRow(
                  leg: legs[i],
                  start: times[i].start,
                  network: network,
                  // Solo la primera subida: la hora de las demás depende de
                  // cómo vaya el viaje, y un arribo de ahora no le sirve.
                  liveBoarding: leavesNow && i == _firstBusIndex,
                ),
        _EndRow(
          name: legs.lastOrNull?.to ?? '',
          at: times.lastOrNull?.end ?? departAt,
        ),
      ],
    );
  }

  int get _firstBusIndex => itinerary.legs.indexWhere((Leg leg) => !leg.isWalk);
}

/// Lo que mide un tramo a pie, sobre su geometría.
double legMeters(Leg leg) {
  const Distance distance = Distance();
  double total = 0;
  for (int i = 1; i < leg.geometry.length; i++) {
    total += distance.as(
      LengthUnit.Meter,
      leg.geometry[i - 1],
      leg.geometry[i],
    );
  }
  return total;
}

/// El riel de la izquierda: un punto por tramo y la línea que lo une con el
/// siguiente. La caminata va punteada y en gris; el camión, sólido y en su
/// color. El color nunca va solo: el tramo dice con palabras qué es.
class _Rail extends StatelessWidget {
  const _Rail({required this.color, required this.dotted, this.icon});

  final Color color;
  final bool dotted;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return SizedBox(
      width: 32,
      child: Column(
        children: <Widget>[
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: colors.surfaceRaised,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
            child: icon == null
                ? null
                : Icon(icon, size: 14, color: colors.textPrimary),
          ),
          Expanded(
            child: CustomPaint(
              painter: _RailPainter(color: color, dotted: dotted),
              child: const SizedBox(width: 4),
            ),
          ),
        ],
      ),
    );
  }
}

class _RailPainter extends CustomPainter {
  const _RailPainter({required this.color, required this.dotted});

  final Color color;
  final bool dotted;

  @override
  void paint(Canvas canvas, Size size) {
    final double x = size.width / 2;
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = dotted ? 3 : 4
      ..strokeCap = StrokeCap.round;
    if (!dotted) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      return;
    }
    for (double y = 4; y < size.height; y += 8) {
      canvas.drawCircle(Offset(x, y), 1.5, paint);
    }
  }

  @override
  bool shouldRepaint(_RailPainter old) =>
      old.color != color || old.dotted != dotted;
}

class _Row extends StatelessWidget {
  const _Row({required this.rail, required this.time, required this.child});

  final Widget rail;
  final DateTime time;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: 48,
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                DateFormat('H:mm').format(time),
                style: AppTypography.caption.copyWith(
                  color: colors.textSecondary,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ),
          ),
          rail,
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: Spacing.xl),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Camina 4 min · 300 m hasta Rosaura Zapata".
class WalkLegRow extends StatelessWidget {
  const WalkLegRow({
    required this.leg,
    required this.start,
    required this.meters,
    super.key,
  });

  final Leg leg;
  final DateTime start;
  final double meters;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final String text =
        'Camina ${durationLabel(leg.duration)} · ${distanceLabel(meters)} '
        'hasta ${leg.to}';
    return Semantics(
      label:
          'A las ${DateFormat('H:mm').format(start)}, desde ${leg.from}. '
          '$text',
      excludeSemantics: true,
      child: _Row(
        time: start,
        rail: _Rail(
          color: colors.textSecondary,
          dotted: true,
          icon: Icons.directions_walk,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              leg.from,
              style: AppTypography.label.copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              text,
              style: AppTypography.body.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un tramo en camión: la placa, hacia dónde va, dónde subir y dónde bajar.
class BusLegRow extends ConsumerWidget {
  const BusLegRow({
    required this.leg,
    required this.start,
    required this.network,
    this.liveBoarding = false,
    super.key,
  });

  final Leg leg;
  final DateTime start;
  final TransitNetwork? network;
  final bool liveBoarding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = context.colors;
    final TransitRoute? route = leg.route;
    final TransitNetwork? net = network;
    final LegPath? path = net == null ? null : legPath(net, leg);
    final String? headsign = path == null
        ? null
        : net!.trip(path.tripId)?.headsign;
    final Stop? board = leg.fromStopId == null
        ? null
        : net?.stop(leg.fromStopId!);
    final Stop? alight = leg.toStopId == null ? null : net?.stop(leg.toStopId!);
    final Arrival? arrival = switch ((liveBoarding, leg.fromStopId, route)) {
      (true, final String stopId?, final TransitRoute r?) => switch (ref
          .watch(stopArrivalsProvider(stopId))
          .value) {
        final List<Arrival> arrivals => boardingArrival(arrivals, r.id),
        null => null,
      },
      _ => null,
    };
    final Color color = route == null
        ? colors.textSecondary
        : RoutePalette.colorForRoute(routeId: route.id, gtfsColor: route.color);
    final int? stops = path?.stopCount;
    final String ride = <String>[
      durationLabel(leg.duration),
      if (stops != null) stops == 1 ? '1 parada' : '$stops paradas',
    ].join(' · ');

    final String spoken = <String>[
      'A las ${DateFormat('H:mm').format(start)}',
      'sube a la ${route?.shortName ?? 'ruta'} en ${leg.from}',
      if (_accessible(board)) 'parada accesible',
      if (headsign != null) 'hacia $headsign',
      'baja en ${leg.to}',
      if (_accessible(alight)) 'parada accesible',
      ride,
      if (arrival != null) EtaChip.describeArrival(arrival),
    ].join(', ');

    return Semantics(
      label: spoken,
      excludeSemantics: true,
      child: _Row(
        time: start,
        rail: _Rail(color: color, dotted: false, icon: Icons.directions_bus),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _StopName(name: leg.from, accessible: _accessible(board)),
            const SizedBox(height: Spacing.sm),
            Row(
              children: <Widget>[
                if (route != null)
                  RouteBadge(
                    shortName: route.shortName,
                    routeId: route.id,
                    gtfsColor: route.color,
                    gtfsTextColor: route.textColor,
                  ),
                if (headsign != null) ...<Widget>[
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Text(
                      'Hacia $headsign',
                      style: AppTypography.body.copyWith(
                        color: colors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            if (arrival != null) ...<Widget>[
              const SizedBox(height: Spacing.sm),
              EtaChip.fromArrival(arrival),
            ],
            const SizedBox(height: Spacing.sm),
            Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(text: 'Baja en ${leg.to}'),
                  if (_accessible(alight)) ..._accessibleMark(colors),
                  TextSpan(text: ' · $ride'),
                ],
              ),
              style: AppTypography.body.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

bool _accessible(Stop? stop) =>
    stop?.wheelchairBoarding == WheelchairBoarding.accessible;

List<InlineSpan> _accessibleMark(AppColors colors) => <InlineSpan>[
  const TextSpan(text: ' '),
  WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Icon(Icons.accessible, size: 16, color: colors.textSecondary),
  ),
];

class _StopName extends StatelessWidget {
  const _StopName({required this.name, required this.accessible});

  final String name;
  final bool accessible;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(text: name),
          if (accessible) ..._accessibleMark(colors),
        ],
      ),
      style: AppTypography.label.copyWith(color: colors.textPrimary),
    );
  }
}

class _EndRow extends StatelessWidget {
  const _EndRow({required this.name, required this.at});

  final String name;
  final DateTime at;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Semantics(
      label: 'Llegas como a las ${DateFormat('H:mm').format(at)} a $name',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 48,
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                '~${DateFormat('H:mm').format(at)}',
                style: AppTypography.caption.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 32,
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: colors.brand,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.flag, size: 14, color: colors.onBrand),
              ),
            ),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Text(
              name,
              style: AppTypography.label.copyWith(color: colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
