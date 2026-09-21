import 'package:flutter/material.dart';

import '../../core/models/arrival.dart';
import '../../core/models/enums.dart';
import '../tokens/colors.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';
import 'eta_chip.dart';
import 'route_badge.dart';

/// Una parada con sus próximos arribos.
///
/// Es la fila que se repite en el mapa, en favoritos y en los resultados de
/// búsqueda. Cuando no hay arribos lo dice con todas sus letras: una lista
/// vacía sin explicación se lee como una falla de la app.
class StopTile extends StatelessWidget {
  const StopTile({
    required this.name,
    required this.arrivals,
    this.code,
    this.distanceLabel,
    this.accessibility = WheelchairBoarding.unknown,
    this.isFavorite = false,
    this.onTap,
    this.onToggleFavorite,
    this.maxArrivals = 3,
    super.key,
  });

  final String name;

  /// Código del poste, cuando existe.
  final String? code;

  /// Arribos ya ordenados por ETA.
  final List<Arrival> arrivals;

  /// "a 240 m", "a 7 min caminando".
  final String? distanceLabel;

  final WheelchairBoarding accessibility;
  final bool isFavorite;
  final VoidCallback? onTap;
  final VoidCallback? onToggleFavorite;

  /// Cuántos arribos se muestran antes de resumir el resto.
  final int maxArrivals;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final List<Arrival> visible = arrivals.take(maxArrivals).toList();
    final int hidden = arrivals.length - visible.length;

    return Material(
      color: colors.surfaceRaised,
      borderRadius: AppRadius.cardRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardRadius,
        child: Container(
          padding: const EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardRadius,
            border: Border.all(
              color: colors.outline,
              width: AppSizes.outlineWidth,
            ),
          ),
          child: Column(
            // La tarjeta mide lo que mide su contenido: si el padre le da
            // altura de sobra, no se estira para llenarla.
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Header(
                name: name,
                code: code,
                distanceLabel: distanceLabel,
                accessibility: accessibility,
                isFavorite: isFavorite,
                onToggleFavorite: onToggleFavorite,
              ),
              const SizedBox(height: Spacing.md),
              if (visible.isEmpty)
                Text(
                  'Sin camiones en camino ahora',
                  style: AppTypography.body.copyWith(
                    color: colors.textSecondary,
                  ),
                )
              else
                ...visible.map(
                  (Arrival arrival) => Padding(
                    padding: const EdgeInsets.only(bottom: Spacing.sm),
                    child: _ArrivalRow(arrival: arrival),
                  ),
                ),
              if (hidden > 0)
                Text(
                  hidden == 1 ? '1 ruta más' : '$hidden rutas más',
                  style: AppTypography.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.code,
    required this.distanceLabel,
    required this.accessibility,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  final String name;
  final String? code;
  final String? distanceLabel;
  final WheelchairBoarding accessibility;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                name,
                style: AppTypography.title.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: 2),
              Row(
                children: <Widget>[
                  // Un solo texto que puede partirse en dos líneas: el código,
                  // la distancia y el ícono no caben en fila en un teléfono
                  // de 360 dp, y ninguno de los tres se puede recortar.
                  if (code != null || distanceLabel != null)
                    Flexible(
                      child: Text(
                        <String>[?code, ?distanceLabel].join(' · '),
                        style: AppTypography.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (accessibility ==
                      WheelchairBoarding.accessible) ...<Widget>[
                    const SizedBox(width: Spacing.sm),
                    Semantics(
                      label: 'Parada accesible',
                      child: Icon(
                        Icons.accessible,
                        size: 16,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        if (onToggleFavorite != null)
          IconButton(
            onPressed: onToggleFavorite,
            iconSize: 22,
            constraints: const BoxConstraints(
              minWidth: AppSizes.minTouchTarget,
              minHeight: AppSizes.minTouchTarget,
            ),
            tooltip: isFavorite
                ? 'Quitar de favoritos'
                : 'Guardar en favoritos',
            icon: Icon(
              isFavorite ? Icons.star : Icons.star_border,
              color: isFavorite ? colors.brand : colors.textSecondary,
            ),
          ),
      ],
    );
  }
}

class _ArrivalRow extends StatelessWidget {
  const _ArrivalRow({required this.arrival});

  final Arrival arrival;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    // Con el texto del sistema muy grande, la placa, el destino y el chip no
    // caben en un renglón. En vez de recortar el destino hasta dejarlo
    // inservible, la fila se parte en dos. Es la misma información, no una
    // versión degradada.
    final bool stacked =
        MediaQuery.textScalerOf(context).scale(AppTypography.body.fontSize!) >
        22;

    final Widget badge = RouteBadge(
      shortName: arrival.routeShortName,
      routeId: arrival.routeId,
      size: RouteBadgeSize.small,
    );
    final Widget headsign = Text(
      arrival.headsign,
      maxLines: stacked ? 2 : 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.body.copyWith(color: colors.textPrimary),
    );

    return Semantics(
      label: 'Ruta ${arrival.routeShortName} a ${arrival.headsign}',
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    badge,
                    const SizedBox(width: Spacing.md),
                    Expanded(child: headsign),
                  ],
                ),
                const SizedBox(height: Spacing.sm),
                EtaChip.fromArrival(arrival),
              ],
            )
          : Row(
              children: <Widget>[
                badge,
                const SizedBox(width: Spacing.md),
                Expanded(child: headsign),
                const SizedBox(width: Spacing.sm),
                EtaChip.fromArrival(arrival),
              ],
            ),
    );
  }
}
