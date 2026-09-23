import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/notices.dart';
import '../../../app/routes.dart';
import '../../../core/clock/clock_provider.dart';
import '../../../core/data/transit_network.dart';
import '../../../core/history/history_providers.dart';
import '../../../core/location/location_service.dart';
import '../../../core/models/models.dart';
import '../../../core/transit/vehicle_interpolator.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/colors.dart';
import '../../../design/tokens/spacing.dart';
import '../../../design/tokens/typography.dart';
import '../../favorites/application/favorites_providers.dart';
import '../../favorites/presentation/saved_stop_tile.dart';
import '../application/accessibility_filter.dart';
import '../application/leave_now.dart';
import '../application/map_providers.dart';

/// Las tres alturas de la hoja, como en la sección 8.1 del spec.
abstract final class SheetStops {
  /// Colapsada: lo justo para "¿Ya me voy?".
  static const double collapsedPixels = 120;

  static const double half = 0.45;

  static const double full = 0.9;

  /// La colapsada como fracción de [height], que es lo que pide
  /// `DraggableScrollableSheet`.
  static double collapsedFor(double height) =>
      (collapsedPixels / height).clamp(0.08, half - 0.05);

  /// Lo que ocupa la barra de búsqueda flotante, sin contar la barra de
  /// estado: su margen, su alto y un respiro abajo.
  static const double searchBarPixels = 8 + 52 + 8;

  /// La expandida: 90 %, **o** justo debajo de la barra de búsqueda si el
  /// 90 % la alcanza. En un Pixel 8 el 90 % deja 91 dp arriba y la barra con
  /// la de estado ocupa 116: la hoja le tapaba el borde.
  static double fullFor(double height, {required double topInset}) =>
      (1 - (topInset + searchBarPixels) / height).clamp(half + 0.05, full);
}

/// La hoja inferior del mapa.
///
/// **Superficie sólida con luz, sin `BackdropFilter`**: un desenfoque sobre un
/// mapa que se repinta fuerza un `saveLayer` por cuadro, el peor caso de la
/// GPU (sección 7, regla 1).
///
/// Lo que muestra depende de lo que el usuario esté mirando: nada (inicio),
/// una parada, un camión o una ruta.
class MapSheet extends ConsumerWidget {
  const MapSheet({
    required this.controller,
    required this.collapsedSize,
    required this.fullSize,
    super.key,
  });

  final DraggableScrollableController controller;
  final double collapsedSize;

  /// La altura máxima, de `SheetStops.fullFor`.
  final double fullSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MapSelection selection = ref.watch(mapSelectionStateProvider);

    return DraggableScrollableSheet(
      controller: controller,
      initialChildSize: collapsedSize,
      minChildSize: collapsedSize,
      maxChildSize: fullSize,
      snap: true,
      snapSizes: const <double>[SheetStops.half],
      builder: (BuildContext context, ScrollController scroll) => LitSurface(
        borderRadius: AppRadius.sheetRadius,
        padding: EdgeInsets.zero,
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(
            Spacing.lg,
            0,
            Spacing.lg,
            Spacing.xxxl,
          ),
          children: <Widget>[
            const _Handle(),
            switch (selection) {
              NothingSelected() => const _HomeContent(),
              StopSelected(:final String stopId) => _StopContent(
                key: ValueKey<String>('stop-$stopId'),
                stopId: stopId,
              ),
              VehicleSelected(:final String vehicleId) => _VehicleContent(
                key: ValueKey<String>('vehicle-$vehicleId'),
                vehicleId: vehicleId,
              ),
              RouteSelected(:final String routeId) => _RouteContent(
                key: ValueKey<String>('route-$routeId'),
                routeId: routeId,
              ),
            },
          ],
        ),
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Hoja de información. Arrástrala para ver más',
      child: SizedBox(
        height: Spacing.xl,
        child: Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: context.colors.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}

/// El encabezado de una vista de detalle, con su botón de cerrar.
class _DetailHeader extends ConsumerWidget {
  const _DetailHeader({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: child),
        IconButton(
          tooltip: 'Cerrar',
          onPressed: () => ref.read(mapSelectionStateProvider.notifier).clear(),
          icon: Icon(Icons.close, color: context.colors.textSecondary),
        ),
      ],
    );
  }
}

