import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/models.dart';
import '../../../core/transit/live_providers.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/colors.dart';
import '../../../design/tokens/spacing.dart';
import '../../../design/tokens/typography.dart';
import '../application/leg_timing.dart';
import '../application/no_route_help.dart';

/// Un resultado del planificador (§8.4): duración total, horas, las placas en
/// secuencia, transbordos y caminata. Se lee de un vistazo y se anuncia en una
/// sola frase.
class ItineraryCard extends ConsumerWidget {
  const ItineraryCard({
    required this.itinerary,
    required this.departAt,
    required this.onTap,
    this.position,
    this.showBoarding = false,
    super.key,
  });

  final Itinerary itinerary;
  final DateTime departAt;
  final VoidCallback onTap;

  /// "Opción 1", para el lector de pantalla.
  final int? position;

  /// Si se sale ahora, el primer camión trae su arribo en vivo: "pasa en 4
  /// min", o su frecuencia. Solo en la primera tarjeta: son las que se
  /// comparan de un vistazo, no un tablero de arribos.
  final bool showBoarding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = context.colors;
    final DateFormat clock = DateFormat('H:mm');
    final List<Leg> buses = itinerary.busLegs;
    final Leg? first = buses.firstOrNull;
    final Arrival? boarding = switch ((showBoarding, first)) {
      (
        true,
        Leg(fromStopId: final String stopId?, route: final TransitRoute route?),
      ) =>
        switch (ref.watch(stopArrivalsProvider(stopId)).value) {
          final List<Arrival> arrivals => boardingArrival(arrivals, route.id),
          null => null,
        },
      _ => null,
    };

    final String duration = durationLabel(itinerary.totalDuration);
    final String times =
        // Raya, no flecha: Barlow no trae "→" y saldría un cuadro vacío.
        '${clock.format(departAt)}–${clock.format(arrivalAt(itinerary, departAt))}';
    final String walk = '${distanceLabel(itinerary.walkingDistance)} a pie';
    final String summary = '${transfersLabel(itinerary.transferCount)} · $walk';

    final String spoken = <String>[
      if (position != null) 'Opción $position',
      duration,
      transfersLabel(itinerary.transferCount),
      if (buses.isNotEmpty)
        'en ${buses.map((Leg l) => l.route?.shortName ?? '').join(', luego ')}',
      walk,
      'sales ${clock.format(departAt)} y llegas como a las '
          '${clock.format(arrivalAt(itinerary, departAt))}',
      if (boarding != null && first?.route != null)
        '${first!.route!.shortName}: ${EtaChip.describeArrival(boarding)}',
    ].join(', ');

    return Semantics(
      button: true,
      label: spoken,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.cardRadius,
          onTap: onTap,
          child: LitSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: <Widget>[
                    Text(
                      duration,
                      style: AppTypography.eta.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: Text(
                        times,
                        style: AppTypography.body.copyWith(
                          color: colors.textSecondary,
                        ),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.md),
                RouteSequence(legs: itinerary.legs),
                const SizedBox(height: Spacing.sm),
                Text(
                  summary,
                  style: AppTypography.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                if (boarding != null && first?.route != null) ...<Widget>[
                  const SizedBox(height: Spacing.md),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'La ${first!.route!.shortName} en ${first.from}',
                          style: AppTypography.caption.copyWith(
                            color: colors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: Spacing.sm),
                      EtaChip.fromArrival(boarding),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
