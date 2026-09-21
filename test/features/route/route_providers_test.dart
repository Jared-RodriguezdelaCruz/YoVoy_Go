import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yovoy_go/core/data/mock/mock_dataset.dart';
import 'package:yovoy_go/core/data/transit_network.dart';
import 'package:yovoy_go/core/models/models.dart';
import 'package:yovoy_go/core/transit/live_providers.dart';
import 'package:yovoy_go/features/route/application/route_providers.dart';
import 'package:yovoy_go/features/route/application/vehicle_placement.dart';

import '../../helpers/screen_harness.dart';

/// Los providers de la ruta contra el dataset real, con el repositorio
/// simulado inyectado por `override` y el reloj fijo en hora pico.
void main() {
  // El stream de la flota pregunta si la app está en primer plano.
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockDataset dataset;
  late ProviderContainer container;

  setUpAll(() => dataset = loadTestDataset());
  setUp(() => container = makeContainer(dataset));
  tearDown(() => container.dispose());

  /// Espera un lote de la flota para que el rastreador tenga camiones.
  Future<RouteDetail> detailWithFleet(String routeId, int directionId) async {
    container.listen(
      routeDetailProvider(routeId, directionId),
      (AsyncValue<RouteDetail>? previous, AsyncValue<RouteDetail> next) {},
    );
    await container.read(vehicleFeedProvider.future);
    await pumpEventQueue();
    return container.read(routeDetailProvider(routeId, directionId).future);
  }

  test('R_01 tiene dos sentidos, nombrados por su destino', () async {
    final List<RouteDirection> directions = await container.read(
      routeDirectionsProvider('R_01').future,
    );

    expect(directions.map((RouteDirection d) => d.directionId), <int>[0, 1]);
    expect(directions.map((RouteDirection d) => d.headsign), <String>[
      'Margaritas',
      'Vicente Guerrero',
    ]);
  });

  test('las rutas de un solo sentido dan un solo sentido', () async {
    final TransitNetwork network = await container.read(
      transitNetworkProvider.future,
    );
    final List<String> oneWay = <String>[
      for (final TransitRoute route in network.routes)
        if (network
                .tripsForRoute(route.id)
                .map((Trip t) => t.directionId)
                .toSet()
                .length ==
            1)
          route.id,
    ];
    expect(oneWay, hasLength(2));

    for (final String id in oneWay) {
      final List<RouteDirection> directions = await container.read(
        routeDirectionsProvider(id).future,
      );
      expect(directions, hasLength(1), reason: id);
    }
  });

  test('una ruta que no existe falla con RouteNotFound', () async {
    container.listen(routeDirectionsProvider('R_999'), (_, _) {});
    await expectLater(
      container.read(routeDirectionsProvider('R_999').future),
      throwsA(isA<RouteNotFound>()),
    );
  });

  test('cada sentido lleva solo sus camiones, entre sus paradas', () async {
    final TransitNetwork network = await container.read(
      transitNetworkProvider.future,
    );
    final RouteDetail outbound = await detailWithFleet('R_01', 0);
    final RouteDetail inbound = await detailWithFleet('R_01', 1);

    expect(outbound.stops, isNotEmpty);
    expect(outbound.path, isNotEmpty);
    expect(
      outbound.vehicles.length + inbound.vehicles.length,
      greaterThan(0),
      reason: 'a las 8:00 de un lunes la R01 tiene camiones',
    );

    for (final (RouteDetail detail, int direction) in <(RouteDetail, int)>[
      (outbound, 0),
      (inbound, 1),
    ]) {
      for (final PlacedVehicle placed in detail.vehicles) {
        expect(placed.vehicle.routeId, 'R_01');
        expect(network.trip(placed.vehicle.tripId)?.directionId, direction);
        expect(placed.afterIndex, inInclusiveRange(0, detail.stops.length - 1));
      }
    }
    final Set<String> outboundIds = <String>{
      for (final PlacedVehicle p in outbound.vehicles) p.vehicle.vehicleId,
    };
    final Set<String> inboundIds = <String>{
      for (final PlacedVehicle p in inbound.vehicles) p.vehicle.vehicleId,
    };
    expect(outboundIds.intersection(inboundIds), isEmpty);
  });

  test('el sentido elegido empieza vacío y se puede cambiar', () {
    expect(container.read(selectedDirectionProvider('R_01')), isNull);
    container.read(selectedDirectionProvider('R_01').notifier).select(1);
    expect(container.read(selectedDirectionProvider('R_01')), 1);
    // Cada ruta recuerda el suyo.
    expect(container.read(selectedDirectionProvider('R_02')), isNull);
  });
}
