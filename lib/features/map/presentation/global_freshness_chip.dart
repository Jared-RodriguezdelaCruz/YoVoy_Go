import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock/clock_provider.dart';
import '../../../core/transit/vehicle_interpolator.dart';
import '../../../design/components/freshness_indicator.dart';
import '../application/map_providers.dart';

/// Qué tan fresco es el dato del mapa entero: "En vivo", "Hace 2 min", "Sin
/// señal". Visible siempre, arriba (sección 8.1).
///
/// Lleva **el único pulso de la pantalla** (sección 6.5): uno por fila
/// convierte la lista en un árbol de navidad.
///
/// La edad es la del reporte más nuevo de toda la flota. Si hasta ese es
/// viejo, no es que un camión perdió señal: es que el feed se detuvo, y eso es
/// lo que este chip tiene que decir.
class GlobalFreshnessChip extends ConsumerStatefulWidget {
  const GlobalFreshnessChip({super.key});

  @override
  ConsumerState<GlobalFreshnessChip> createState() =>
      _GlobalFreshnessChipState();
}

class _GlobalFreshnessChipState extends ConsumerState<GlobalFreshnessChip> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    // La edad cambia sola con el reloj, sin que llegue nada nuevo. Una vez por
    // segundo basta para que "hace 1 min" pase a "hace 2 min" a tiempo.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final VehicleInterpolator tracker = ref.watch(vehicleTrackerProvider);
    // Para enterarse del primer lote sin esperar al siguiente segundo.
    ref.watch(vehicleFeedProvider);

    final DateTime? newest = tracker.newestReport;
    if (newest == null) {
      return const SizedBox.shrink();
    }
    final DateTime now = ref.watch(clockProvider)();
    final Duration age = now.toUtc().difference(newest.toUtc());
    return FreshnessIndicator(
      dataAge: age.isNegative ? Duration.zero : age,
      pulse: true,
    );
  }
}