// -- Inicio ------------------------------------------------------------------

class _HomeContent extends ConsumerWidget {
  const _HomeContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = context.colors;
    final AsyncValue<List<NearbyStop>> nearby = ref.watch(nearbyStopsProvider);
    // El filtro se nombra en el título: una lista más corta sin explicación
    // parece una zona con menos paradas.
    final bool accessibleOnly =
        ref.watch(accessibleOnlyProvider).value ?? false;

    // Lo del usuario manda sobre lo cercano: si guardó una parada o si la
    // toma siempre a esta hora, está arriba y no hay que buscarla.
    final List<String> favorites =
        ref.watch(favoriteStopsProvider).value?.take(3).toList() ??
        const <String>[];
    final List<String> learned = <String>[
      for (final String stopId in ref.watch(learnedStopIdsProvider))
        if (!favorites.contains(stopId)) stopId,
    ];
    // Una parada no se repite dentro de la misma hoja: si ya está arriba, se
    // cae de "cercanas", que es la lista genérica.
    final Set<String> shown = <String>{...favorites, ...learned};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const OfflineNotice(padding: EdgeInsets.only(bottom: Spacing.md)),
        const _LeaveNowCard(),
        const SizedBox(height: Spacing.xl),
        if (favorites.isNotEmpty) ...<Widget>[
          const SectionTitle('Tus favoritos'),
          for (final String stopId in favorites)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.md),
              child: SavedStopTile(stopId: stopId),
            ),
          const SizedBox(height: Spacing.lg),
        ],
        if (learned.isNotEmpty) ...<Widget>[
          const SectionTitle('A esta hora sueles tomar'),
          for (final String stopId in learned)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.md),
              child: SavedStopTile(
                stopId: stopId,
                label: 'a esta hora sueles tomar',
                onHide: () =>
                    ref.read(hiddenSuggestionsProvider.notifier).hide(stopId),
              ),
            ),
          const SizedBox(height: Spacing.lg),
        ],
        if (nearby.value?.every((NearbyStop s) => shown.contains(s.stop.id)) !=
            true) ...<Widget>[
          Text(
            accessibleOnly ? 'Paradas accesibles cercanas' : 'Paradas cercanas',
            style: AppTypography.title.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: Spacing.md),
        ],
        switch (nearby) {
          AsyncData<List<NearbyStop>>(:final List<NearbyStop> value)
              when value.isEmpty =>
            accessibleOnly
                ? const EmptyState(
                    icon: Icons.accessible,
                    title: 'No hay paradas accesibles a 600 m',
                    message:
                        'Quita el filtro "Solo accesibles" para ver las '
                        'demás, o mueve el mapa a otra zona.',
                  )
                : const EmptyState(
                    icon: Icons.directions_walk,
                    title: 'No hay paradas a 600 m',
                    message:
                        'Busca una parada por su nombre o mueve el mapa para ver '
                        'las de otra zona.',
                  ),
          AsyncData<List<NearbyStop>>(:final List<NearbyStop> value) => Column(
            children: <Widget>[
              for (final NearbyStop stop in value)
                if (!shown.contains(stop.stop.id))
                  Padding(
                    padding: const EdgeInsets.only(bottom: Spacing.md),
                    child: _NearbyStopTile(nearby: stop),
                  ),
            ],
          ),
          AsyncError<List<NearbyStop>>() => ErrorState(
            title: 'No se pudieron cargar las paradas cercanas',
            message: 'El servicio no respondió. Vuelve a intentarlo.',
            onRetry: () => ref.invalidate(nearbyStopsProvider),
          ),
          _ => const Column(
            children: <Widget>[
              SheetSkeleton(),
              SizedBox(height: Spacing.md),
              SheetSkeleton(),
            ],
          ),
        },
      ],
    );
  }
}

