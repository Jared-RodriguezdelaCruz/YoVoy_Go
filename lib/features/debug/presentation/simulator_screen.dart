import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/clock/clock_provider.dart';
import '../../../core/data/mock/mock_dataset.dart';
import '../../../core/data/mock/mock_transit_repository.dart';
import '../../../core/data/mock/simulator_config.dart';
import '../../../core/data/transit_repository.dart';
import '../../../core/data/transit_repository_provider.dart';
import '../../../core/history/history_providers.dart';
import '../../../core/history/observation.dart';
import '../../../core/models/models.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/colors.dart';
import '../../../design/tokens/spacing.dart';
import '../../../design/tokens/typography.dart';
import '../../planner/application/trip_request.dart';

/// Panel de control del simulador, solo en builds de debug.
///
/// Existe porque la sección 4.2 del spec pide poder empujar la app a su peor
/// caso a mano: **un mock de datos perfectos produce una UI que se rompe en
/// producción**. Aquí se sube la latencia, se fuerzan errores, se apagan los
/// GPS y se ve qué hace la app con eso.
class SimulatorScreen extends ConsumerWidget {
  const SimulatorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = context.colors;
    final SimulatorConfig config = ref.watch(simulatorSettingsProvider);
    final AsyncValue<TransitRepository> repository = ref.watch(
      transitRepositoryProvider,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Simulador'),
        actions: <Widget>[
          TextButton(
            onPressed: () =>
                ref.read(simulatorSettingsProvider.notifier).makePerfect(),
            child: const Text('Perfecto'),
          ),
          TextButton(
            onPressed: () =>
                ref.read(simulatorSettingsProvider.notifier).makeHostile(),
            child: const Text('Hostil'),
          ),
        ],
      ),
      body: repository.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stack) => ErrorState(
          title: 'No se pudo cargar el dataset',
          message: '$error',
          onRetry: () => ref.invalidate(mockDatasetProvider),
        ),
        data: (TransitRepository repo) => ListView(
          padding: const EdgeInsets.fromLTRB(
            Spacing.lg,
            Spacing.lg,
            Spacing.lg,
            Spacing.xxxl,
          ),
          children: <Widget>[
            if (repo is MockTransitRepository) ...<Widget>[
              _Fleet(repository: repo),
              const SizedBox(height: Spacing.xl),
              _TestTrips(dataset: repo.dataset),
            ],
            const SizedBox(height: Spacing.xl),
            Text(
              'Las fallas',
              style: AppTypography.title.copyWith(color: colors.textPrimary),
            ),
            Text(
              'Nada de esto es pesimismo: es lo que hace el sistema real.',
              style: AppTypography.caption.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: Spacing.md),
            _Slider(
              label: 'Llamadas con error',
              value: config.errorRate,
              display: '${(config.errorRate * 100).round()} %',
              onChanged: (double value) =>
                  _update(ref, config.copyWith(errorRate: value)),
            ),
            _Slider(
              label: 'Vehículos que pierden señal',
              value: config.signalLossRate,
              display: '${(config.signalLossRate * 100).round()} %',
              onChanged: (double value) =>
                  _update(ref, config.copyWith(signalLossRate: value)),
            ),
            _Slider(
              label: 'Reportes sin dirección',
              value: config.missingBearingRate,
              display: '${(config.missingBearingRate * 100).round()} %',
              onChanged: (double value) =>
                  _update(ref, config.copyWith(missingBearingRate: value)),
            ),
            _Slider(
              label: 'Reportes sin ocupación',
              value: config.missingOccupancyRate,
              display: '${(config.missingOccupancyRate * 100).round()} %',
              onChanged: (double value) =>
                  _update(ref, config.copyWith(missingOccupancyRate: value)),
            ),
            _Slider(
              label: 'Latencia máxima',
              value: config.maxLatency.inMilliseconds / 5000,
              display: '${config.maxLatency.inMilliseconds} ms',
              onChanged: (double value) => _update(
                ref,
                config.copyWith(
                  maxLatency: Duration(milliseconds: (value * 5000).round()),
                ),
              ),
            ),
            _Slider(
              label: 'Ruido del GPS',
              value: config.gpsNoiseMaxMeters / 50,
              display: '${config.gpsNoiseMaxMeters.round()} m',
              onChanged: (double value) =>
                  _update(ref, config.copyWith(gpsNoiseMaxMeters: value * 50)),
            ),
            const SizedBox(height: Spacing.xl),
            LitSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'Cadencia de reporte: ${config.reportInterval.inSeconds} s',
                    style: AppTypography.body.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: Spacing.xs),
                  Text(
                    'Es la del sistema real. La UI interpola entre reportes; '
                    'bajarla aquí esconde justo el problema que hay que ver.',
                    style: AppTypography.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (repo is MockTransitRepository) ...<Widget>[
              const SizedBox(height: Spacing.xl),
              _SeedHistory(dataset: repo.dataset),
            ],
          ],
        ),
      ),
    );
  }

  void _update(WidgetRef ref, SimulatorConfig next) =>
      ref.read(simulatorSettingsProvider.notifier).update(next);
}

