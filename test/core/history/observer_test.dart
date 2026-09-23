import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yovoy_go/app/routes.dart';
import 'package:yovoy_go/core/data/mock/mock_dataset.dart';
import 'package:yovoy_go/core/data/mock/simulator_config.dart';
import 'package:yovoy_go/core/history/history_store.dart';
import 'package:yovoy_go/core/history/observation.dart';

import '../../helpers/screen_harness.dart';

/// El lazo completo de observación, con el mundo moviéndose.
///
/// Los demás tests del historial siembran la tienda y miran la pantalla. Este
/// es el único que deja correr el reloj y comprueba **lo que la app anota
/// sola**: es donde se escondía el error de la fase 8, y donde se vería otro.
///
/// La regla que sostiene todo: una observación se guarda solo si el camión se
/// vio **venir y después pasar, en el mismo viaje**. Lo demás se tira.
void main() {
  late MockDataset dataset;

  setUpAll(() => dataset = loadTestDataset());

  /// El Parián: 17 rutas, la parada más viva del dataset a las 8:00.
  const String busy = 'P409';

  testWidgets('observar media hora deja anotado lo que de verdad pasó', (
    WidgetTester tester,
  ) async {
    DateTime now = eightAm;
    final InMemoryHistoryStore history = InMemoryHistoryStore();
    final ProviderContainer container = makeContainer(
      dataset,
      clock: () => now,
      history: history,
    );
    await pumpAt(tester, container, AppPaths.stop(busy));

    // Media hora de servicio, en pasos de 30 s: la cadencia real del feed.
    for (int tick = 0; tick < 60; tick++) {
      now = now.add(const Duration(seconds: 30));
      await tester.pump(const Duration(seconds: 30));
    }

    final List<ArrivalObservation> observed = await history.loadArrivals();

    expect(
      observed,
      isNotEmpty,
      reason:
          'en media hora por una parada de 17 rutas tiene que pasar algún '
          'camión prometido; si no, el lazo dejó de observar',
    );

    for (final ArrivalObservation observation in observed) {
      // Un camión no puede llegar antes de que la app lo viera venir. Un
      // adelanto grande no es puntualidad: es que se cerró la promesa contra
      // otro camión, que es justo lo que pasaba en la fase 8.
      expect(
        observation.delay,
        greaterThan(const Duration(minutes: -20)),
        reason: 'adelanto imposible: ${observation.delay.inMinutes} min',
      );
      expect(
        observation.delay,
        lessThan(const Duration(minutes: 30)),
        reason: 'retraso imposible: ${observation.delay.inMinutes} min',
      );
      expect(observation.stopId, busy);
    }

    await unmount(tester, container);
  });

  testWidgets('en modo hostil tampoco se inventa un adelanto', (
    WidgetTester tester,
  ) async {
    // Señal que se cae, llamadas que fallan y reportes sin rumbo. Lo que se
    // pide no es que anote mucho, sino que **nada de lo que anote sea
    // imposible**: la fase 8 llenó el historial de "26 min antes" así.
    DateTime now = eightAm;
    final InMemoryHistoryStore history = InMemoryHistoryStore();
    final ProviderContainer container = makeContainer(
      dataset,
      config: SimulatorConfig.hostile,
      clock: () => now,
      history: history,
    );
    await pumpAt(tester, container, AppPaths.stop(busy));

    for (int tick = 0; tick < 60; tick++) {
      now = now.add(const Duration(seconds: 30));
      await tester.pump(const Duration(seconds: 30));
    }

    for (final ArrivalObservation observation in await history.loadArrivals()) {
      expect(
        observation.delay,
        greaterThan(const Duration(minutes: -20)),
        reason: 'adelanto imposible: ${observation.delay.inMinutes} min',
      );
    }

    await unmount(tester, container);
  });
}
