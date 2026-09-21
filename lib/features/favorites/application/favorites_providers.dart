import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/favorites_store.dart';

part 'favorites_providers.g.dart';

@Riverpod(keepAlive: true)
FavoritesStore favoritesStore(Ref ref) =>
    const SharedPreferencesFavoritesStore();

/// Los ids de las paradas guardadas.
///
/// `keepAlive`: es un dato del usuario, no una suscripción. Leerlo del disco
/// cada vez que se abre una parada sería trabajo tirado.
@Riverpod(keepAlive: true)
class FavoriteStops extends _$FavoriteStops {
  @override
  Future<Set<String>> build() => ref.watch(favoritesStoreProvider).loadStops();

  /// Guarda o quita [stopId]. La estrella cambia al instante y el disco se
  /// entera después: esperar a la escritura se sentiría como un botón roto.
  Future<void> toggle(String stopId) async {
    final Set<String> current = await future;
    final Set<String> next = current.contains(stopId)
        ? (<String>{...current}..remove(stopId))
        : <String>{...current, stopId};
    state = AsyncData<Set<String>>(next);
    await ref.read(favoritesStoreProvider).saveStops(next);
  }
}
