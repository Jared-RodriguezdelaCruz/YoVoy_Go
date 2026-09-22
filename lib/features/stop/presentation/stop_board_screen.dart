import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/config/freshness.dart';
import '../../../core/device/screen_awake.dart';
import '../../../core/lifecycle/app_lifecycle_provider.dart';
import '../../../core/models/models.dart';
import '../../../core/transit/live_providers.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/colors.dart';
import '../../../design/tokens/max_contrast.dart';
import '../../../design/tokens/spacing.dart';
import '../../../design/tokens/typography.dart';
import '../application/stop_board.dart';
import '../application/stop_providers.dart';

/// Modo paradero: una parada, un número enorme, la tira de la ruta y nada
/// más.
///
/// Es para cuando ya estás parado esperando, con el sol de frente y el
/// teléfono en una mano. Por eso el contraste va al máximo, la pantalla no se
/// apaga y se actualiza sola. Un toque en cualquier parte sale.
class StopBoardScreen extends ConsumerStatefulWidget {
  const StopBoardScreen({required this.stopId, super.key});

  final String stopId;

  @override
  ConsumerState<StopBoardScreen> createState() => _StopBoardScreenState();
}

class _StopBoardScreenState extends ConsumerState<StopBoardScreen> {
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

  void _exit() => context.canPop()
      ? context.pop()
      : context.goNamed(
          AppRoute.stop.name,
          pathParameters: <String, String>{AppParams.stopId: widget.stopId},
        );

  @override
  Widget build(BuildContext context) {
    // En segundo plano la pantalla no tiene por qué quedarse encendida.
    ref.listen(appInForegroundProvider, (bool? _, bool visible) {
      visible ? _awake.keepOn() : _awake.release();
    });

    final ThemeData theme = Theme.of(context);
    final AppColors colors = maxContrastColors(
      context.colors,
      theme.brightness,
    );
    final AsyncValue<StopBoard> board = ref.watch(
      stopBoardProvider(widget.stopId),
    );

    return Theme(
      data: theme.copyWith(extensions: <ThemeExtension<dynamic>>[colors]),
      child: Scaffold(
        backgroundColor: colors.surface,
        body: Semantics(
          label: 'Modo paradero. Toca para salir',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _exit,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.xl,
                  Spacing.sm,
                  Spacing.sm,
                  Spacing.xl,
                ),
                child: switch (board) {
                  AsyncValue<StopBoard>(:final StopBoard value?) => _Board(
                    board: value,
                    onExit: _exit,
                  ),
                  AsyncValue<StopBoard>(error: StopNotFound()) => _Message(
                    onExit: _exit,
                    child: EmptyState(
                      icon: Icons.wrong_location_outlined,
                      title: 'Esta parada no existe',
                      message:
                          'No hay ninguna parada con el código '
                          '${widget.stopId}.',
                      actionLabel: 'Ir al mapa',
                      onAction: () => context.goNamed(AppRoute.map.name),
                    ),
                  ),
                  AsyncValue<StopBoard>(hasError: true) => _Message(
                    onExit: _exit,
                    child: ErrorState(
                      title: 'No se pudieron cargar los arribos',
                      message: 'El servicio no respondió. Vuelve a intentarlo.',
                      onRetry: () =>
                          ref.invalidate(stopArrivalsProvider(widget.stopId)),
                    ),
                  ),
                  _ => _Message(
                    onExit: _exit,
                    child: const Padding(
                      padding: EdgeInsets.only(right: Spacing.md),
                      child: SheetSkeleton(lines: 4),
                    ),
                  ),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.onExit, required this.child});

  final VoidCallback onExit;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Align(
          alignment: Alignment.topRight,
          child: _ExitButton(onExit: onExit),
        ),
        Expanded(child: Center(child: child)),
      ],
    );
  }
}

class _ExitButton extends StatelessWidget {
  const _ExitButton({required this.onExit});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Salir del modo paradero',
      iconSize: 28,
      icon: Icon(Icons.close, color: context.colors.textPrimary),
      onPressed: onExit,
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({required this.board, required this.onExit});

