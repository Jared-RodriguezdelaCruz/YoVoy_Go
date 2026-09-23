import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/data/not_found.dart';
import '../../../core/device/screen_awake.dart';
import '../../../core/history/history_providers.dart';
import '../../../core/history/observation.dart';
import '../../../core/lifecycle/app_lifecycle_provider.dart';
import '../../../core/models/models.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/colors.dart';
import '../../../design/tokens/max_contrast.dart';
import '../../../design/tokens/spacing.dart';
import '../../../design/tokens/typography.dart';
import '../../stop/application/stop_board.dart';
import '../application/leg_timing.dart';
import '../application/no_route_help.dart';
import '../application/planner_providers.dart';
import '../application/ride_session.dart';
import '../application/trip_request.dart';
import 'itinerary_timeline.dart';

/// Modo viaje, la feature 5 de `FEATURES.md`: vas a bordo en una ruta que no
/// conoces y no sabes cuándo bajarte.
///
/// Sigue al camión en el que vas, no al GPS. La pantalla se queda encendida
/// mientras dure el viaje: con la app en segundo plano todo se detiene (§7),
/// y un aviso de "bájate" que no llega con la pantalla apagada es peor que
/// no tener aviso. Al pasar a segundo plano o al terminar, se suelta.
class RideScreen extends ConsumerStatefulWidget {
  const RideScreen({required this.request, required this.index, super.key});

  final TripRequest request;
  final int index;

  @override
  ConsumerState<RideScreen> createState() => _RideScreenState();
}

class _RideScreenState extends ConsumerState<RideScreen> {
  // Se toma una vez: en `dispose` ya no se puede leer `ref`.
  late final ScreenAwake _awake = ref.read(screenAwakeProvider);

  @override
  void initState() {
    super.initState();
    _awake.keepOn();
  }

  @override
  void dispose() {
    _awake.release();
    super.dispose();
  }

  RideController get _ride =>
      ref.read(rideControllerProvider(widget.request, widget.index).notifier);

  void _exit() =>
      context.canPop() ? context.pop() : context.goNamed(AppRoute.map.name);

  /// "Ya me subí": fija el camión y, de paso, lo aprende.
  ///
  /// Es la señal más fuerte de las tres: aquí no hay duda de que el usuario
  /// tomó esta ruta en esta parada.
  void _board(RideWaiting view, String vehicleId) {
    _ride.board(vehicleId);
    if (view.leg.fromStopId case final String stopId) {
      unawaited(
        ref
            .read(usageLogProvider.notifier)
            .record(
              stopId: stopId,
              kind: UseKind.ride,
              routeId: view.leg.route?.id,
            ),
      );
    }
  }

  /// Vibra y lo anuncia, una sola vez por tramo.
  void _alert(RideView view) {
    if (view is! RideOnBoard) {
      return;
    }
    final RideAlert? alert = view.status?.alert;
    if (alert == null || !_ride.claim(alert)) {
      return;
    }
    final String stop = view.leg.to;
    final String message = switch (alert) {
      RideAlert.prepare => 'Prepárate: bajas en 2 paradas, en $stop',
      RideAlert.next => 'Bájate en la siguiente: $stop',
      RideAlert.here => 'Bájate aquí: $stop',
    };
    switch (alert) {
      case RideAlert.prepare:
        HapticFeedback.mediumImpact();
      case RideAlert.next:
      case RideAlert.here:
        HapticFeedback.heavyImpact();
    }
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      TextDirection.ltr,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appInForegroundProvider, (bool? _, bool visible) {
      visible ? _awake.keepOn() : _awake.release();
    });
    ref.listen(rideViewProvider(widget.request, widget.index), (
      AsyncValue<RideView>? _,
      AsyncValue<RideView> next,
    ) {
      if (next case AsyncData<RideView>(:final RideView value)) {
        _alert(value);
      }
    });

    final ThemeData theme = Theme.of(context);
    final AppColors colors = maxContrastColors(
      context.colors,
      theme.brightness,
    );
    final AsyncValue<RideView> view = widget.request.isComplete
        ? ref.watch(rideViewProvider(widget.request, widget.index))
        : const AsyncValue<RideView>.error(
            TripOptionNotFound('sin petición'),
            StackTrace.empty,
          );

