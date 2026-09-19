import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yovoy_go/app/app.dart';
import 'package:yovoy_go/app/router.dart';
import 'package:yovoy_go/app/routes.dart';
import 'package:yovoy_go/features/map/presentation/map_screen.dart';
import 'package:yovoy_go/features/settings/presentation/settings_screen.dart';
import 'package:yovoy_go/features/stop/presentation/stop_screen.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const YoVoyGoApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('la ruta inicial es el mapa', (WidgetTester tester) async {
    await pumpApp(tester);

    expect(find.byType(MapScreen), findsOneWidget);
  });

  testWidgets('navegar por nombre llega a ajustes', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    container.read(appRouterProvider).goNamed(AppRoute.settings.name);
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('la parada recibe su parámetro de path', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    container.read(appRouterProvider).go(AppPaths.stop('123'));
    await tester.pumpAndSettle();

    expect(find.byType(StopScreen), findsOneWidget);
    expect(find.text('stopId: 123'), findsOneWidget);
  });

  testWidgets('una ruta inexistente cae en la pantalla de error propia', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    container.read(appRouterProvider).go('/no-existe');
    await tester.pumpAndSettle();

    expect(find.text('Esta pantalla no existe'), findsOneWidget);
    expect(find.text('/no-existe'), findsOneWidget);
  });
}
