import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/data/not_found.dart';
import '../../../core/models/models.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/colors.dart';
import '../../../design/tokens/spacing.dart';
import '../../../design/tokens/typography.dart';
import '../application/leg_timing.dart';
import '../application/no_route_help.dart';
import '../application/planner_providers.dart';
import '../application/trip_request.dart';
import 'itinerary_map.dart';
import 'itinerary_timeline.dart';

/// Detalle de itinerario (§8.4): el mapa con la geometría completa arriba y
/// la línea de tiempo vertical abajo. De aquí se entra al modo viaje.
class ItineraryScreen extends ConsumerWidget {
  const ItineraryScreen({
    required this.request,
    required this.index,
    super.key,
  });

  final TripRequest request;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = context.colors;
    final AsyncValue<(TripPlan, Itinerary)> option = request.isComplete
        ? ref.watch(tripOptionProvider(request, index))
        : const AsyncValue<(TripPlan, Itinerary)>.error(
            TripOptionNotFound('sin petición'),
            StackTrace.empty,
          );

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: switch (option) {
          AsyncValue<(TripPlan, Itinerary)>(
            value: (final TripPlan plan, final Itinerary itinerary)?,
          ) =>
            _Body(
              request: request,
              index: index,
              plan: plan,
              itinerary: itinerary,
            ),
          AsyncValue<(TripPlan, Itinerary)>(error: NotFound()) => _Gone(
            request: request,
          ),
          AsyncValue<(TripPlan, Itinerary)>(error: OriginUnavailable()) =>
            _Gone(request: request),
          AsyncValue<(TripPlan, Itinerary)>(error: PlaceNotFound()) => _Gone(
            request: request,
          ),
          AsyncValue<(TripPlan, Itinerary)>(hasError: true) => Column(
            children: <Widget>[
              const _TopBar(),
              Expanded(
                child: ErrorState(
                  title: 'No se pudo cargar el viaje',
                  message: 'El servicio no respondió. Vuelve a intentarlo.',
                  onRetry: () => ref.invalidate(tripPlanProvider(request)),
                ),
              ),
            ],
          ),
          _ => const Column(
            children: <Widget>[
              _TopBar(),
              Padding(
                padding: EdgeInsets.all(Spacing.lg),
                child: SheetSkeleton(lines: 6),
              ),
            ],
          ),
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.request,
    required this.index,
    required this.plan,
    required this.itinerary,
  });

  final TripRequest request;
  final int index;
  final TripPlan plan;
  final Itinerary itinerary;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final double mapHeight = (MediaQuery.sizeOf(context).height * 0.3).clamp(
      160,
      280,
    );
    final bool hasBus = itinerary.busLegs.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: _TopBar(
                  title: Semantics(
                    header: true,
                    child: Text(
                      '${durationLabel(itinerary.totalDuration)} · '
                      '${transfersLabel(itinerary.transferCount)}',
                      style: AppTypography.title.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
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
                    child: ItineraryMap(itinerary: itinerary),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.lg,
                  Spacing.lg,
                  Spacing.lg,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      RouteSequence(legs: itinerary.legs),
                      const SizedBox(height: Spacing.sm),
                      Text(
                        '${distanceLabel(itinerary.walkingDistance)} a pie · '
                        'las horas no cuentan la espera',
                        style: AppTypography.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.lg,
                  Spacing.xl,
                  Spacing.lg,
                  Spacing.lg,
                ),
                sliver: SliverToBoxAdapter(
                  child: ItineraryTimeline(
                    itinerary: itinerary,
                    departAt: plan.departAt,
                    leavesNow: plan.leavesNow,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (hasBus)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.lg,
              Spacing.sm,
              Spacing.lg,
              Spacing.lg,
            ),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: colors.brand,
                foregroundColor: colors.onBrand,
                minimumSize: const Size.fromHeight(
                  AppSizes.minTouchTarget + Spacing.sm,
                ),
                textStyle: AppTypography.label,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.cardRadius,
                ),
              ),
              onPressed: () => context.pushNamed(
                AppRoute.ride.name,
                pathParameters: <String, String>{AppParams.option: '$index'},
                queryParameters: request.toQuery(),
              ),
              icon: const Icon(Icons.navigation_outlined),
              label: const Text('Empezar viaje'),
            ),
          ),
      ],
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
                : context.goNamed(AppRoute.planner.name),
          ),
          const SizedBox(width: Spacing.xs),
          if (title != null) Expanded(child: title!),
        ],
      ),
    );
  }
}

/// El enlace apunta a un viaje que ya no está: la lista cambió o la petición
/// no llegó completa.
class _Gone extends StatelessWidget {
  const _Gone({required this.request});

  final TripRequest request;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const _TopBar(),
        Expanded(
          child: EmptyState(
            icon: Icons.alt_route,
            title: 'Este viaje ya no está',
            message:
                'Las opciones cambiaron desde que se abrió este enlace. '
                'Planéalo otra vez.',
            actionLabel: 'Planear de nuevo',
            onAction: () => context.goNamed(
              AppRoute.planner.name,
              queryParameters: request.toQuery(),
            ),
          ),
        ),
      ],
    );
  }
}
