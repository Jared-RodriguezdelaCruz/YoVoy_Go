import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/clock/clock_provider.dart';
import '../../../core/data/not_found.dart';
import '../../../core/data/transit_network.dart';
import '../../../core/models/models.dart';
import '../../../core/transit/live_providers.dart';

part 'stop_providers.g.dart';

/// Se pidió una parada que la red no tiene.
class StopNotFound extends NotFound {
  const StopNotFound(super.id);
}

/// La parada, sacada de la red estática.
@Riverpod(retry: retryUnlessNotFound)
Future<Stop> stopDetail(Ref ref, String stopId) async {
  final TransitNetwork network = await ref.watch(transitNetworkProvider.future);
  return network.stop(stopId) ?? (throw StopNotFound(stopId));
}

/// Las alertas vigentes que tocan a esta parada: las que la nombran y las de
/// cualquier ruta que pase por ella.
///
/// Un desvío de la R03 le importa a quien espera la R03 aquí, aunque la
/// alerta no mencione esta parada.
@riverpod
Future<List<ServiceAlert>> stopAlerts(Ref ref, String stopId) async {
  final TransitNetwork network = await ref.watch(transitNetworkProvider.future);
  final List<ServiceAlert> alerts = await ref.watch(
    activeAlertsProvider.future,
  );
  final Set<String> routes = network.routesForStop(stopId);
  final DateTime now = ref.watch(clockProvider)();
  return <ServiceAlert>[
    for (final ServiceAlert alert in alerts)
      if (alert.isActiveAt(now) &&
          (alert.affectedStopIds.contains(stopId) ||
              alert.affectedRouteIds.any(routes.contains)))
        alert,
  ];
}
