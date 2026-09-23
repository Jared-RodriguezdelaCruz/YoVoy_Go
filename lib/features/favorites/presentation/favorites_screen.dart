import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/notices.dart';
import '../../../app/routes.dart';
import '../../../core/data/transit_network.dart';
import '../../../core/models/models.dart';
import '../../../core/transit/live_providers.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/colors.dart';
import '../../../design/tokens/spacing.dart';
import '../../../design/tokens/typography.dart';
import '../application/favorites_providers.dart';
import 'saved_stop_tile.dart';

/// Paradas y rutas guardadas, como en la sección 8.5 del spec.
///
/// Las paradas traen su ETA en vivo: guardar una parada es decir "aquí espero
/// seguido", y lo que se quiere saber al abrir es si ya viene el camión.
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = context.colors;
    final List<String> stops =
        ref.watch(favoriteStopsProvider).value?.toList() ?? <String>[];
    final List<String> routes =
        ref.watch(favoriteRoutesProvider).value?.toList() ?? <String>[];
    final bool empty = stops.isEmpty && routes.isEmpty;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const _TopBar(),
            Expanded(
              child: empty
                  ? const EmptyState(
                      icon: Icons.star_border,
                      title: 'Todavía no guardas nada',
                      message:
                          'La estrella de una parada o de una ruta la deja '
                          'aquí, con sus camiones en vivo.',
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                        Spacing.lg,
                        Spacing.sm,
                        Spacing.lg,
                        Spacing.xxxl,
                      ),
                      children: <Widget>[
                        const OfflineNotice(
                          padding: EdgeInsets.only(bottom: Spacing.md),
                        ),
                        if (stops.isNotEmpty) ...<Widget>[
                          const SectionTitle('Tus paradas'),
                          for (final String stopId in stops)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: Spacing.md,
                              ),
                              child: SavedStopTile(stopId: stopId),
                            ),
                        ],
                        if (routes.isNotEmpty) ...<Widget>[
                          const SizedBox(height: Spacing.lg),
                          const SectionTitle('Tus rutas'),
                          for (final String routeId in routes)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: Spacing.md,
                              ),
                              child: _FavoriteRouteRow(routeId: routeId),
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
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.xs, 0, Spacing.lg, 0),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: 'Volver',
            icon: Icon(Icons.arrow_back, color: context.colors.textPrimary),
            onPressed: () => context.canPop()
                ? context.pop()
                : context.goNamed(AppRoute.map.name),
          ),
          const SizedBox(width: Spacing.xs),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                'Favoritos',
                style: AppTypography.title.copyWith(
                  color: context.colors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Una ruta guardada: su placa, a dónde va y la estrella para soltarla.
class _FavoriteRouteRow extends ConsumerWidget {
  const _FavoriteRouteRow({required this.routeId});

  final String routeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = context.colors;
    final TransitNetwork? network = ref.watch(transitNetworkProvider).value;
    final TransitRoute? route = network?.route(routeId);
    if (route == null) {
      return const SheetSkeleton(lines: 1);
    }

    return Material(
      color: colors.surfaceRaised,
      borderRadius: AppRadius.cardRadius,
      child: InkWell(
        borderRadius: AppRadius.cardRadius,
        onTap: () => context.pushNamed(
          AppRoute.route.name,
          pathParameters: <String, String>{AppParams.routeId: routeId},
        ),
        child: Container(
          padding: const EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardRadius,
            border: Border.all(
              color: colors.outline,
              width: AppSizes.outlineWidth,
            ),
          ),
          child: Row(
            children: <Widget>[
              RouteBadge(
                shortName: route.shortName,
                routeId: route.id,
                gtfsColor: route.color,
                gtfsTextColor: route.textColor,
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Text(
                  route.longName,
                  style: AppTypography.body.copyWith(color: colors.textPrimary),
                ),
              ),
              IconButton(
                tooltip: 'Quitar de favoritos',
                onPressed: () =>
                    ref.read(favoriteRoutesProvider.notifier).toggle(routeId),
                icon: Icon(Icons.star, color: colors.cantera),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
