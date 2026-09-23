import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/notices.dart';
import '../../../app/routes.dart';
import '../../../core/clock/clock_provider.dart';
import '../../../core/data/transit_network.dart';
import '../../../core/location/location_service.dart';
import '../../../core/models/models.dart';
import '../../../core/transit/live_providers.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/colors.dart';
import '../../../design/tokens/spacing.dart';
import '../../../design/tokens/typography.dart';
import '../../map/presentation/accessible_only_chip.dart';
import '../application/no_route_help.dart';
import '../application/planner_providers.dart';
import '../application/trip_request.dart';
import 'itinerary_card.dart';
import 'place_picker.dart';

/// Planificador de viaje, como en la sección 8.4 del spec: "cómo llego de A
/// a B", y responder bien también cuando no hay respuesta.
///
/// La petición vive en la URL. Cambiar un campo reemplaza la página con la
/// petición nueva, así que el resultado se puede abrir por enlace y el botón
/// de volver regresa a donde se estaba antes de planear.
class PlannerScreen extends ConsumerStatefulWidget {
  const PlannerScreen({required this.request, super.key});

  final TripRequest request;

  @override
  ConsumerState<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends ConsumerState<PlannerScreen> {
  /// "Mostrarlas de todos modos": ver las opciones que el filtro escondió,
  /// solo esta vez. No cambia el interruptor guardado.
  bool _showHidden = false;

  @override
  void didUpdateWidget(PlannerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request != widget.request) {
      _showHidden = false;
    }
  }

  void _replace(TripRequest request) => context.replaceNamed(
    AppRoute.planner.name,
    queryParameters: request.toQuery(),
  );

  Future<void> _pickFrom() async {
    final PlaceRef? place = await showPlacePicker(
      context,
      title: '¿De dónde sales?',
    );
    if (place != null && mounted) {
      _replace(widget.request.withFrom(place));
    }
  }

  Future<void> _pickTo() async {
    final PlaceRef? place = await showPlacePicker(
      context,
      title: '¿A dónde vas?',
    );
    if (place != null && mounted) {
      _replace(widget.request.withTo(place));
    }
  }

  Future<void> _pickTime() async {
    final int? current = widget.request.departMinutes;
    final DateTime now = ref.read(clockProvider)();
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      helpText: 'Hora de salida',
      cancelText: 'Cancelar',
      confirmText: 'Listo',
      initialTime: current == null
          ? TimeOfDay.fromDateTime(now)
          : TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (picked != null && mounted) {
      _replace(
        widget.request.withDepartMinutes(picked.hour * 60 + picked.minute),
      );
    }
  }

