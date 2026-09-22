import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yovoy_go/core/data/mock/mock_dataset.dart';
import 'package:yovoy_go/core/models/models.dart';
import 'package:yovoy_go/features/map/application/accessibility_filter.dart';
import 'package:yovoy_go/features/map/application/map_providers.dart';

import '../../helpers/screen_harness.dart';

/// "Solo accesibles": el filtro, lo que guarda y lo que deja fuera.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockDataset dataset;

  setUpAll(() => dataset = loadTestDataset());

  test('las paradas sin verificar no pasan el filtro', () {
    const Stop sinVerificar = Stop(id: 'A', name: 'A', lat: 0, lon: 0);
    const Stop accesible = Stop(
      id: 'B',
      name: 'B',
      lat: 0,
      lon: 0,
      wheelchairBoarding: WheelchairBoarding.accessible,
    );

    expect(
      passesAccessibilityFilter(sinVerificar, accessibleOnly: true),
      isFalse,
    );
    expect(passesAccessibilityFilter(accesible, accessibleOnly: true), isTrue);
    expect(
      passesAccessibilityFilter(sinVerificar, accessibleOnly: false),
      isTrue,
    );
  });

  test('el interruptor se guarda y sobrevive a otro arranque', () async {
    final InMemoryAccessibilityFilterStore store =
        InMemoryAccessibilityFilterStore();
    final ProviderContainer first = makeContainer(
      dataset,
      accessibility: store,
    );
    expect(await first.read(accessibleOnlyProvider.future), isFalse);
    await first.read(accessibleOnlyProvider.notifier).toggle();
    expect(first.read(accessibleOnlyProvider).value, isTrue);
    first.dispose();

    final ProviderContainer second = makeContainer(
      dataset,
      accessibility: store,
    );
    expect(await second.read(accessibleOnlyProvider.future), isTrue);
    second.dispose();
  });

  test('en disco usa su propia clave', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const SharedPreferencesAccessibilityFilterStore store =
        SharedPreferencesAccessibilityFilterStore();

    expect(await store.load(), isFalse);
    await store.save(accessibleOnly: true);
    expect(await store.load(), isTrue);
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getBool(SharedPreferencesAccessibilityFilterStore.key),
      isTrue,
    );
  });

  test('con el filtro, las paradas cercanas son solo las accesibles', () async {
    final ProviderContainer container = makeContainer(
      dataset,
      accessibility: InMemoryAccessibilityFilterStore(value: true),
    );
    final ProviderSubscription<AsyncValue<List<NearbyStop>>> sub = container
        .listen(nearbyStopsProvider, (_, _) {});

    final List<NearbyStop> nearby = await container.read(
      nearbyStopsProvider.future,
    );

    expect(nearby, isNotEmpty);
    expect(
      nearby.every(
        (NearbyStop n) =>
            n.stop.wheelchairBoarding == WheelchairBoarding.accessible,
      ),
      isTrue,
    );
    sub.close();
    container.dispose();
  });
}
