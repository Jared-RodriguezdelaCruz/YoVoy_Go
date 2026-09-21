import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/mock/mock_dataset.dart';
import '../../../core/data/mock/mock_transit_repository.dart';
import '../../../core/data/mock/simulator_config.dart';
import '../../../core/data/transit_repository.dart';
import '../../../core/data/transit_repository_provider.dart';
import '../../../core/models/models.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/colors.dart';
import '../../../design/tokens/spacing.dart';
import '../../../design/tokens/typography.dart';

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
            if (repo is MockTransitRepository) _Fleet(repository: repo),
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
          ],
        ),
      ),
    );
  }

  void _update(WidgetRef ref, SimulatorConfig next) =>
      ref.read(simulatorSettingsProvider.notifier).update(next);
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
