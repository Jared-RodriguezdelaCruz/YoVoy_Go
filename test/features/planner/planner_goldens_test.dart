import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yovoy_go/core/data/mock/mock_dataset.dart';
import 'package:yovoy_go/core/data/transit_network.dart';
import 'package:yovoy_go/core/models/models.dart';
import 'package:yovoy_go/core/transit/live_providers.dart';
import 'package:yovoy_go/design/theme.dart';
import 'package:yovoy_go/features/planner/application/planner_providers.dart';
import 'package:yovoy_go/features/planner/application/ride_session.dart';
import 'package:yovoy_go/features/planner/application/trip_request.dart';
import 'package:yovoy_go/features/planner/presentation/itinerary_screen.dart';
import 'package:yovoy_go/features/planner/presentation/planner_screen.dart';
import 'package:yovoy_go/features/planner/presentation/ride_screen.dart';

import '../../helpers/golden_fonts.dart';
import '../../helpers/screen_harness.dart';

/// Fotos del planificador, el detalle y el modo viaje, para **verlas** sin
/// emulador. El reloj va fijo a las 8:00 y el fondo del mapa no se dibuja:
/// pide red. Se regeneran con `flutter test --update-goldens`.
void main() {
  late MockDataset dataset;
  late TripRequest transbordo;

  setUpAll(() async {
    await loadAppFonts();
    dataset = loadTestDataset();
    final PrecookedTrip pair = dataset.precookedTrips.firstWhere(
      (PrecookedTrip p) => p.id == 'dos_transbordos',
    );
    transbordo = TripRequest(
      from: PointPlace(pair.from),
      to: PointPlace(pair.to),
    );
  });

  String planner(TripRequest request) =>
      Uri(path: '/planner', queryParameters: request.toQuery()).toString();

  testWidgets('resultados, tema oscuro', (WidgetTester tester) async {
    final ProviderContainer container = makeContainer(dataset);
    await pumpAt(tester, container, planner(transbordo));
    await expectLater(
      find.byType(PlannerScreen),
      matchesGoldenFile('goldens/planner_results_dark.png'),
    );
    await unmount(tester, container);
  });

  testWidgets('resultados, tema claro', (WidgetTester tester) async {
    final ProviderContainer container = makeContainer(dataset);
    await pumpAt(tester, container, planner(transbordo), theme: AppTheme.light);
    await expectLater(
      find.byType(PlannerScreen),
      matchesGoldenFile('goldens/planner_results_light.png'),
    );
    await unmount(tester, container);
  });

  testWidgets('sin ruta, tema oscuro', (WidgetTester tester) async {
    final ProviderContainer container = makeContainer(dataset);
    await pumpAt(tester, container, '/planner?from=P453&to=21.6,-102.6');
    await expectLater(
      find.byType(PlannerScreen),
      matchesGoldenFile('goldens/planner_no_route_dark.png'),
    );
    await unmount(tester, container);
  });

  testWidgets('detalle del itinerario, tema oscuro', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = makeContainer(dataset);
    await pumpAt(
      tester,
      container,
      Uri(
        path: '/planner/option/0',
        queryParameters: transbordo.toQuery(),
      ).toString(),
    );
    await expectLater(
      find.byType(ItineraryScreen),
      matchesGoldenFile('goldens/itinerary_dark.png'),
    );
    await unmount(tester, container);
  });

  testWidgets('modo viaje a dos paradas, tema oscuro', (
    WidgetTester tester,
  ) async {
    // El primer camión del mejor viaje, a dos paradas de bajarse.
    final ProviderContainer probe = makeContainer(dataset);
    final TransitNetwork network = await probe.read(
      transitNetworkProvider.future,
    );
    final TripPlan plan = await probe.read(tripPlanProvider(transbordo).future);
    probe.dispose();
    final Leg leg = plan.ranked.first.busLegs.first;
    final LegPath path = legPath(network, leg)!;
    final VehiclePosition bus = VehiclePosition(
      vehicleId: 'golden',
      tripId: path.tripId,
      routeId: leg.route!.id,
      position: path.tripStops[path.alight - 2].position,
      timestamp: eightAm.subtract(const Duration(seconds: 20)),
      currentStopSequence: path.alight - 1,
    );

    final ProviderContainer container = makeContainer(
      dataset,
      vehicles: <VehiclePosition>[bus],
    );
    await pumpAt(
      tester,
      container,
      Uri(
        path: '/planner/option/0/ride',
        queryParameters: transbordo.toQuery(),
      ).toString(),
    );
    container.read(rideControllerProvider(transbordo, 0).notifier)
      ..advance()
      ..board('golden');
    await settle(tester);

    await expectLater(
      find.byType(RideScreen),
      matchesGoldenFile('goldens/ride_dark.png'),
    );
    await unmount(tester, container);
  });
}
