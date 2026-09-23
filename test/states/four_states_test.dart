import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yovoy_go/app/routes.dart';
import 'package:yovoy_go/core/data/mock/mock_dataset.dart';
import 'package:yovoy_go/core/data/mock/simulator_config.dart';
import 'package:yovoy_go/design/components/components.dart';
import 'package:yovoy_go/features/route/presentation/route_stop_ladder.dart';

import '../helpers/screen_harness.dart';

/// Los cuatro estados obligatorios de la sección 9 del spec, pantalla por
/// pantalla y con el simulador empujado a cada uno.
///
/// - **Cargando**: esqueleto con la forma del contenido, nunca un spinner.
/// - **Vacío**: qué pasó y qué puede hacer el usuario.
/// - **Error**: qué falló, en su idioma, con reintentar.
/// - **Dato viejo**: el contenido sigue ahí, marcado.
///
/// El cuarto es el que distingue esta app y el más fácil de romper sin darse
/// cuenta: basta con que alguien cambie un `switch` para que la pantalla se
/// vacíe cuando el dato envejece, y eso se vería como una falla de red y no
/// como lo que sería —una decisión de producto al revés—.
void main() {
  // El dataset se lee al declarar: los casos lo necesitan para armar rutas.
  final MockDataset dataset = loadTestDataset();

  /// P074, Héroes de Chapultepec: 14 rutas, la parada más concurrida.
  const String busy = '/stop/P074';

  /// P1522 no aparece en ningún viaje del feed. Es una de las dos que hay así,
  /// y es lo que dispara el vacío de verdad en vez de simularlo.
  const String orphan = '/stop/P1522';

  /// La R52 no tiene flota a propósito (`service.json`, `active: false`).
  const String quietRoute = '/route/R_52';
  const String busyRoute = '/route/R_01';

  /// Toda llamada falla. Es la única forma honesta de ver el estado de error:
  /// con 20 % a veces sale y a veces no, y un test así miente la mitad de las
  /// veces.
  const SimulatorConfig broken = SimulatorConfig(errorRate: 1);

  /// Nada falla, pero todo tarda. El estado de carga sin carrera.
  const SimulatorConfig slow = SimulatorConfig(
    errorRate: 0,
    signalLossRate: 0,
    minLatency: Duration(seconds: 3),
    maxLatency: Duration(seconds: 3),
  );

  /// Todos los camiones con la señal perdida. Lo que queda es horario.
  const SimulatorConfig silent = SimulatorConfig(
    errorRate: 0,
    signalLossRate: 1,
    minSignalLoss: Duration(minutes: 3),
    maxSignalLoss: Duration(minutes: 5),
  );

  group('cargando', () {
    testWidgets('la parada enseña la forma del letrero, no un spinner', (
      WidgetTester tester,
    ) async {
      final ProviderContainer box = makeContainer(dataset, config: slow);
      await pumpAt(tester, box, busy, frames: 2);

      expect(find.byType(SheetSkeleton), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await settle(tester, frames: 40);
      await unmount(tester, box);
      // Las peticiones con latencia que ya iban en camino.
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('la ruta no pone un spinner centrado', (
      WidgetTester tester,
    ) async {
      final ProviderContainer box = makeContainer(dataset, config: slow);
      await pumpAt(tester, box, busyRoute, frames: 2);

      expect(find.byType(CircularProgressIndicator), findsNothing);

      await settle(tester, frames: 40);
      await unmount(tester, box);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('el mapa no pone un spinner encima del mapa', (
      WidgetTester tester,
    ) async {
      final ProviderContainer box = makeContainer(dataset, config: slow);
      await pumpMapScreen(tester, box, frames: 2);

      expect(find.byType(CircularProgressIndicator), findsNothing);

      await settle(tester, frames: 40);
      await unmount(tester, box);
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('vacío', () {
    testWidgets('una parada sin rutas lo dice, y dice qué hacer', (
      WidgetTester tester,
    ) async {
      final ProviderContainer box = makeContainer(dataset);
      await pumpAt(tester, box, orphan);

      final EmptyState empty = tester.widget<EmptyState>(
        find.byType(EmptyState),
      );
      expect(empty.message, isNotEmpty);

      await unmount(tester, box);
    });

    testWidgets('una ruta sin camiones lo dice y deja las paradas', (
      WidgetTester tester,
    ) async {
      final ProviderContainer box = makeContainer(dataset);
      await pumpAt(tester, box, quietRoute);

      expect(
        find.text('Ningún camión de esta ruta está reportando ahora.'),
        findsOneWidget,
      );
      // Vacío de camiones no es vacío de pantalla: las paradas sirven igual.
      expect(find.byType(LadderRow), findsWidgets);

      await unmount(tester, box);
    });

    testWidgets('favoritos sin nada dice cómo guardar el primero', (
      WidgetTester tester,
    ) async {
      final ProviderContainer box = makeContainer(dataset);
      await pumpAt(tester, box, AppPaths.favorites);

      final EmptyState empty = tester.widget<EmptyState>(
        find.byType(EmptyState),
      );
      expect(empty.title, 'Todavía no guardas nada');
      expect(empty.message, contains('estrella'));

      await unmount(tester, box);
    });
  });

  group('error', () {
    testWidgets('la parada dice qué falló y ofrece reintentar', (
      WidgetTester tester,
    ) async {
      final ProviderContainer box = makeContainer(dataset, config: broken);
      // Tres reintentos automáticos con espera creciente, y cada intento
      // arrastra la latencia del simulador: hasta 7.4 s antes de rendirse.
      await pumpAt(tester, box, busy, frames: 100);

      expect(find.byType(ErrorState), findsWidgets);
      expect(find.text('Reintentar'), findsWidgets);

      await unmount(tester, box);
    });

    testWidgets('la hoja del mapa dice qué falló y ofrece reintentar', (
      WidgetTester tester,
    ) async {
      final ProviderContainer box = makeContainer(dataset, config: broken);
      await pumpMapScreen(tester, box, frames: 100);

      expect(find.text('Reintentar'), findsWidgets);

      await unmount(tester, box);
    });
  });

  group('dato viejo', () {
    testWidgets('la parada no se vacía: deja las filas y las marca', (
      WidgetTester tester,
    ) async {
      final ProviderContainer box = makeContainer(dataset, config: silent);
      await pumpAt(tester, box, busy, frames: 20);

      // Lo que importa: sigue habiendo contenido.
      expect(find.byType(EtaChip), findsWidgets);
      expect(find.byType(ErrorState), findsNothing);
      // Y se dice que el dato no viene de un camión.
      expect(find.textContaining('horario'), findsWidgets);

      await unmount(tester, box);
    });

    testWidgets('la ruta deja la escalera y no la borra', (
      WidgetTester tester,
    ) async {
      final ProviderContainer box = makeContainer(dataset, config: silent);
      await pumpAt(tester, box, busyRoute, frames: 20);

      expect(find.byType(LadderRow), findsWidgets);
      expect(find.byType(ErrorState), findsNothing);

      await unmount(tester, box);
    });

    testWidgets('el horario que queda debajo trae su fecha', (
      WidgetTester tester,
    ) async {
      final ProviderContainer box = makeContainer(dataset, config: silent);
      await pumpAt(tester, box, busy, frames: 20);

      // Sin camión, lo que se ve sale del feed empacado. Decir de cuándo es
      // ese feed es el mismo principio que marcar un dato viejo, una capa más
      // abajo.
      expect(find.byType(ScheduleNote), findsOneWidget);

      await unmount(tester, box);
    });
  });
}