    return Theme(
      data: theme.copyWith(extensions: <ThemeExtension<dynamic>>[colors]),
      child: Scaffold(
        backgroundColor: colors.surface,
        body: SafeArea(
          child: Semantics(
            label: 'Modo viaje',
            container: true,
            explicitChildNodes: true,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.xl,
                Spacing.sm,
                Spacing.sm,
                Spacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _Header(view: view.value, onExit: _exit),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: Spacing.md),
                      child: switch (view) {
                        AsyncValue<RideView>(:final RideView value?) =>
                          switch (value) {
                            RideWalking() => _Walking(
                              view: value,
                              onDone: _ride.advance,
                            ),
                            RideWaiting() => _Waiting(
                              view: value,
                              onBoard: (String id) => _board(value, id),
                            ),
                            RideOnBoard() => _OnBoard(
                              view: value,
                              onGotOff: _ride.advance,
                            ),
                            RideFinished() => _Finished(
                              view: value,
                              onDone: () => context.goNamed(AppRoute.map.name),
                            ),
                          },
                        AsyncValue<RideView>(error: NotFound()) ||
                        AsyncValue<RideView>(error: OriginUnavailable()) ||
                        AsyncValue<RideView>(
                          error: PlaceNotFound(),
                        ) => EmptyState(
                          icon: Icons.alt_route,
                          title: 'Este viaje ya no está',
                          message:
                              'Las opciones cambiaron desde que se abrió este '
                              'enlace. Planéalo otra vez.',
                          actionLabel: 'Planear de nuevo',
                          onAction: () => context.goNamed(
                            AppRoute.planner.name,
                            queryParameters: widget.request.toQuery(),
                          ),
                        ),
                        AsyncValue<RideView>(hasError: true) => ErrorState(
                          title: 'Se perdió el viaje',
                          message:
                              'El servicio no respondió. Vuelve a intentarlo.',
                          onRetry: () =>
                              ref.invalidate(tripPlanProvider(widget.request)),
                        ),
                        _ => const SheetSkeleton(lines: 4),
                      },
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

class _Header extends StatelessWidget {
  const _Header({required this.view, required this.onExit});

  final RideView? view;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final RideView? current = view;
    final String step = current == null || current is RideFinished
        ? 'Modo viaje'
        : 'Modo viaje · paso ${current.legIndex + 1} de '
              '${current.itinerary.legs.length}';
    return Row(
      children: <Widget>[
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              step,
              style: AppTypography.label.copyWith(color: colors.textSecondary),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Terminar el viaje',
          iconSize: 28,
          icon: Icon(Icons.close, color: colors.textPrimary),
          onPressed: onExit,
        ),
      ],
    );
  }
}

/// El texto enorme del modo viaje. Palabras, no números sueltos: "faltan 3
/// paradas" se entiende de un vistazo; un "3" solo, no.
class _Big extends StatelessWidget {
  const _Big({required this.text, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double scale = (constraints.maxWidth / 320).clamp(0.8, 1.6);
        return Semantics(
          liveRegion: true,
          child: Text(
            text,
            style: AppTypography.etaBoard.copyWith(
              fontSize: AppTypography.etaBoard.fontSize! * 0.42 * scale,
              height: 1,
              letterSpacing: -0.5,
              color: color ?? colors.textPrimary,
            ),
          ),
        );
      },
    );
  }
}

/// Arriba, al centro y abajo. Si sobra alto, el centro queda al centro y el
/// botón pegado abajo, al alcance del pulgar. Si no alcanza —texto al 200 %,
/// teléfono chico— se desplaza en vez de desbordarse.
class _Stage extends StatelessWidget {
  const _Stage({
    required this.middle,
    required this.bottom,
    this.top = const <Widget>[],
  });

  final List<Widget> top;
  final List<Widget> middle;
  final List<Widget> bottom;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) =>
          SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: top,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Spacing.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: middle,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: bottom,
                  ),
                ],
              ),
            ),
          ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: colors.brand,
        foregroundColor: colors.onBrand,
        disabledBackgroundColor: colors.surfaceSunken,
        disabledForegroundColor: colors.textSecondary,
        minimumSize: const Size.fromHeight(AppSizes.minTouchTarget + 16),
        textStyle: AppTypography.title,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
      ),
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.check),
      label: Text(label),
    );
  }
}

class _RouteLine extends StatelessWidget {
  const _RouteLine({required this.route, required this.text});