class _LeaveNowCard extends ConsumerWidget {
  const _LeaveNowCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = context.colors;
    final AsyncValue<LeaveNowAdvice?> advice = ref.watch(leaveNowProvider);
    final UserLocation? location = ref.watch(userLocationProvider).value;

    final TextStyle headlineStyle = AppTypography.etaDisplay.copyWith(
      fontSize: 34,
      letterSpacing: -0.68,
      color: colors.textPrimary,
    );
    final TextStyle detailStyle = AppTypography.caption.copyWith(
      color: colors.textSecondary,
    );

    Widget lines(String headline, String detail, {Color? headlineColor}) =>
        Semantics(
          liveRegion: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                headline,
                style: headlineStyle.copyWith(color: headlineColor),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: Spacing.xs),
              Text(
                detail,
                style: detailStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );

    if (location != null && location.isFallback) {
      return lines(
        '¿Ya me voy?',
        'Sin tu ubicación no sé cuánto caminas. Toca el botón de ubicación '
            'para intentarlo.',
        headlineColor: colors.textSecondary,
      );
    }

    return switch (advice) {
      AsyncData<LeaveNowAdvice?>(:final LeaveNowAdvice? value)
          when value == null =>
        lines(
          '¿Ya me voy?',
          'No pasa ninguna ruta por las paradas a 600 m de ti.',
          headlineColor: colors.textSecondary,
        ),
      AsyncData<LeaveNowAdvice?>(:final LeaveNowAdvice? value) => lines(
        value!.headline,
        value.detail,
        // Sin cuenta regresiva no hay número que resaltar: se apaga igual que
        // la tira.
        headlineColor: value.isCountdown || value is LeaveBySchedule
            ? colors.textPrimary
            : colors.textSecondary,
      ),
      AsyncError<LeaveNowAdvice?>() => Row(
        children: <Widget>[
          Expanded(
            child: lines(
              '¿Ya me voy?',
              'No se pudieron cargar los arribos de tu parada.',
              headlineColor: colors.textSecondary,
            ),
          ),
          TextButton(
            onPressed: () => ref.invalidate(leaveNowProvider),
            child: const Text('Reintentar'),
          ),
        ],
      ),
      _ => const SheetSkeleton(lines: 2),
    };
  }
}

class _NearbyStopTile extends ConsumerWidget {
  const _NearbyStopTile({required this.nearby});

  final NearbyStop nearby;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Stop stop = nearby.stop;
    final AsyncValue<List<Arrival>> arrivals = ref.watch(
      stopArrivalsProvider(stop.id),
    );
    final TransitNetwork? network = ref.watch(transitNetworkProvider).value;
    final String distance =
        'a ${_meters(nearby.meters)} · ${nearby.walk.inMinutes.clamp(1, 99)} '
        'min a pie';

    return switch (arrivals) {
      AsyncData<List<Arrival>>(:final List<Arrival> value) => StopTile(
        name: stop.name,
        code: stop.code,
        arrivals: value,
        distanceLabel: distance,
        accessibility: stop.wheelchairBoarding,
        routeOf: network?.route,
        onTap: () => ref
            .read(mapSelectionStateProvider.notifier)
            .select(StopSelected(stop.id)),
      ),
      AsyncError<List<Arrival>>() => _InlineError(
        title: stop.name,
        onRetry: () => ref.invalidate(stopArrivalsProvider(stop.id)),
      ),
      _ => const SheetSkeleton(),
    };
  }
}

// -- Parada ------------------------------------------------------------------

class _StopContent extends ConsumerWidget {
  const _StopContent({required this.stopId, super.key});

  final String stopId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TransitNetwork? network = ref.watch(transitNetworkProvider).value;
    final Stop? stop = network?.stop(stopId);
    final AsyncValue<List<Arrival>> arrivals = ref.watch(
      stopArrivalsProvider(stopId),
    );

