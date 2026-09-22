import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/config/freshness.dart';
import '../../../core/models/models.dart';
import '../../../core/transit/live_providers.dart';
import '../../../core/transit/reliability.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/colors.dart';
import '../../../design/tokens/route_palette.dart';
import '../../../design/tokens/spacing.dart';
import '../../../design/tokens/typography.dart';
import '../application/route_providers.dart';
import '../application/vehicle_placement.dart';
import 'route_minimap.dart';
import 'route_stop_ladder.dart';

/// Detalle de ruta, como en la sección 8.3 del spec.
///
/// Arriba el trazo sobre la ciudad; abajo la tira de pie, con los camiones
/// entre paradas. El selector de sentido nombra el destino.
class RouteScreen extends ConsumerWidget {
  const RouteScreen({required this.routeId, this.fromStopId, super.key});

  final String routeId;

  /// La parada desde la que se llegó, si se llegó desde una. La
  /// confiabilidad solo tiene sentido en una parada concreta.
  final String? fromStopId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = context.colors;
    final AsyncValue<List<RouteDirection>> directions = ref.watch(
      routeDirectionsProvider(routeId),
    );
    final TransitRoute? route = ref
        .watch(transitNetworkProvider)
        .value
        ?.route(routeId);

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        bottom: false,
        child: switch (directions) {
          AsyncValue<List<RouteDirection>>(:final List<RouteDirection> value?)
              when route != null =>
            _RouteBody(route: route, directions: value, fromStopId: fromStopId),
          AsyncValue<List<RouteDirection>>(error: RouteNotFound()) => _Missing(
            routeId: routeId,
          ),
          AsyncValue<List<RouteDirection>>(hasError: true) => Column(
            children: <Widget>[
              const _TopBar(),
              Expanded(
                child: ErrorState(
                  title: 'No se pudo cargar la ruta',
                  message: 'El servicio no respondió. Vuelve a intentarlo.',
                  onRetry: () => ref.invalidate(transitNetworkProvider),
                ),
              ),
            ],
          ),
          _ => const _Loading(),
        },
      ),
    );
  }
}

class _RouteBody extends ConsumerWidget {
  const _RouteBody({
    required this.route,
    required this.directions,
    required this.fromStopId,
  });

  final TransitRoute route;
  final List<RouteDirection> directions;
  final String? fromStopId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = context.colors;
    final int directionId =
        ref.watch(selectedDirectionProvider(route.id)) ??
        directions.first.directionId;
    final AsyncValue<RouteDetail> detail = ref.watch(
      routeDetailProvider(route.id, directionId),
    );
    final Color color = RoutePalette.colorForRoute(
      routeId: route.id,
      gtfsColor: route.color,
    );
    final String? stopId = fromStopId;
    final String? reliability = stopId == null
        ? null
        : ref
              .watch(reliabilityNoteProvider(routeId: route.id, stopId: stopId))
              .value;
    final double mapHeight = (MediaQuery.sizeOf(context).height * 0.3).clamp(
      160,
      280,
    );

    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: _TopBar(
            title: Row(
              children: <Widget>[
                RouteBadge(
                  shortName: route.shortName,
                  routeId: route.id,
                  gtfsColor: route.color,
                  gtfsTextColor: route.textColor,
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Semantics(
                        header: true,
                        child: Text(
                          route.longName,
                          style: AppTypography.title.copyWith(
                            color: colors.textPrimary,
                            fontSize: 18,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ReliabilityNote(text: reliability),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.lg,
            Spacing.sm,
            Spacing.lg,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: SizedBox(
              height: mapHeight,
              child: switch (detail.value) {
                final RouteDetail value => RouteMinimap(
                  key: ValueKey<int>(directionId),
                  path: value.path,
                  color: color,
                  vehicles: value.vehicles,
                ),
                null => DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surfaceSunken,
                    borderRadius: AppRadius.cardRadius,
                  ),
                ),
              },
            ),
          ),
        ),
        if (directions.length > 1)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.lg,
              Spacing.lg,
              Spacing.lg,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: _DirectionPicker(
                directions: directions,
                selected: directionId,
                onSelected: (int id) => ref
                    .read(selectedDirectionProvider(route.id).notifier)
                    .select(id),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.lg,
              Spacing.lg,
              Spacing.lg,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Hacia ${directions.first.headsign}',
                style: AppTypography.label.copyWith(color: colors.textPrimary),
              ),
            ),
          ),
        ..._ladder(context, ref, detail, color, directionId),
        const SliverToBoxAdapter(child: SizedBox(height: Spacing.xxxl)),
      ],
    );
  }

  List<Widget> _ladder(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<RouteDetail> detail,
    Color color,
    int directionId,
  ) {
    final RouteDetail? value = detail.value;
    if (value == null) {
      if (detail.hasError) {
        return <Widget>[
          SliverToBoxAdapter(
            child: ErrorState(
              title: 'No se pudieron cargar las paradas',
              message: 'El servicio no respondió. Vuelve a intentarlo.',
              onRetry: () =>
                  ref.invalidate(routeDetailProvider(route.id, directionId)),
            ),
          ),
        ];
      }
      return const <Widget>[
        SliverPadding(
          padding: EdgeInsets.all(Spacing.lg),
          sliver: SliverToBoxAdapter(child: SheetSkeleton(lines: 6)),
        ),
      ];
    }

    return <Widget>[
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.lg,
          Spacing.md,
          Spacing.lg,
          Spacing.sm,
        ),
        sliver: SliverToBoxAdapter(child: _FleetLine(vehicles: value.vehicles)),
      ),
      if (value.stops.isEmpty)
        const SliverToBoxAdapter(
          child: EmptyState(
            icon: Icons.format_list_bulleted,
            title: 'Este sentido no trae paradas',
            message:
                'El horario oficial no lista sus paradas. Prueba el otro '
                'sentido o busca la ruta en el mapa.',
          ),
        )
      else
        RouteStopLadder(
          stops: value.stops,
          vehicles: value.vehicles,
          color: color,
          onStopTap: (Stop stop) => context.pushNamed(
            AppRoute.stop.name,
            pathParameters: <String, String>{AppParams.stopId: stop.id},
          ),
        ),
    ];
  }
}