  final StopBoard board;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final Arrival? lead = board.lead;
    final ApproachStrip? strip = board.strip;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: Spacing.md),
                child: Semantics(
                  header: true,
                  child: Text(
                    board.stop.name,
                    style: AppTypography.routeBadge.copyWith(
                      fontSize: 26,
                      height: 1.1,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
            _ExitButton(onExit: onExit),
          ],
        ),
        const Spacer(),
        if (lead == null)
          Text(
            'No pasa ningún camión por aquí ahora',
            style: AppTypography.title.copyWith(color: colors.textPrimary),
          )
        else ...<Widget>[
          Row(
            children: <Widget>[
              RouteBadge(
                shortName: lead.routeShortName,
                routeId: lead.routeId,
                gtfsColor: board.route?.color,
                gtfsTextColor: board.route?.textColor,
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Text(
                  'Hacia ${lead.headsign}',
                  style: AppTypography.title.copyWith(
                    color: colors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.lg),
          _BigEta(arrival: lead),
          const SizedBox(height: Spacing.lg),
          OccupancyIndicator(status: lead.occupancyStatus, large: true),
        ],
        const Spacer(),
        if (strip != null) ...<Widget>[
          Padding(
            padding: const EdgeInsets.only(right: Spacing.md),
            child: RouteStrip(
              stops: strip.stopNames,
              vehicleProgress: strip.progress,
              dataAge: strip.dataAge,
            ),
          ),
          const SizedBox(height: Spacing.xl),
        ],
        if (board.following.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: Spacing.md),
            child: Text(
              'Después: ${board.following.map(_shortEta).join(' · ')}',
              style: AppTypography.body.copyWith(color: colors.textSecondary),
            ),
          ),
      ],
    );
  }
}

/// "R09 en 12 min" · "R37 cada 20 min" · "R12 sin señal".
String _shortEta(Arrival arrival) {
  final String when;
  if (arrival.confidence == EtaConfidence.live && arrival.showsNumericEta) {
    final int minutes = arrival.eta!.inMinutes;
    when = minutes <= 0 ? 'llegando' : 'en $minutes min';
  } else if (arrival.headway case final Duration headway) {
    when = FrequencyCopy.label(headway);
  } else if (arrival.showsNumericEta) {
    when = 'en ${arrival.eta!.inMinutes} min, programado';
  } else {
    when = 'sin señal';
  }
  return '${arrival.routeShortName} $when';
}

/// El número enorme, o lo que lo sustituye. Nunca un número inventado.
class _BigEta extends StatelessWidget {
  const _BigEta({required this.arrival});

  final Arrival arrival;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final bool live =
        arrival.confidence == EtaConfidence.live && arrival.showsNumericEta;
    final DataFreshness freshness = Freshness.classify(arrival.dataAge);

    final int? minutes = arrival.eta?.inMinutes;
    // `unit` presente es un número: va al tamaño completo. Lo demás son
    // palabras, y van más chicas para caber en un renglón.
    final (
      String big,
      String? unit,
      String note,
      Color color,
    ) = switch (arrival) {
      _ when live => (
        minutes! <= 0 ? 'llegando' : '$minutes',
        minutes <= 0 ? null : 'min',
        FreshnessCopy.label(arrival.dataAge),
        FreshnessCopy.color(colors, freshness),
      ),
      Arrival(:final Duration headway?) => (
        FrequencyCopy.label(headway),
        null,
        arrival.confidence == EtaConfidence.unknown
            ? 'sin señal del camión · según horario'
            : 'según horario',
        colors.textPrimary,
      ),
      _ when arrival.showsNumericEta => (
        '$minutes',
        'min',
        'programado',
        colors.textPrimary,
      ),
      _ => ('sin señal', null, 'de este camión', colors.textSecondary),
    };

    return Semantics(
      label: EtaChip.describeArrival(arrival),
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // El número crece con el ancho del teléfono.
          final double scale = (constraints.maxWidth / 320).clamp(0.8, 1.6);
          final TextStyle style = AppTypography.etaBoard.copyWith(
            fontSize:
                AppTypography.etaBoard.fontSize! *
                scale *
                (unit != null ? 1 : 0.42),
            color: color,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: <Widget>[
                    Text(big, style: style),
                    if (unit != null) ...<Widget>[
                      const SizedBox(width: Spacing.sm),
                      Text(
                        unit,
                        style: AppTypography.eta.copyWith(
                          fontSize: 32 * scale,
                          color: color,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                note,
                style: AppTypography.body.copyWith(color: colors.textSecondary),
              ),
            ],
          );
        },
      ),
    );
  }
}