    if (stop == null) {
      return const SheetSkeleton();
    }

    return _DetailHeader(
      child: switch (arrivals) {
        AsyncData<List<Arrival>>(:final List<Arrival> value) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            StopTile(
              name: stop.name,
              code: stop.code,
              arrivals: value,
              accessibility: stop.wheelchairBoarding,
              maxArrivals: 12,
              routeOf: network?.route,
              // Con doce arribos el enlace de abajo queda fuera de la
              // pantalla: la tarjeta entera también abre la parada.
              onTap: () => context.pushNamed(
                AppRoute.stop.name,
                pathParameters: <String, String>{AppParams.stopId: stop.id},
              ),
            ),
            _OpenLink(
              label: 'Ver parada',
              route: AppRoute.stop,
              params: <String, String>{AppParams.stopId: stop.id},
            ),
          ],
        ),
        AsyncError<List<Arrival>>() => ErrorState(
          title: 'No se pudieron cargar los arribos de ${stop.name}',
          message: 'El servicio no respondió. Vuelve a intentarlo.',
          onRetry: () => ref.invalidate(stopArrivalsProvider(stopId)),
        ),
        _ => const SheetSkeleton(lines: 4),
      },
    );
  }
}

// -- Camión ------------------------------------------------------------------

/// El callout del camión es la firma de la app: la tira con luz de recorrido.
///
/// La sección 8.1 pide ruta, destino y próxima parada. `RouteStrip` ya dibuja
/// exactamente eso —el camión entre sus paradas— y se apaga sola cuando el
/// dato vence.
class _VehicleContent extends ConsumerStatefulWidget {
  const _VehicleContent({required this.vehicleId, super.key});

  final String vehicleId;

  /// Cuántas paradas se ven en la tira: las dos de atrás y las cinco que
  /// siguen. Una ruta entera son 60 marcas que no se distinguen.
  static const int behind = 2;
  static const int ahead = 5;

  @override
  ConsumerState<_VehicleContent> createState() => _VehicleContentState();
}

class _VehicleContentState extends ConsumerState<_VehicleContent> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    // La edad del reporte crece sola; la tira tiene que apagarse a tiempo.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final VehicleInterpolator tracker = ref.watch(vehicleTrackerProvider);
    final TransitNetwork? network = ref.watch(transitNetworkProvider).value;
    final VehiclePosition? vehicle = tracker.vehicleOf(widget.vehicleId);

    if (network == null) {
      return const SheetSkeleton(lines: 3);
    }
    if (vehicle == null) {
      return EmptyState(
        icon: Icons.signal_cellular_connected_no_internet_0_bar,
        title: 'Este camión dejó de reportar',
        message:
            'Lleva más de 10 minutos sin señal. Toca otro camión o busca su '
            'ruta.',
        actionLabel: 'Cerrar',
        onAction: () => ref.read(mapSelectionStateProvider.notifier).clear(),
      );
    }

    final TransitRoute? route = network.route(vehicle.routeId);
    final Trip? trip = network.trip(vehicle.tripId);
    final List<Stop> stops = network.stopsForTrip(vehicle.tripId);
    final Duration age = vehicle.ageAt(ref.watch(clockProvider)());

    // La última parada por la que pasó. `current_stop_sequence` cuenta desde 1.
    final int passed = ((vehicle.currentStopSequence ?? 1) - 1).clamp(
      0,
      stops.isEmpty ? 0 : stops.length - 1,
    );
    final int start = (passed - _VehicleContent.behind).clamp(0, stops.length);
    final int end = (passed + _VehicleContent.ahead + 1).clamp(0, stops.length);
    final List<Stop> window = stops.sublist(start, end);
    final Stop? next = passed + 1 < stops.length ? stops[passed + 1] : null;
    // A la mitad del tramo entre la que pasó y la que sigue: es lo que se
    // sabe. Más precisión que esa sería inventada.
    final double progress = window.length < 2
        ? 0
        : ((passed - start) + 0.5) / (window.length - 1);

    return _DetailHeader(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              RouteBadge(
                shortName: route?.shortName ?? vehicle.routeId,
                routeId: vehicle.routeId,
                gtfsColor: route?.color,
                gtfsTextColor: route?.textColor,
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Text(
                  trip == null
                      ? 'Destino desconocido'
                      : 'Hacia ${trip.headsign}',
                  style: AppTypography.title.copyWith(
                    color: colors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            next == null
                ? 'Llegando a su última parada'
                : 'Próxima parada: ${next.name}',
            style: AppTypography.body.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: Spacing.lg),
          if (window.length >= 2)
            RouteStrip(
              stops: <String>[for (final Stop stop in window) stop.name],
              vehicleProgress: progress,
              dataAge: age,
            ),
          _OpenLink(
            label: 'Ver ruta',
            route: AppRoute.route,
            params: <String, String>{AppParams.routeId: vehicle.routeId},
          ),
        ],
      ),
    );
  }
}

