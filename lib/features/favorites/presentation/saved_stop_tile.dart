import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/data/transit_network.dart';
import '../../../core/models/models.dart';
import '../../../core/transit/live_providers.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/colors.dart';
import '../../../design/tokens/spacing.dart';
import '../../../design/tokens/typography.dart';
import '../../stop/application/stop_providers.dart';
import '../application/favorites_providers.dart';

/// Una parada guardada o sugerida, con sus camiones en vivo.
///
/// Es la misma fila del mapa (`StopTile`), pero partiendo de un id: favoritos
/// y las sugerencias de "a esta hora sueles tomar" no saben la distancia, y no
/// hace falta —la parada ya la eligió el usuario—.
class SavedStopTile extends ConsumerWidget {
  const SavedStopTile({
    required this.stopId,
    this.label,
    this.onHide,
    super.key,
  });

  final String stopId;

  /// La línea chica bajo el nombre: "a esta hora sueles tomar".
  final String? label;

  /// Si se puede callar esta sugerencia. Los favoritos no se ocultan: se
  /// quitan con la estrella.
  final VoidCallback? onHide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Stop> stop = ref.watch(stopDetailProvider(stopId));
    final AsyncValue<List<Arrival>> arrivals = ref.watch(
      stopArrivalsProvider(stopId),
    );
    final TransitNetwork? network = ref.watch(transitNetworkProvider).value;
    final bool isFavorite =
        ref.watch(favoriteStopsProvider).value?.contains(stopId) ?? false;

    if (stop.value case final Stop value) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          StopTile(
            name: value.name,
            code: value.code,
            arrivals: arrivals.value ?? const <Arrival>[],
            distanceLabel: label,
            accessibility: value.wheelchairBoarding,
            isFavorite: isFavorite,
            routeOf: network?.route,
            onToggleFavorite: () =>
                ref.read(favoriteStopsProvider.notifier).toggle(stopId),
            onTap: () => context.pushNamed(
              AppRoute.stop.name,
              pathParameters: <String, String>{AppParams.stopId: stopId},
            ),
          ),
          if (onHide != null)
            TextButton.icon(
              onPressed: onHide,
              icon: const Icon(Icons.visibility_off_outlined, size: 18),
              label: const Text('No me la muestres'),
            ),
        ],
      );
    }

    // Una parada que ya no existe en el dataset no se anuncia como falla: se
    // calla, y la estrella se queda donde está hasta que el usuario la quite.
    return stop.hasError ? const SizedBox.shrink() : const SheetSkeleton();
  }
}

/// Un separador con título para las secciones de favoritos y sugerencias.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {this.trailing, super.key});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                text,
                style: AppTypography.title.copyWith(
                  color: context.colors.textPrimary,
                ),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