  void _openOption(int index) => context.pushNamed(
    AppRoute.plannerOption.name,
    pathParameters: <String, String>{AppParams.option: '$index'},
    queryParameters: widget.request.toQuery(),
  );

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final TripRequest request = widget.request;
    final TransitNetwork? network = ref.watch(transitNetworkProvider).value;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.xs,
                  0,
                  Spacing.lg,
                  0,
                ),
                child: Row(
                  children: <Widget>[
                    IconButton(
                      tooltip: 'Volver',
                      icon: Icon(Icons.arrow_back, color: colors.textPrimary),
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.goNamed(AppRoute.map.name),
                    ),
                    const SizedBox(width: Spacing.xs),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          'Cómo llego',
                          style: AppTypography.title.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: OfflineNotice(
                padding: EdgeInsets.fromLTRB(
                  Spacing.lg,
                  Spacing.sm,
                  Spacing.lg,
                  0,
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
                child: _PlaceFields(
                  from: request.from == null
                      ? null
                      : placeLabel(request.from!, network),
                  to: request.to == null
                      ? null
                      : placeLabel(request.to!, network),
                  onFrom: _pickFrom,
                  onTo: _pickTo,
                  onSwap: request.from == null && request.to == null
                      ? null
                      : () => _replace(request.swapped()),
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
                child: Wrap(
                  spacing: Spacing.sm,
                  runSpacing: Spacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    _DepartChip(
                      minutes: request.departMinutes,
                      onPick: _pickTime,
                      onNow: request.leavesNow
                          ? null
                          : () => _replace(request.withDepartMinutes(null)),
                    ),
                    const AccessibleOnlyChip(
                      onMessage:
                          'Mostrando solo viajes que suben y bajan en paradas '
                          'verificadas como accesibles',
                      offMessage:
                          'Ocultar los viajes con paradas que no están '
                          'verificadas como accesibles',
                    ),
                  ],
                ),
              ),
            ),
            ..._results(context, request),
            const SliverToBoxAdapter(child: SizedBox(height: Spacing.xxxl)),
          ],
        ),
      ),
    );
  }

  List<Widget> _results(BuildContext context, TripRequest request) {
    if (!request.isComplete) {
      return <Widget>[
        SliverToBoxAdapter(
          child: EmptyState(
            icon: Icons.directions_outlined,
            title: request.from == null ? '¿De dónde sales?' : '¿A dónde vas?',
            message:
                'Elige una parada o el destino de una ruta. Como origen '
                'también sirve tu ubicación.',
            actionLabel: request.from == null
                ? 'Elegir el origen'
                : 'Elegir el destino',
            onAction: request.from == null ? _pickFrom : _pickTo,
          ),
        ),
      ];
    }

    final AsyncValue<TripPlan> plan = ref.watch(tripPlanProvider(request));
    return switch (plan) {
      AsyncValue<TripPlan>(:final TripPlan value?) => _plan(context, value),
      AsyncValue<TripPlan>(
        error: OriginUnavailable(:final LocationIssue issue),
      ) =>
        <Widget>[
          SliverToBoxAdapter(
            child: EmptyState(
              icon: Icons.location_disabled_outlined,
              title: 'No sé dónde estás',
              message: switch (issue) {
                LocationIssue.serviceDisabled =>
                  'La ubicación del teléfono está apagada. Elige una parada '
                      'como origen.',
                LocationIssue.denied || LocationIssue.deniedForever =>
                  'Yo Voy Go no tiene permiso de ubicación. Elige una parada '
                      'como origen.',
                LocationIssue.unavailable =>
                  'El teléfono no respondió con tu ubicación. Elige una '
                      'parada como origen.',
              },
              actionLabel: 'Elegir una parada',
              onAction: request.from is HerePlace ? _pickFrom : _pickTo,
            ),
          ),
        ],
      AsyncValue<TripPlan>(error: PlaceNotFound(:final String id)) => <Widget>[
        SliverToBoxAdapter(
          child: EmptyState(
            icon: Icons.wrong_location_outlined,
            title: 'Esa parada no existe',
            message: 'No hay ninguna parada con el código $id. Elige otra.',
            actionLabel: 'Elegir otra',
            onAction: request.from == StopPlace(id) ? _pickFrom : _pickTo,
          ),
        ),
      ],
      AsyncValue<TripPlan>(hasError: true) => <Widget>[
        SliverToBoxAdapter(
          child: ErrorState(
            title: 'No se pudo planear el viaje',
            message: 'El servicio no respondió. Vuelve a intentarlo.',
            onRetry: () => ref.invalidate(tripPlanProvider(request)),
          ),
        ),
      ],
      _ => const <Widget>[
        SliverPadding(
          padding: EdgeInsets.all(Spacing.lg),
          sliver: SliverToBoxAdapter(child: SheetSkeleton(lines: 6)),
        ),
      ],
    };
  }

  List<Widget> _plan(BuildContext context, TripPlan plan) {
    final AppColors colors = context.colors;
    if (plan.ranked.isEmpty) {
      return <Widget>[SliverToBoxAdapter(child: _NoRoute(plan: plan))];
    }

    final List<(int, Itinerary)> shown = _showHidden
        ? <(int, Itinerary)>[
            for (int i = 0; i < plan.ranked.length; i++) (i, plan.ranked[i]),
          ]
        : plan.visible;
    final int hidden = plan.hiddenByAccessibility;

    if (shown.isEmpty) {
      return <Widget>[
        SliverToBoxAdapter(
          child: EmptyState(
            icon: Icons.accessible,
            title: 'Ningún viaje es accesible de punta a punta',
            message: hidden == 1
                ? 'Hay 1 opción, pero sube o baja en una parada que no está '
                      'verificada como accesible.'
                : 'Hay $hidden opciones, pero todas suben o bajan en alguna '
                      'parada que no está verificada como accesible.',
            actionLabel: hidden == 1
                ? 'Mostrarla'
                : 'Mostrarlas de todos modos',
            onAction: () => setState(() => _showHidden = true),
          ),
        ),
      ];
    }

    return <Widget>[
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.lg,
          Spacing.lg,
          Spacing.lg,
          Spacing.sm,
        ),
        sliver: SliverToBoxAdapter(
          child: Text(
            <String>[
              if (shown.length == 1)
                '1 forma de llegar'
              else
                '${shown.length} formas de llegar',
              'primero la más sencilla',
              if (hidden > 0 && !_showHidden)
                hidden == 1
                    ? '1 oculta por accesibilidad'
                    : '$hidden ocultas por accesibilidad',
            ].join(' · '),
            style: AppTypography.label.copyWith(color: colors.textPrimary),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
        sliver: SliverList.separated(
          itemCount: shown.length,
          separatorBuilder: (BuildContext context, int _) =>
              const SizedBox(height: Spacing.md),
          itemBuilder: (BuildContext context, int i) {
            final (int index, Itinerary itinerary) = shown[i];
            return ItineraryCard(
              itinerary: itinerary,
              departAt: plan.departAt,
              position: i + 1,
              showBoarding: i == 0 && plan.leavesNow,
              onTap: () => _openOption(index),
            );
          },
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.lg,
          Spacing.md,
          Spacing.lg,
          0,
        ),
        sliver: SliverToBoxAdapter(
          child: Text(
            'Las horas no cuentan la espera en la parada: esa depende del '
            'camión, y se ve en vivo al abrir cada opción.',
            style: AppTypography.caption.copyWith(color: colors.textSecondary),
          ),
        ),
      ),
    ];
  }
}

