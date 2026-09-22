import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yovoy_go/app/routes.dart';
import 'package:yovoy_go/core/data/mock/mock_dataset.dart';
import 'package:yovoy_go/core/models/models.dart';
import 'package:yovoy_go/features/favorites/data/favorites_store.dart';
import 'package:yovoy_go/features/favorites/presentation/favorites_screen.dart';
import 'package:yovoy_go/features/settings/presentation/about_screen.dart';
import 'package:yovoy_go/features/settings/presentation/settings_screen.dart';

import '../../helpers/golden_fonts.dart';
import '../../helpers/screen_harness.dart';

/// Fotos de lo que la app recuerda y de lo que dice de sí misma. Se
/// regeneran con `flutter test --update-goldens`.
void main() {
  late MockDataset dataset;

  setUpAll(() async {
    await loadAppFonts();
    dataset = loadTestDataset();
  });

  testWidgets('favoritos, tema oscuro', (WidgetTester tester) async {
    final Stop stop = dataset.stops.firstWhere(
      (Stop s) => dataset.tripsForStop(s.id).isNotEmpty,
    );
    final ProviderContainer container = makeContainer(
      dataset,
      favorites: InMemoryFavoritesStore(
        <String>{stop.id},
        <String>{dataset.routes.first.id},
      ),
    );
    await pumpAt(tester, container, AppPaths.favorites);
    await expectLater(
      find.byType(FavoritesScreen),
      matchesGoldenFile('goldens/favorites_dark.png'),
    );
    await unmount(tester, container);
  });

  testWidgets('ajustes, tema oscuro', (WidgetTester tester) async {
    final ProviderContainer container = makeContainer(dataset);
    await pumpAt(tester, container, AppPaths.settings);
    await expectLater(
      find.byType(SettingsScreen),
      matchesGoldenFile('goldens/settings_dark.png'),
    );
    await unmount(tester, container);
  });

  testWidgets('acerca de, tema oscuro', (WidgetTester tester) async {
    final ProviderContainer container = makeContainer(dataset);
    await pumpAt(tester, container, AppPaths.about);
    await expectLater(
      find.byType(AboutScreen),
      matchesGoldenFile('goldens/about_dark.png'),
    );
    await unmount(tester, container);
  });
}