  final TransitRoute? route;
  final String text;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final TransitRoute? r = route;
    return Row(
      children: <Widget>[
        if (r != null) ...<Widget>[
          RouteBadge(
            shortName: r.shortName,
            routeId: r.id,
            gtfsColor: r.color,
            gtfsTextColor: r.textColor,
          ),
          const SizedBox(width: Spacing.md),
        ],
        Expanded(
          child: Text(
            text,
            style: AppTypography.title.copyWith(color: colors.textPrimary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _Walking extends StatelessWidget {
  const _Walking({required this.view, required this.onDone});

  final RideWalking view;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final Leg leg = view.leg;
    final bool last = view.isLastLeg;
    return _Stage(
      middle: <Widget>[
        Icon(Icons.directions_walk, size: 40, color: colors.textPrimary),
        const SizedBox(height: Spacing.md),
        _Big(text: last ? 'Camina a tu destino' : 'Camina a ${leg.to}'),
        const SizedBox(height: Spacing.md),
        Text(
          '${durationLabel(leg.duration)} · '
          '${distanceLabel(legMeters(leg))} a pie',
          // Medium y no Regular: esta pantalla se lee con el teléfono en una
          // mano y el sol de frente, y es la única de la app donde el peso de
          // la letra pesa más que la elegancia del texto corrido.
          style: AppTypography.body.copyWith(
            color: colors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
      bottom: <Widget>[
        _PrimaryButton(
          label: last ? 'Ya llegué' : 'Ya estoy en la parada',
          onPressed: onDone,
        ),
      ],
    );
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting({required this.view, required this.onBoard});

  final RideWaiting view;
  final ValueChanged<String> onBoard;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final Leg leg = view.leg;
    final String route = leg.route?.shortName ?? 'ruta';
    final Arrival? arrival = view.arrival;
    final String? candidate = view.candidate?.vehicle.vehicleId;

    return _Stage(
      middle: <Widget>[
        _RouteLine(route: leg.route, text: 'Espera en ${leg.from}'),
        const SizedBox(height: Spacing.lg),
        if (arrival != null)
          Align(
            alignment: Alignment.centerLeft,
            child: EtaChip.fromArrival(arrival, size: EtaChipSize.large),
          )
        else
          Text(
            'Sin arribos de la $route aquí ahora',
            style: AppTypography.body.copyWith(color: colors.textSecondary),
          ),
        const SizedBox(height: Spacing.md),
        Text(
          'Bajas en ${leg.to}',
          style: AppTypography.body.copyWith(color: colors.textSecondary),
        ),
      ],
      bottom: <Widget>[
        if (candidate == null)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.md),
            child: Semantics(
              liveRegion: true,
              child: Text(
                'Todavía no veo un camión de la $route cerca. El botón se '
                'activa cuando llegue.',
                style: AppTypography.body.copyWith(color: colors.textSecondary),
              ),
            ),
          ),
        _PrimaryButton(
          label: 'Ya me subí',
          icon: Icons.directions_bus,
          onPressed: candidate == null ? null : () => onBoard(candidate),
        ),
      ],
    );
  }
}

class _OnBoard extends StatelessWidget {
  const _OnBoard({required this.view, required this.onGotOff});

  final RideOnBoard view;
  final VoidCallback onGotOff;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final Leg leg = view.leg;
    final RideStatus? status = view.status;
    final int? left = status?.stopsLeft;
    final ApproachStrip? strip = status?.strip;

    final String big = switch (left) {
      null => 'Sin señal de tu camión',
      <= 0 => 'Bájate aquí',
      1 => 'Bájate en la siguiente',
      final int n => 'Faltan $n paradas',
    };
    final String? banner = switch (status?.alert) {
      RideAlert.prepare => 'Prepárate: bajas en 2 paradas',
      RideAlert.next => 'La que sigue es la tuya',
      RideAlert.here || null => null,
    };
    final Duration? age = status?.dataAge;

    return _Stage(
      top: <Widget>[
        const SizedBox(height: Spacing.md),
        _RouteLine(route: leg.route, text: 'Bajas en ${leg.to}'),
      ],
      middle: <Widget>[
        if (banner != null) ...<Widget>[
          _Banner(text: banner),
          const SizedBox(height: Spacing.lg),
        ],
        _Big(text: big, color: left == null ? colors.textSecondary : null),
        const SizedBox(height: Spacing.md),
        Text(switch ((status?.signalLost ?? true, age)) {
          (true, final Duration a) =>
            'Perdimos la señal de tu camión ${FreshnessCopy.label(a)}. '
                'El conteo es de su último reporte.',
          (true, null) =>
            'Tu camión ya no reporta. Fíjate en las paradas por la '
                'ventana.',
          (false, final Duration a) => 'Dato ${FreshnessCopy.label(a)}',
          (false, null) => '',
        }, style: AppTypography.body.copyWith(color: colors.textSecondary)),
      ],
      bottom: <Widget>[
        if (strip != null) ...<Widget>[
          RouteStrip(
            stops: strip.stopNames,
            vehicleProgress: strip.progress,
            dataAge: strip.dataAge,
          ),
          const SizedBox(height: Spacing.xl),
        ],
        _PrimaryButton(
          label: view.isLastLeg ? 'Ya llegué' : 'Ya bajé',
          icon: Icons.logout,
          onPressed: onGotOff,
        ),
      ],
    );
  }
}

/// El aviso de prepararse para bajar. Va en índigo con texto: no depende del
/// color, y se lee con el sol de frente.
class _Banner extends StatelessWidget {
  const _Banner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.lg,
        vertical: Spacing.md,
      ),
      decoration: BoxDecoration(
        color: colors.brand,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.notifications_active, color: colors.onBrand),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Text(
              text,
              style: AppTypography.title.copyWith(color: colors.onBrand),
            ),
          ),
        ],
      ),
    );
  }
}

class _Finished extends StatelessWidget {
  const _Finished({required this.view, required this.onDone});

  final RideFinished view;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return _Stage(
      middle: <Widget>[
        Icon(Icons.flag, size: 40, color: colors.textPrimary),
        const SizedBox(height: Spacing.md),
        const _Big(text: 'Llegaste'),
        const SizedBox(height: Spacing.md),
        Text(
          view.itinerary.legs.lastOrNull?.to ?? '',
          style: AppTypography.title.copyWith(color: colors.textSecondary),
        ),
      ],
      bottom: <Widget>[_PrimaryButton(label: 'Terminar', onPressed: onDone)],
    );
  }
}
