import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yovoy_go/core/data/mock/mock_dataset.dart';
import 'package:yovoy_go/core/data/mock/mock_transit_repository.dart';
import 'package:yovoy_go/core/data/mock/simulator_config.dart';
import 'package:yovoy_go/core/data/transit_repository.dart';
import 'package:yovoy_go/core/data/transit_repository_provider.dart';
import 'package:yovoy_go/core/lifecycle/app_lifecycle_provider.dart';
import 'package:yovoy_go/core/location/location_service.dart';
import 'package:yovoy_go/core/models/models.dart';
import 'package:yovoy_go/features/map/application/accessibility_filter.dart';
import 'package:yovoy_go/features/map/application/leave_now.dart';
import 'package:yovoy_go/features/map/application/map_providers.dart';

class _MockRepository extends Mock implements TransitRepository {}

/// Una ubicación puesta a mano: los tests no tocan el GPS.
class _FixedLocation implements LocationService {
  _FixedLocation(this.location);

  final UserLocation location;

  @override
  Future<UserLocation> current() async => location;

  @override
  Future<void> openSettings(LocationIssue issue) async {}
}

/// Los providers del mapa, con `ProviderContainer` y `overrides` como pide la
/// sección 13 del spec.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('con la app en segundo plano no se sondea nada', () {
    late StreamController<List<VehiclePosition>> feed;
    late int listens;
    late int cancels;
    late ProviderContainer container;

    setUp(() {
      listens = 0;
      cancels = 0;
      feed = StreamController<List<VehiclePosition>>.broadcast(
        onListen: () => listens++,
        onCancel: () => cancels++,
      );
      final _MockRepository repository = _MockRepository();
      when(repository.watchVehicles).thenAnswer((_) => feed.stream);

      container = ProviderContainer(
        overrides: [
          accessibilityFilterStoreProvider.overrideWithValue(
            InMemoryAccessibilityFilterStore(),
          ),
          transitRepositoryProvider.overrideWith((Ref ref) async => repository),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(feed.close);
    });

    test('el stream se suelta en pausa y vuelve al regresar', () async {
      final ProviderSubscription<AsyncValue<List<VehiclePosition>>> sub =
          container.listen(vehicleFeedProvider, (_, _) {});
      addTearDown(sub.close);
      container
          .read(appLifecycleProvider.notifier)
          .set(AppLifecycleState.resumed);
      await pumpEventQueue();
      expect(listens, 1);
      expect(cancels, 0);

      container
          .read(appLifecycleProvider.notifier)
          .set(AppLifecycleState.paused);
      await pumpEventQueue();
      expect(cancels, 1, reason: 'en pausa la suscripción tiene que soltarse');

      container
          .read(appLifecycleProvider.notifier)
          .set(AppLifecycleState.resumed);
      await pumpEventQueue();
      expect(listens, 2, reason: 'al volver se suscribe de nuevo');
    });

    test('bajar la cortina de notificaciones no corta el mapa', () async {
      container
          .read(appLifecycleProvider.notifier)
          .set(AppLifecycleState.inactive);
      expect(container.read(appInForegroundProvider), isTrue);
      container
          .read(appLifecycleProvider.notifier)
          .set(AppLifecycleState.hidden);
      expect(container.read(appInForegroundProvider), isFalse);
    });
  });

  group('con el dataset real', () {
    late MockDataset dataset;

    setUpAll(() {
      dataset = MockDataset.fromJsonStrings(<String, String>{
        for (final String name in MockAssets.files)
          name: File('${MockAssets.directory}/$name').readAsStringSync(),
      });
    });

    ProviderContainer containerWith(UserLocation location) {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          accessibilityFilterStoreProvider.overrideWithValue(
            InMemoryAccessibilityFilterStore(),
          ),
          transitRepositoryProvider.overrideWith(
            (Ref ref) async => MockTransitRepository(
              dataset: dataset,
              config: SimulatorConfig.perfect,
            ),
          ),
          locationServiceProvider.overrideWithValue(_FixedLocation(location)),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test(
      'sin permiso de ubicación, el mapa cae al centro de la ciudad',
      () async {
        final ProviderContainer container = containerWith(
          const UserLocation.fallback(LocationIssue.denied),
        );
        final UserLocation location = await container.read(
          userLocationProvider.future,
        );
        expect(location.isFallback, isTrue);
        expect(location.position, aguascalientesCenter);

        // Y aun así hay paradas: el centro es donde más pasan.
        final List<NearbyStop> nearby = await container.read(
          nearbyStopsProvider.future,
        );
        expect(nearby, isNotEmpty);
      },
    );

    test(
      'las paradas cercanas vienen de la más cercana a la más lejana',
      () async {
        final ProviderContainer container = containerWith(
          const UserLocation(position: LatLng(21.8818, -102.2960)),
        );
        final List<NearbyStop> nearby = await container.read(
          nearbyStopsProvider.future,
        );
        expect(nearby.length, lessThanOrEqualTo(6));
        for (int i = 1; i < nearby.length; i++) {
          expect(nearby[i].meters, greaterThanOrEqualTo(nearby[i - 1].meters));
        }
        expect(
          nearby.every((NearbyStop n) => n.meters <= nearbyRadiusMeters),
          isTrue,
        );
      },
    );

    test('"¿Ya me voy?" responde para la parada más cercana', () async {
      final ProviderContainer container = containerWith(
        const UserLocation(position: LatLng(21.8818, -102.2960)),
      );
      final LeaveNowAdvice? advice = await container.read(
        leaveNowProvider.future,
      );
      final List<NearbyStop> nearby = await container.read(
        nearbyStopsProvider.future,
      );
      expect(advice, isNotNull);
      expect(advice!.stopName, nearby.first.stop.name);
    });

    test('lejos de todo, "¿Ya me voy?" no inventa una parada', () async {
      final ProviderContainer container = containerWith(
        // Un punto en el campo, a kilómetros de cualquier ruta.
        const UserLocation(position: LatLng(22.2, -102.6)),
      );
      expect(await container.read(nearbyStopsProvider.future), isEmpty);
      expect(await container.read(leaveNowProvider.future), isNull);
    });

    test('la red trae trazos por ruta y paradas por viaje', () async {
      final ProviderContainer container = containerWith(
        const UserLocation(position: LatLng(21.8818, -102.2960)),
      );
      final TransitNetwork network = await container.read(
        transitNetworkProvider.future,
      );
      expect(network.routes, hasLength(48));
      expect(network.shapesForRoute('R_01'), hasLength(2));
      final Trip trip = network.tripsForRoute('R_01').first;
      expect(network.stopsForTrip(trip.id).length, greaterThan(2));
    });
  });
}
