import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yovoy_go/features/favorites/application/favorites_providers.dart';
import 'package:yovoy_go/features/favorites/data/favorites_store.dart';

void main() {
  group('FavoriteStops', () {
    ProviderContainer containerWith(FavoritesStore store) {
      final ProviderContainer container = ProviderContainer(
        overrides: [favoritesStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('toggle guarda y quita, y cada toque se escribe', () async {
      final InMemoryFavoritesStore store = InMemoryFavoritesStore();
      final ProviderContainer container = containerWith(store);
      final FavoriteStops favorites = container.read(
        favoriteStopsProvider.notifier,
      );

      await favorites.toggle('P090');
      expect(await container.read(favoriteStopsProvider.future), <String>{
        'P090',
      });

      await favorites.toggle('P090');
      expect(await container.read(favoriteStopsProvider.future), isEmpty);
      expect(store.saves, 2);
    });

    test('lo guardado sobrevive a un arranque nuevo', () async {
      final InMemoryFavoritesStore store = InMemoryFavoritesStore();
      await containerWith(store)
          .read(favoriteStopsProvider.notifier)
          .toggle('P001');

      final ProviderContainer again = containerWith(store);
      expect(await again.read(favoriteStopsProvider.future), <String>{'P001'});
    });
  });

  group('SharedPreferencesFavoritesStore', () {
    test('lee lo que ya estaba en el teléfono', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        SharedPreferencesFavoritesStore.stopsKey: <String>['P002', 'P001'],
      });

      expect(
        await const SharedPreferencesFavoritesStore().loadStops(),
        <String>{'P001', 'P002'},
      );
    });

    test('escribe y vuelve a leer', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      const SharedPreferencesFavoritesStore store =
          SharedPreferencesFavoritesStore();

      await store.saveStops(<String>{'P090'});

      expect(await store.loadStops(), <String>{'P090'});
    });

    test('sin nada guardado, no hay favoritos', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      expect(
        await const SharedPreferencesFavoritesStore().loadStops(),
        isEmpty,
      );
    });
  });
}