// -- Ruta --------------------------------------------------------------------

class _RouteContent extends ConsumerWidget {
  const _RouteContent({required this.routeId, super.key});

  final String routeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = context.colors;
    final TransitNetwork? network = ref.watch(transitNetworkProvider).value;
    final VehicleInterpolator tracker = ref.watch(vehicleTrackerProvider);
    // Para recontar cuando llega un lote.
    ref.watch(vehicleFeedProvider);

    final TransitRoute? route = network?.route(routeId);
    if (network == null || route == null) {
      return const SheetSkeleton(lines: 3);
    }

    final int running = tracker
        .frameAt(ref.watch(clockProvider)(), interpolate: false)
        .where((VehicleFrame f) => f.vehicle.routeId == routeId)
        .length;
    final List<String> headsigns = <String>{
      for (final Trip trip in network.tripsForRoute(routeId)) trip.headsign,
    }.toList();

    return _DetailHeader(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
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
                  style: AppTypography.title.copyWith(
                    color: colors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          // Una ruta sin camiones se dice con todas sus letras, no con un mapa
          // vacío (sección 8.3).
          Text(
            running == 0
                ? 'Ningún camión de esta ruta está reportando ahora.'
                : running == 1
                ? '1 camión reportando'
                : '$running camiones reportando',
            style: AppTypography.body.copyWith(
              color: running == 0 ? colors.stale : colors.textSecondary,
            ),
          ),
          if (headsigns.isNotEmpty) ...<Widget>[
            const SizedBox(height: Spacing.xs),
            Text(
              'Va hacia ${headsigns.join(' y ')}',
              style: AppTypography.caption.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
          _OpenLink(
            label: 'Ver ruta',
            route: AppRoute.route,
            params: <String, String>{AppParams.routeId: route.id},
          ),
        ],
      ),
    );
  }
}

// -- Piezas ------------------------------------------------------------------

/// El paso de la hoja a la pantalla completa de la parada o de la ruta.
class _OpenLink extends StatelessWidget {
  const _OpenLink({
    required this.label,
    required this.route,
    required this.params,
  });

  final String label;
  final AppRoute route;
  final Map<String, String> params;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: Spacing.sm),
        child: TextButton.icon(
          onPressed: () =>
              context.pushNamed(route.name, pathParameters: params),
          icon: const Icon(Icons.arrow_forward, size: 18),
          label: Text(label),
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.title, required this.onRetry});

  final String title;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: AppTypography.label.copyWith(color: colors.textPrimary),
              ),
              Text(
                'No se pudieron cargar sus arribos.',
                style: AppTypography.caption.copyWith(color: colors.alert),
              ),
            ],
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Reintentar')),
      ],
    );
  }
}

String _meters(double meters) => meters < 1000
    ? '${(meters / 10).round() * 10} m'
    : '${(meters / 1000).toStringAsFixed(1)} km';
