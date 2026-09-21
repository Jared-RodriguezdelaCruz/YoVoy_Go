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
import '../../favorites/application/favorites_providers.dart';
import '../application/stop_providers.dart';

/// Detalle de parada, como en la sección 8.2 del spec.
///
/// Se lee como el letrero del paradero: el nombre grande, lo que avisa el
/// operador debajo y los camiones por orden de llegada. Cada fila abre su
/// ruta.
class StopScreen extends ConsumerWidget {
  const StopScreen({required this.stopId, super.key});

  final String stopId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = context.colors;
    final AsyncValue<Stop> stop = ref.watch(stopDetailProvider(stopId));

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        bottom: false,
        child: switch (stop) {
          AsyncValue<Stop>(:final Stop value?) => _StopBoard(stop: value),
          AsyncValue<Stop>(error: StopNotFound()) => _Missing(stopId: stopId),
          AsyncValue<Stop>(hasError: true) => Column(
            children: <Widget>[
              const _TopBar(),
              Expanded(
                child: ErrorState(
                  title: 'No se pudo cargar la parada',
                  message: 'El servicio no respondió. Vuelve a intentarlo.',
                  onRetry: () => ref.invalidate(stopDetailProvider(stopId)),
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

class _StopBoard extends ConsumerWidget {
  const _StopBoard({required this.stop});

  final Stop stop;

  Future<void> _refresh(WidgetRef ref) async {
    try {
      final List<Arrival> _ = await ref.refresh(
        stopArrivalsProvider(stop.id).future,
      );
    } on Object {
      // El error ya queda en el estado del provider y la pantalla lo pinta.
      // Aquí solo se cierra el indicador.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = context.colors;
    final AsyncValue<List<Arrival>> arrivals = ref.watch(
      stopArrivalsProvider(stop.id),
    );
    // Las alertas son un extra: si fallan, la parada se sigue viendo sin
    // ellas. El error de los arribos sí se dice.
    final List<ServiceAlert> alerts =
        ref.watch(stopAlertsProvider(stop.id)).value ?? const <ServiceAlert>[];
    final TransitNetwork? network = ref.watch(transitNetworkProvider).value;
    final bool isFavorite =
        ref.watch(favoriteStopsProvider).value?.contains(stop.id) ?? false;

    return RefreshIndicator(
      color: colors.brand,
      backgroundColor: colors.surfaceRaised,
      onRefresh: () => _refresh(ref),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: Spacing.xxxl),
        children: <Widget>[
          _TopBar(
            trailing: IconButton(
              tooltip: isFavorite
                  ? 'Quitar de favoritos'
                  : 'Guardar en favoritos',
              onPressed: () =>
                  ref.read(favoriteStopsProvider.notifier).toggle(stop.id),
              icon: Icon(
                isFavorite ? Icons.star : Icons.star_border,
                // Cantera: el favorito lo decidió el usuario, no el sistema.
                color: isFavorite ? colors.cantera : colors.textSecondary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
            child: _Header(
              stop: stop,
              routeCount: network?.routesForStop(stop.id).length,
              arrivals: arrivals.value,
            ),
          ),
          for (final ServiceAlert alert in alerts)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.lg,
                Spacing.md,
                Spacing.lg,
                0,
              ),
              child: AlertBanner.fromAlert(alert),
            ),
          const SizedBox(height: Spacing.xl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
            child: Text(
              'Próximos camiones',
              style: AppTypography.label.copyWith(color: colors.textSecondary),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          ..._arrivalRows(context, ref, arrivals, network),
        ],
      ),
    );
  }

  List<Widget> _arrivalRows(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Arrival>> arrivals,
    TransitNetwork? network,
  ) {
    const EdgeInsets inset = EdgeInsets.symmetric(horizontal: Spacing.lg);
    final List<Arrival>? rows = arrivals.value;

    if (rows == null) {
      if (arrivals.hasError) {
        return <Widget>[
          Padding(
            padding: inset,
            child: ErrorState(
              title: 'No se pudieron cargar los arribos',
              message:
                  'El servicio no respondió. Desliza hacia abajo o '
                  'vuelve a intentarlo.',
              onRetry: () => ref.invalidate(stopArrivalsProvider(stop.id)),
            ),
          ),
        ];
      }
      return <Widget>[
        for (int i = 0; i < 4; i++)
          const Padding(
            padding: EdgeInsets.fromLTRB(
              Spacing.lg,
              Spacing.md,
              Spacing.lg,
              Spacing.md,
            ),
            child: SheetSkeleton(lines: 2),
          ),
      ];
    }

    if (rows.isEmpty) {
      return const <Widget>[
        Padding(
          padding: inset,
          child: EmptyState(
            icon: Icons.departure_board,
            title: 'Sin camiones en camino ahora',
            message:
                'Hoy no hay servicio programado por esta parada a esta hora. '
                'Busca otra parada cercana en el mapa.',
          ),
        ),
      ];
    }

    return <Widget>[
      // Si el último refresco falló, lo que se ve es el dato anterior. Se
      // dice, y los chips ya se apagan solos con la edad.
      if (arrivals.hasError)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.lg,
            0,
            Spacing.lg,
            Spacing.sm,
          ),
          child: Text(
            'No se pudo actualizar. Estos son los últimos arribos que llegaron.',
            style: AppTypography.caption.copyWith(color: context.colors.alert),
          ),
        ),
      for (final Arrival arrival in rows)
        _ArrivalRow(arrival: arrival, route: network?.route(arrival.routeId)),
    ];
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({this.trailing});

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: 'Volver',
            icon: Icon(Icons.arrow_back, color: context.colors.textPrimary),
            onPressed: () => context.canPop()
                ? context.pop()
                : context.goNamed(AppRoute.map.name),
          ),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

/// El letrero: el nombre en el ancho condensado de los datos, y debajo lo
/// que la distingue.
class _Header extends StatelessWidget {
  const _Header({
    required this.stop,
    required this.routeCount,
    required this.arrivals,
  });

  final Stop stop;
  final int? routeCount;
  final List<Arrival>? arrivals;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    // La edad del dato en vivo más reciente: eso es lo que sabe la parada.
    final Duration? freshest = arrivals
        ?.where((Arrival a) => a.confidence == EtaConfidence.live)
        .map((Arrival a) => a.dataAge)
        .fold<Duration?>(
          null,
          (Duration? best, Duration age) =>
              best == null || age < best ? age : best,
        );

    final List<String> facts = <String>[
      if (stop.code case final String code) 'Parada $code',
      if (routeCount case final int count when count > 0)
        count == 1 ? 'Pasa 1 ruta' : 'Pasan $count rutas',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            stop.name,
            style: AppTypography.routeBadge.copyWith(
              fontSize: 32,
              height: 1.1,
              letterSpacing: -0.3,
              color: colors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: Spacing.sm),
        Wrap(
          spacing: Spacing.md,
          runSpacing: Spacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            if (facts.isNotEmpty)
              Text(
                facts.join(' · '),
                style: AppTypography.caption.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            if (stop.wheelchairBoarding == WheelchairBoarding.accessible)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.accessible, size: 16, color: colors.textSecondary),
                  const SizedBox(width: 2),
                  Text(
                    'Accesible',
                    style: AppTypography.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            if (freshest != null) FreshnessIndicator(dataAge: freshest),
          ],
        ),
      ],
    );
  }
}

/// Una fila del letrero: placa, destino y el chip grande. Toda la fila abre
/// la ruta.
class _ArrivalRow extends StatelessWidget {
  const _ArrivalRow({required this.arrival, required this.route});

  final Arrival arrival;
  final TransitRoute? route;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final bool stacked =
        MediaQuery.textScalerOf(context).scale(AppTypography.body.fontSize!) >
        22;

    final Widget badge = RouteBadge(
      shortName: arrival.routeShortName,
      routeId: arrival.routeId,
      gtfsColor: route?.color,
      gtfsTextColor: route?.textColor,
    );
    final Widget headsign = Text(
      'Hacia ${arrival.headsign}',
      style: AppTypography.body.copyWith(color: colors.textPrimary),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
    final Widget chip = EtaChip.fromArrival(arrival, size: EtaChipSize.large);

    return Semantics(
      button: true,
      label: '${arrivalAnnouncement(arrival)}. Ver la ruta',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => context.pushNamed(
          AppRoute.route.name,
          pathParameters: <String, String>{AppParams.routeId: arrival.routeId},
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg,
            vertical: Spacing.md,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: colors.outline,
                width: AppSizes.outlineWidth,
              ),
            ),
          ),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    badge,
                    const SizedBox(height: Spacing.sm),
                    headsign,
                    const SizedBox(height: Spacing.sm),
                    chip,
                  ],
                )
              : Row(
                  children: <Widget>[
                    badge,
                    const SizedBox(width: Spacing.md),
                    Expanded(child: headsign),
                    const SizedBox(width: Spacing.sm),
                    chip,
                  ],
                ),
        ),
      ),
    );
  }
}

class _Missing extends StatelessWidget {
  const _Missing({required this.stopId});

  final String stopId;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const _TopBar(),
        Expanded(
          child: EmptyState(
            icon: Icons.wrong_location_outlined,
            title: 'Esta parada no existe',
            message:
                'No hay ninguna parada con el código $stopId. Búscala por su '
                'nombre en el mapa.',
            actionLabel: 'Ir al mapa',
            onAction: () => context.goNamed(AppRoute.map.name),
          ),
        ),
      ],
    );
  }
}

/// La forma del letrero mientras llega: título, una línea y cuatro filas.
class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        const _TopBar(),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: Spacing.lg),
          child: SheetSkeleton(lines: 2),
        ),
        const SizedBox(height: Spacing.xl),
        for (int i = 0; i < 4; i++)
          const Padding(
            padding: EdgeInsets.fromLTRB(
              Spacing.lg,
              Spacing.md,
              Spacing.lg,
              Spacing.md,
            ),
            child: SheetSkeleton(lines: 2),
          ),
      ],
    );
  }
}
