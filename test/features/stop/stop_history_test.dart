import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yovoy_go/app/routes.dart';
import 'package:yovoy_go/core/data/mock/mock_dataset.dart';
import 'package:yovoy_go/core/history/history_providers.dart';
import 'package:yovoy_go/core/history/history_store.dart';
import 'package:yovoy_go/core/history/observation.dart';
import 'package:yovoy_go/core/models/models.dart';

import '../../helpers/screen_harness.dart';

/// Lo que el historial de la fase 8 enciende en pantallas que ya existían:
/// la nota de confiabilidad de la fase 6, que hasta hoy nunca se había visto.
void main() {
  late MockDataset dataset;

  setUpAll(() => dataset = loadTestDataset());

  /// Una parada real con una ruta real que pase por ella.
  ({String stopId, String routeId}) pair() {
    for (final Stop stop in dataset.stops) {
      for (final String tripId in dataset.tripsForStop(stop.id)) {
        final Trip? trip = dataset.trip(tripId);
        if (trip != null) {
          return (stopId: stop.id, routeId: trip.routeId);
        }
      }
    }
    throw StateError('el dataset no tiene ninguna parada con rutas');
  }

  InMemoryHistoryStore historyWith({
    required String routeId,
    required String stopId,
    required int count,
    Duration delay = const Duration(minutes: 3),
  }) => InMemoryHistoryStore(
    arrivals: <ArrivalObservation>[
      for (int i = 0; i < count; i++)
        ArrivalObservation(
          routeId: routeId,
          stopId: stopId,
          band: TimeBand.of(eightAm),
          delay: delay,
          at: eightAm.subtract(Duration(days: i)),
        ),
    ],
  );

  testWidgets('con cinco observaciones la parada dice qué tan puntual es', (
    WidgetTester tester,
  ) async {
    final ({String stopId, String routeId}) target = pair();
    final ProviderContainer container = makeContainer(
      dataset,
      history: historyWith(
        routeId: target.routeId,
        stopId: target.stopId,
        count: 6,
      ),
    );
    await pumpAt(tester, container, AppPaths.stop(target.stopId));

    expect(
      find.textContaining('suele llegar 3 min tarde'),
      findsWidgets,
      reason: 'la nota de la fase 6 por fin tiene con qué hablar',
    );
    expect(find.textContaining('6 observaciones tuyas'), findsWidgets);

    await unmount(tester, container);
  });

  testWidgets('con cuatro se queda callada', (WidgetTester tester) async {
    final ({String stopId, String routeId}) target = pair();
    final ProviderContainer container = makeContainer(
      dataset,
      history: historyWith(
        routeId: target.routeId,
        stopId: target.stopId,
        count: 4,
      ),
    );
    await pumpAt(tester, container, AppPaths.stop(target.stopId));

    expect(find.textContaining('suele llegar'), findsNothing);

    await unmount(tester, container);
  });

  testWidgets('abrir una parada deja su huella, y el paradero pesa más', (
    WidgetTester tester,
  ) async {
    final ({String stopId, String routeId}) target = pair();
    final InMemoryHistoryStore history = InMemoryHistoryStore();
    final ProviderContainer container = makeContainer(
      dataset,
      history: history,
    );
    await pumpAt(tester, container, AppPaths.stop(target.stopId));

    List<UseEvent> uses = await history.loadUses();
    expect(uses, hasLength(1));
    expect(uses.single.stopId, target.stopId);
    expect(uses.single.kind, UseKind.detail);

    await tester.tap(find.byTooltip('Modo paradero'));
    await settle(tester);

    uses = await history.loadUses();
    expect(uses, hasLength(2));
    expect(uses.last.kind, UseKind.board);
    expect(UseKind.board.weight, greaterThan(UseKind.detail.weight));

    await unmount(tester, container);
  });

  testWidgets('lo observado no sale del teléfono: se lee de la misma tienda', (
    WidgetTester tester,
  ) async {
    final ({String stopId, String routeId}) target = pair();
    final InMemoryHistoryStore history = historyWith(
      routeId: target.routeId,
      stopId: target.stopId,
      count: 5,
    );
    final ProviderContainer container = makeContainer(
      dataset,
      history: history,
    );
    await pumpAt(tester, container, AppPaths.stop(target.stopId));

    expect(container.read(arrivalHistoryProvider).value, hasLength(5));

    await unmount(tester, container);
  });
}
