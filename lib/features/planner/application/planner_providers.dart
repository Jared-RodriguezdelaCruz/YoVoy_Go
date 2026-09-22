import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/clock/clock_provider.dart';
import '../../../core/data/not_found.dart';
import '../../../core/data/transit_repository.dart';
import '../../../core/data/transit_repository_provider.dart';
import '../../../core/location/location_service.dart';
import '../../../core/models/models.dart';
import '../../../core/transit/live_providers.dart';
import '../../map/application/accessibility_filter.dart';
import 'no_route_help.dart';
import 'ranking.dart';
import 'trip_request.dart';

part 'planner_providers.g.dart';

/// Se pidió una opción que la lista ya no tiene: un enlace viejo.
class TripOptionNotFound extends NotFound {
  const TripOptionNotFound(super.id);
}

/// Lo que responde el planificador para una petición.
@immutable
class TripPlan {
  const TripPlan({
    required this.from,
    required this.to,
    required this.ranked,
    required this.departAt,
    required this.leavesNow,
    required this.accessibleOnly,
    this.stops = const <String, Stop>{},
    this.help,
  });

  final ResolvedPlace from;
  final ResolvedPlace to;

  /// Todas las opciones, ya ordenadas: simplicidad antes que minutos. El
  /// índice de una opción en esta lista es el que va en la URL.
  final List<Itinerary> ranked;

  final DateTime departAt;
  final bool leavesNow;

  /// Si el filtro de accesibilidad estaba activo al planear.
  final bool accessibleOnly;

  /// Las paradas donde se sube o se baja en alguna opción, por id.
  final Map<String, Stop> stops;

  /// La salida útil, solo cuando no hay ninguna opción.
  final NoRouteHelp? help;

  /// Las opciones que pasan el filtro, con su índice en [ranked].
  List<(int, Itinerary)> get visible => <(int, Itinerary)>[
    for (int i = 0; i < ranked.length; i++)
      if (!accessibleOnly || itineraryIsAccessible(ranked[i], stops))
        (i, ranked[i]),
  ];

  /// Cuántas opciones escondió el filtro.
  int get hiddenByAccessibility => ranked.length - visible.length;
}

/// Si todas las paradas donde se sube o se baja están verificadas como
/// accesibles. Una sin verificar no pasa: quien necesita una rampa no puede
/// apostar a que haya una.
bool itineraryIsAccessible(Itinerary itinerary, Map<String, Stop> stops) {
  for (final Leg leg in itinerary.busLegs) {
    for (final String? id in <String?>[leg.fromStopId, leg.toStopId]) {
      final Stop? stop = id == null ? null : stops[id];
      if (stop == null ||
          !passesAccessibilityFilter(stop, accessibleOnly: true)) {
        return false;
      }
    }
  }
  return true;
}

/// Los tramos a pie del dataset dicen "Tu ubicación" y "Tu destino". En
/// pantalla va el nombre de lo que el usuario eligió.
Itinerary relabel(
  Itinerary itinerary, {
  required String from,
  required String to,
}) => itinerary.copyWith(
  legs: <Leg>[
    for (final Leg leg in itinerary.legs)
      leg.copyWith(
        from: leg.from == 'Tu ubicación' ? from : leg.from,
        to: leg.to == 'Tu destino' ? to : leg.to,
      ),
  ],
);

/// Reintentar no arregla un GPS apagado ni una parada que no existe.
Duration? plannerRetry(int retryCount, Object error) =>
    error is OriginUnavailable || error is PlaceNotFound
    ? null
    : retryUnlessNotFound(retryCount, error);

/// Planea [request]. La petición tiene que venir completa.
@Riverpod(retry: plannerRetry)
Future<TripPlan> tripPlan(Ref ref, TripRequest request) async {
  assert(request.isComplete, 'el planificador necesita origen y destino');
  final TransitNetwork network = await ref.watch(transitNetworkProvider.future);
  final bool needsGps = request.from is HerePlace || request.to is HerePlace;
  final UserLocation? location = needsGps
      ? await ref.watch(userLocationProvider.future)
      : null;
  final ResolvedPlace from = resolvePlace(
    request.from!,
    network: network,
    location: location,
  );
  final ResolvedPlace to = resolvePlace(
    request.to!,
    network: network,
    location: location,
  );

  final DateTime now = ref.watch(clockProvider)();
  final DateTime departAt = request.departAt(now);
  final TransitRepository repository = await ref.watch(
    transitRepositoryProvider.future,
  );
  final List<Itinerary> found = await repository.planTrip(
    from: from.position,
    to: to.position,
    departAt: request.leavesNow ? null : departAt,
  );
  final bool accessibleOnly = await ref.watch(accessibleOnlyProvider.future);

  final List<Itinerary> ranked = rankItineraries(<Itinerary>[
    for (final Itinerary itinerary in found)
      relabel(itinerary, from: from.label, to: to.label),
  ]);
  return TripPlan(
    from: from,
    to: to,
    ranked: ranked,
    departAt: departAt,
    leavesNow: request.leavesNow,
    accessibleOnly: accessibleOnly,
    stops: <String, Stop>{
      for (final Itinerary itinerary in ranked)
        for (final Leg leg in itinerary.busLegs)
          for (final String? id in <String?>[leg.fromStopId, leg.toStopId])
            if (id != null)
              if (network.stop(id) case final Stop stop) id: stop,
    },
    help: ranked.isEmpty
        ? noRouteHelp(network, from: from.position, to: to.position)
        : null,
  );
}

/// Una opción del plan, por su índice en [TripPlan.ranked].
@Riverpod(retry: plannerRetry)
Future<(TripPlan, Itinerary)> tripOption(
  Ref ref,
  TripRequest request,
  int index,
) async {
  final TripPlan plan = await ref.watch(tripPlanProvider(request).future);
  if (index < 0 || index >= plan.ranked.length) {
    throw TripOptionNotFound('$index');
  }
  return (plan, plan.ranked[index]);
}