/// Origen y destino, con el botón para intercambiarlos.
class _PlaceFields extends StatelessWidget {
  const _PlaceFields({
    required this.from,
    required this.to,
    required this.onFrom,
    required this.onTo,
    required this.onSwap,
  });

  final String? from;
  final String? to;
  final VoidCallback onFrom;
  final VoidCallback onTo;
  final VoidCallback? onSwap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            children: <Widget>[
              _Field(
                icon: Icons.trip_origin,
                label: 'Desde',
                value: from,
                hint: 'Elige de dónde sales',
                onTap: onFrom,
              ),
              const SizedBox(height: Spacing.sm),
              _Field(
                icon: Icons.flag_outlined,
                label: 'Hacia',
                value: to,
                hint: 'Elige a dónde vas',
                onTap: onTo,
              ),
            ],
          ),
        ),
        const SizedBox(width: Spacing.xs),
        IconButton(
          tooltip: 'Intercambiar origen y destino',
          onPressed: onSwap,
          icon: Icon(Icons.swap_vert, color: context.colors.textPrimary),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.icon,
    required this.label,
    required this.value,
    required this.hint,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String? value;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Semantics(
      button: true,
      label: '$label: ${value ?? 'sin elegir'}',
      excludeSemantics: true,
      child: Material(
        color: colors.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardRadius,
          side: BorderSide(color: colors.outline),
        ),
        child: InkWell(
          borderRadius: AppRadius.cardRadius,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSizes.minTouchTarget + Spacing.xs,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: Spacing.sm,
              ),
              child: Row(
                children: <Widget>[
                  Icon(icon, size: 20, color: colors.textSecondary),
                  const SizedBox(width: Spacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          label,
                          style: AppTypography.caption.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        Text(
                          value ?? hint,
                          style: AppTypography.label.copyWith(
                            color: value == null
                                ? colors.textSecondary
                                : colors.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Salir ahora" o "Salir a las 8:30".
class _DepartChip extends StatelessWidget {
  const _DepartChip({
    required this.minutes,
    required this.onPick,
    required this.onNow,
  });

  final int? minutes;
  final VoidCallback onPick;

  /// Volver a "ahora". `null` si ya es ahora.
  final VoidCallback? onNow;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final int? at = minutes;
    return InputChip(
      avatar: Icon(Icons.schedule, size: 18, color: colors.textSecondary),
      label: Text(
        at == null ? 'Salir ahora' : 'Salir a las ${TripRequest.timeLabel(at)}',
      ),
      labelStyle: AppTypography.label.copyWith(color: colors.textPrimary),
      tooltip: 'Cambiar la hora de salida',
      onPressed: onPick,
      onDeleted: onNow,
      deleteButtonTooltipMessage: 'Salir ahora',
      deleteIconColor: colors.textSecondary,
      backgroundColor: colors.surfaceRaised,
      side: BorderSide(color: colors.outline),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.chipRadius),
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}

/// "No encontré ruta", con salida útil: nunca un callejón (§8.4).
class _NoRoute extends StatelessWidget {
  const _NoRoute({required this.plan});

  final TripPlan plan;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final NoRouteHelp? help = plan.help;
    final ClosestReach? reach = help?.reach;
    final List<NearbyRoute> near = help?.nearOrigin ?? const <NearbyRoute>[];

    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.xl, Spacing.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              'No encontré un camión de ${plan.from.label} a ${plan.to.label}',
              style: AppTypography.title.copyWith(color: colors.textPrimary),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            near.isEmpty
                ? 'Ningún camión pasa a menos de '
                      '${distanceLabel(nearbyMeters)} de tu origen. Prueba '
                      'desde una parada.'
                : 'Esto es lo que sí puedes hacer desde ahí.',
            style: AppTypography.body.copyWith(color: colors.textSecondary),
          ),
          if (reach != null) ...<Widget>[
            const SizedBox(height: Spacing.lg),
            _ReachCard(reach: reach),
          ],
          if (near.isNotEmpty) ...<Widget>[
            const SizedBox(height: Spacing.xl),
            Semantics(
              header: true,
              child: Text(
                'Pasan cerca de tu origen',
                style: AppTypography.label.copyWith(color: colors.textPrimary),
              ),
            ),
            const SizedBox(height: Spacing.sm),
            for (final NearbyRoute route in near) _NearbyRouteRow(route: route),
          ] else ...<Widget>[
            const SizedBox(height: Spacing.lg),
            FilledButton.icon(
              onPressed: () => context.goNamed(AppRoute.map.name),
              icon: const Icon(Icons.map_outlined),
              label: const Text('Ver las rutas en el mapa'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReachCard extends StatelessWidget {
  const _ReachCard({required this.reach});

  final ClosestReach reach;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final String text =
        'Con la ${reach.route.shortName} llegas a '
        '${distanceLabel(reach.remainingMeters)} de tu destino, en '
        '${reach.alight.name}.';
    return Semantics(
      button: true,
      label: '$text Súbete en ${reach.board.name}. Ver la parada.',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.cardRadius,
          onTap: () => context.pushNamed(
            AppRoute.stop.name,
            pathParameters: <String, String>{AppParams.stopId: reach.alight.id},
          ),
          child: LitSurface(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                RouteBadge(
                  shortName: reach.route.shortName,
                  routeId: reach.route.id,
                  gtfsColor: reach.route.color,
                  gtfsTextColor: reach.route.textColor,
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        text,
                        style: AppTypography.body.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: Spacing.xs),
                      Text(
                        'Súbete en ${reach.board.name}',
                        style: AppTypography.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: colors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NearbyRouteRow extends StatelessWidget {
  const _NearbyRouteRow({required this.route});

  final NearbyRoute route;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    // Si el origen es la parada misma, "a 50 m" no dice nada.
    final String where = route.meters < 25
        ? 'en ${route.stop.name}'
        : 'a ${distanceLabel(route.meters)}, en ${route.stop.name}';
    return Semantics(
      button: true,
      label:
          '${route.route.shortName}, ${route.route.longName}, $where. '
          'Ver la ruta.',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => context.pushNamed(
          AppRoute.route.name,
          pathParameters: <String, String>{AppParams.routeId: route.route.id},
          queryParameters: <String, String>{AppParams.fromStop: route.stop.id},
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTouchTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
            child: Row(
              children: <Widget>[
                RouteBadge(
                  shortName: route.route.shortName,
                  routeId: route.route.id,
                  gtfsColor: route.route.color,
                  gtfsTextColor: route.route.textColor,
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        route.route.longName,
                        style: AppTypography.label.copyWith(
                          color: colors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        where,
                        style: AppTypography.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: colors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
