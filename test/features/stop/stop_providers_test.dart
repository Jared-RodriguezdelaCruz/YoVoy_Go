import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yovoy_go/core/data/mock/mock_dataset.dart';
import 'package:yovoy_go/core/data/transit_network.dart';
import 'package:yovoy_go/core/models/models.dart';
import 'package:yovoy_go/core/transit/live_providers.dart';
import 'package:yovoy_go/features/stop/application/stop_providers.dart';

import '../../helpers/screen_harness.dart';

/// Las alertas del dataset real, vistas el 21 de septiembre de 2026:
///
/// - El desvío de López Mateos (R_03 y R_09) empezó el 1 de septiembre y
///   sigue "hasta nuevo aviso".
/// - La parada movida por la Feria de San Marcos (P090, R_37) terminó en
///   mayo.
void main() {
  // El stream de la flota pregunta si la app está en primer plano.
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockDataset dataset;
  late ProviderContainer container;

  setUpAll(() => dataset = loadTestDataset());
  setUp(() => container = makeContainer(dataset));
  tearDown(() => container.dispose());

  Future<List<ServiceAlert>> alertsFor(String stopId) async {
    container.listen(
      stopAlertsProvider(stopId),
      (
        AsyncValue<List<ServiceAlert>>? previous,
        AsyncValue<List<ServiceAlert>> next,
      ) {},
    );
    return container.read(stopAlertsProvider(stopId).future);
  }

  test('la parada sale de la red', () async {
    final Stop stop = await container.read(stopDetailProvider('P090').future);
    expect(stop.name, 'Leche San Marcos');
  });

  test('una parada que no existe falla con StopNotFound', () async {
    container.listen(stopDetailProvider('nada'), (_, _) {});
    await expectLater(
      container.read(stopDetailProvider('nada').future),
      throwsA(isA<StopNotFound>()),
    );
  });

  test(
    'un desvío de la R03 se ve en las paradas por donde pasa la R03',
    () async {
      final TransitNetwork network = await container.read(
        transitNetworkProvider.future,
      );
      final Stop onR03 = network.stops.firstWhere(
        (Stop s) => network.routesForStop(s.id).contains('R_03'),
      );

      final List<ServiceAlert> alerts = await alertsFor(onR03.id);

      expect(
        alerts.map((ServiceAlert a) => a.id),
        contains('alerta_obra_lopez_mateos'),
      );
    },
  );

  test('una alerta vencida no aparece aunque nombre la parada', () async {
    final List<ServiceAlert> alerts = await alertsFor('P090');

    expect(
      alerts.map((ServiceAlert a) => a.id),
      isNot(contains('alerta_parada_movida_san_marcos')),
    );
  });

  test('una parada lejos de las rutas afectadas no lleva alertas', () async {
    final TransitNetwork network = await container.read(
      transitNetworkProvider.future,
    );
    final Stop quiet = network.stops.firstWhere((Stop s) {
      final Set<String> routes = network.routesForStop(s.id);
      return routes.isNotEmpty &&
          !routes.contains('R_03') &&
          !routes.contains('R_09');
    });

    expect(await alertsFor(quiet.id), isEmpty);
  });
}