/// Los pares precocinados de `itineraries.json`, a un toque.
///
/// La v1 no tiene motor de ruteo (§4.3): el planificador solo responde cerca
/// de estos pares. Sin este atajo, demostrarlo es adivinar coordenadas.
class _TestTrips extends StatelessWidget {
  const _TestTrips({required this.dataset});

  final MockDataset dataset;

  static String _title(String id) => switch (id) {
    'directo' => 'Directo',
    'un_transbordo' => 'Con un transbordo',
    'dos_transbordos' => 'Con dos transbordos',
    'sin_resultados' => 'Sin resultados',
    _ => id,
  };

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Viajes de prueba',
          style: AppTypography.title.copyWith(color: colors.textPrimary),
        ),
        Text(
          'Los pares precocinados del planificador. Fuera de ellos, la '
          'respuesta correcta es "no encontré ruta".',
          style: AppTypography.caption.copyWith(color: colors.textSecondary),
        ),
        for (final PrecookedTrip trip in dataset.precookedTrips)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.directions, color: colors.brand),
            title: Text(
              _title(trip.id),
              style: AppTypography.label.copyWith(color: colors.textPrimary),
            ),
            subtitle: Text(
              switch (trip.itineraries.length) {
                0 => 'ninguna opción',
                1 => '1 opción',
                final int n => '$n opciones',
              },
              style: AppTypography.caption.copyWith(
                color: colors.textSecondary,
              ),
            ),
            trailing: Icon(Icons.chevron_right, color: colors.textSecondary),
            onTap: () => context.pushNamed(
              AppRoute.planner.name,
              queryParameters: TripRequest(
                from: PointPlace(trip.from),
                to: PointPlace(trip.to),
              ).toQuery(),
            ),
          ),
      ],
    );
  }
}

/// La flota, en vivo. Es la prueba de que el simulador está andando.
class _Fleet extends ConsumerWidget {
  const _Fleet({required this.repository});

  final MockTransitRepository repository;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = context.colors;
    final MockDataset dataset = repository.dataset;

    return StreamBuilder<List<VehiclePosition>>(
      stream: repository.watchVehicles(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<VehiclePosition>> snapshot,
          ) {
            final List<VehiclePosition> vehicles =
                snapshot.data ?? const <VehiclePosition>[];
            final int sinBearing = vehicles
                .where((VehiclePosition v) => v.bearing == null)
                .length;
            final int flota = repository.simulator.fleetSize;

            return LitSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '${vehicles.length} de $flota reportando',
                    style: AppTypography.title.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: Spacing.xs),
                  Text(
                    '$sinBearing sin dirección · '
                    '${dataset.routes.length} rutas · '
                    '${dataset.stops.length} paradas',
                    style: AppTypography.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  Text(
                    'Sin servicio a propósito: '
                    '${repository.simulator.routesWithoutService.join(', ')}',
                    style: AppTypography.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          },
    );
  }
}

