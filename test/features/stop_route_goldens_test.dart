import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yovoy_go/core/data/mock/mock_dataset.dart';
import 'package:yovoy_go/design/theme.dart';
import 'package:yovoy_go/features/route/presentation/route_screen.dart';
import 'package:yovoy_go/features/stop/presentation/stop_board_screen.dart';
import 'package:yovoy_go/features/stop/presentation/stop_screen.dart';

import '../helpers/golden_fonts.dart';
import '../helpers/screen_harness.dart';

/// Fotos de la parada y la ruta, para **verlas** sin emulador.
///
/// El reloj va fijo —lunes 21 de septiembre de 2026, 8:00— para que la flota
/// salga igual cada vez. El fondo vectorial del minimapa no se dibuja: pide
/// red. Se regeneran con `flutter test --update-goldens`.
void main() {
  late MockDataset dataset;
  // Un minuto después de las 8: el R37 ya pasó y el protagonista trae número.
  final DateTime board = eightAm.add(const Duration(minutes: 1));

  setUpAll(() async {
    await loadAppFonts();
    dataset = loadTestDataset();
  });

  testWidgets('parada, tema oscuro', (WidgetTester tester) async {
    final ProviderContainer container = makeContainer(dataset);
    await pumpAt(tester, container, '/stop/P074');
    await expectLater(
      find.byType(StopScreen),
      matchesGoldenFile('stop/goldens/stop_dark.png'),
    );
    await unmount(tester, container);
  });

  testWidgets('parada, tema claro', (WidgetTester tester) async {
    final ProviderContainer container = makeContainer(dataset);
    await pumpAt(tester, container, '/stop/P074', theme: AppTheme.light);
    await expectLater(
      find.byType(StopScreen),
      matchesGoldenFile('stop/goldens/stop_light.png'),
    );
    await unmount(tester, container);
  });

  testWidgets('modo paradero, tema oscuro', (WidgetTester tester) async {
    final ProviderContainer container = makeContainer(dataset, now: board);
    await pumpAt(tester, container, '/stop/P074/board');
    await expectLater(
      find.byType(StopBoardScreen),
      matchesGoldenFile('stop/goldens/stop_board_dark.png'),
    );
    await unmount(tester, container);
  });

  testWidgets('modo paradero, tema claro', (WidgetTester tester) async {
    final ProviderContainer container = makeContainer(dataset, now: board);
    await pumpAt(tester, container, '/stop/P074/board', theme: AppTheme.light);
    await expectLater(
      find.byType(StopBoardScreen),
      matchesGoldenFile('stop/goldens/stop_board_light.png'),
    );
    await unmount(tester, container);
  });

  testWidgets('ruta con camiones, tema oscuro', (WidgetTester tester) async {
    final ProviderContainer container = makeContainer(dataset);
    await pumpAt(tester, container, '/route/R_01');
    await expectLater(
      find.byType(RouteScreen),
      matchesGoldenFile('route/goldens/route_dark.png'),
    );
    await unmount(tester, container);
  });

  testWidgets('ruta sin camiones, tema oscuro', (WidgetTester tester) async {
    final ProviderContainer container = makeContainer(dataset);
    await pumpAt(tester, container, '/route/R_52');
    await expectLater(
      find.byType(RouteScreen),
      matchesGoldenFile('route/goldens/route_no_vehicles_dark.png'),
    );
    await unmount(tester, container);
  });
}