/// Cuántos camiones hay, dicho con todas sus letras. Una ruta sin camiones
/// no se resuelve con una tira vacía (sección 8.3).
class _FleetLine extends StatelessWidget {
  const _FleetLine({required this.vehicles});

  final List<PlacedVehicle> vehicles;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final int reporting = vehicles
        .where(
          (PlacedVehicle v) =>
              Freshness.classify(v.age) != DataFreshness.unknown,
        )
        .length;
    final int silent = vehicles.length - reporting;

    final String text = switch ((reporting, silent)) {
      (0, 0) => 'Ningún camión de esta ruta está reportando ahora.',
      (0, 1) => 'Ningún camión reporta ahora. Uno perdió la señal.',
      (0, final int s) => 'Ningún camión reporta ahora. $s perdieron la señal.',
      (1, 0) => '1 camión reportando',
      (final int r, 0) => '$r camiones reportando',
      (final int r, final int s) =>
        '${r == 1 ? '1 camión reportando' : '$r camiones reportando'} · '
            '$s sin señal',
    };

    return Semantics(
      liveRegion: true,
      child: Text(
        text,
        style: AppTypography.body.copyWith(
          color: reporting == 0 ? colors.stale : colors.textSecondary,
        ),
      ),
    );
  }
}

class _DirectionPicker extends StatelessWidget {
  const _DirectionPicker({
    required this.directions,
    required this.selected,
    required this.onSelected,
  });

  final List<RouteDirection> directions;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<int>(
        showSelectedIcon: false,
        // El sentido elegido es una acción del usuario sobre el sistema: va
        // en el índigo de marca, no en el acento de fábrica de Material.
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: colors.brand,
          selectedForegroundColor: colors.onBrand,
          foregroundColor: colors.textPrimary,
          backgroundColor: colors.surfaceRaised,
          side: BorderSide(color: colors.outline),
          textStyle: AppTypography.label,
        ),
        segments: <ButtonSegment<int>>[
          for (final RouteDirection direction in directions)
            ButtonSegment<int>(
              value: direction.directionId,
              label: Text(
                'Hacia ${direction.headsign}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
        ],
        selected: <int>{selected},
        onSelectionChanged: (Set<int> value) => onSelected(value.single),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({this.title});

  final Widget? title;

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
          if (title != null) Expanded(child: title!),
        ],
      ),
    );
  }
}

class _Missing extends StatelessWidget {
  const _Missing({required this.routeId});

  final String routeId;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const _TopBar(),
        Expanded(
          child: EmptyState(
            icon: Icons.route_outlined,
            title: 'Esta ruta no existe',
            message:
                'No hay ninguna ruta con el código $routeId. Búscala por su '
                'número en el mapa.',
            actionLabel: 'Ir al mapa',
            onAction: () => context.goNamed(AppRoute.map.name),
          ),
        ),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        const _TopBar(),
        Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              color: colors.surfaceSunken,
              borderRadius: AppRadius.cardRadius,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(Spacing.lg),
          child: SheetSkeleton(lines: 6),
        ),
      ],
    );
  }
}