class _Slider extends StatelessWidget {
  const _Slider({
    required this.label,
    required this.value,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final double value;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              // Con el texto del sistema al 200 % estas etiquetas no caben en
              // una fila fija: la etiqueta cede y el valor se queda entero.
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.label.copyWith(
                    color: colors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Text(
                display,
                style: AppTypography.label.copyWith(color: colors.brand),
              ),
            ],
          ),
          Slider(value: value.clamp(0, 1), onChanged: onChanged),
        ],
      ),
    );
  }
}

/// Siembra un historial de mentira, solo en debug.
///
/// La confiabilidad observada necesita cinco observaciones por ruta y parada,
/// y llegan a razón de un camión a la vez: sin esto, verla en el emulador
/// significa esperar media hora mirando una parada. Lo sembrado se borra desde
/// Ajustes, con el mismo botón que lo de verdad.
class _SeedHistory extends ConsumerStatefulWidget {
  const _SeedHistory({required this.dataset});

  final MockDataset dataset;

  @override
  ConsumerState<_SeedHistory> createState() => _SeedHistoryState();
}

class _SeedHistoryState extends ConsumerState<_SeedHistory> {
  /// Las diferencias que se siembran, en minutos. Ni todas iguales ni
  /// disparatadas: una ruta normal, con su cola de retrasos.
  static const List<int> _delays = <int>[-1, 0, 0, 1, 2, 2, 3, 5];

  String? _seeded;

  /// Las primeras paradas del dataset que tienen ruta, con su ruta.
  List<({String stopId, String routeId, String name})> _targets() {
    final List<({String stopId, String routeId, String name})> targets =
        <({String stopId, String routeId, String name})>[];
    for (final Stop stop in widget.dataset.stops) {
      final String? tripId = widget.dataset.tripsForStop(stop.id).firstOrNull;
      final Trip? trip = tripId == null ? null : widget.dataset.trip(tripId);
      if (trip == null) {
        continue;
      }
      targets.add((stopId: stop.id, routeId: trip.routeId, name: stop.name));
      if (targets.length == 3) {
        break;
      }
    }
    return targets;
  }

  Future<void> _seed() async {
    final DateTime now = ref.read(clockProvider)();
    final List<({String stopId, String routeId, String name})> targets =
        _targets();
    if (targets.isEmpty) {
      return;
    }

    final List<ArrivalObservation> observations = <ArrivalObservation>[
      for (final ({String stopId, String routeId, String name}) target
          in targets)
        for (int i = 0; i < _delays.length; i++)
          ArrivalObservation(
            routeId: target.routeId,
            stopId: target.stopId,
            band: TimeBand.of(now.subtract(Duration(days: i))),
            delay: Duration(minutes: _delays[i]),
            at: now.subtract(Duration(days: i)),
          ),
    ];
    await ref.read(arrivalHistoryProvider.notifier).record(observations);

    // Y el uso, para que la hoja del mapa encabece con la primera parada.
    for (int i = 0; i < 4; i++) {
      await ref
          .read(usageLogProvider.notifier)
          .record(stopId: targets.first.stopId, kind: UseKind.board);
    }

    if (mounted) {
      setState(() => _seeded = targets.first.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final int observations =
        ref.watch(arrivalHistoryProvider).value?.length ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Historial de prueba',
          style: AppTypography.title.copyWith(color: colors.textPrimary),
        ),
        Text(
          _seeded == null
              ? 'Llena la confiabilidad observada y lo aprendido sin esperar '
                    'a que pasen los camiones. Hoy hay $observations '
                    'observaciones.'
              : 'Sembrado. Abre "${_seeded!}" y mira la nota bajo cada ruta.',
          style: AppTypography.caption.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: Spacing.md),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: colors.brand,
              foregroundColor: colors.onBrand,
            ),
            onPressed: _seed,
            icon: const Icon(Icons.history),
            label: const Text('Sembrar historial'),
          ),
        ),
      ],
    );
  }
}
