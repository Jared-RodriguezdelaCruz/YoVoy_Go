import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yovoy_go/core/models/models.dart';
import 'package:yovoy_go/design/components/components.dart';
import 'package:yovoy_go/design/theme.dart';
import 'package:yovoy_go/design/tokens/motion.dart';
import 'package:yovoy_go/design/tokens/route_palette.dart';

/// La decoración de la placa que contiene [value].
BoxDecoration _plateOf(WidgetTester tester, String value) {
  final DecoratedBox plate = tester.widget<DecoratedBox>(
    find
        .ancestor(of: find.text(value), matching: find.byType(DecoratedBox))
        .first,
  );
  return plate.decoration as BoxDecoration;
}

/// Monta un componente con el tema real de la app.
Future<void> pumpComponent(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.dark,
  double textScale = 1,
  bool disableAnimations = false,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
        ),
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );
}

void main() {
  group('EtaChip', () {
    testWidgets('dato en vivo: muestra los minutos y lo dice', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        const EtaChip(
          eta: Duration(minutes: 4),
          confidence: EtaConfidence.live,
          dataAge: Duration(seconds: 12),
        ),
      );

      expect(find.text('4'), findsOneWidget);
      expect(find.text('min'), findsOneWidget);
      expect(find.text('en vivo'), findsOneWidget);
    });

    testWidgets('dato viejo: sigue mostrando el número, con su edad', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        const EtaChip(
          eta: Duration(minutes: 7),
          confidence: EtaConfidence.live,
          dataAge: Duration(seconds: 130),
        ),
      );

      expect(find.text('7'), findsOneWidget);
      expect(find.text('hace 2 min'), findsOneWidget);
    });

    testWidgets('pasados los 180 s no hay número, aunque haya ETA', (
      WidgetTester tester,
    ) async {
      // Esta es la prueba que sostiene la tesis del producto entero.
      await pumpComponent(
        tester,
        const EtaChip(
          eta: Duration(minutes: 4),
          confidence: EtaConfidence.live,
          dataAge: Duration(minutes: 9),
        ),
      );

      expect(find.text('4'), findsNothing);
      expect(find.text('min'), findsNothing);
      expect(find.text('sin señal'), findsOneWidget);
    });

    testWidgets('confianza desconocida tampoco muestra número', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        const EtaChip(
          eta: Duration(minutes: 4),
          confidence: EtaConfidence.unknown,
          dataAge: Duration(seconds: 10),
        ),
      );

      expect(find.text('4'), findsNothing);
      expect(find.text('sin dato'), findsOneWidget);
    });

    testWidgets('sin ETA pero con horario, da la hora programada', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        const EtaChip(
          eta: null,
          confidence: EtaConfidence.unknown,
          dataAge: Duration(minutes: 20),
          scheduledTimeLabel: '7:04',
        ),
      );

      expect(find.text('7:04'), findsOneWidget);
      expect(find.text('min'), findsNothing);
    });

    testWidgets('horario programado y fresco: número más su origen', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        const EtaChip(
          eta: Duration(minutes: 12),
          confidence: EtaConfidence.scheduled,
          dataAge: Duration(seconds: 20),
        ),
      );

      expect(find.text('12'), findsOneWidget);
      expect(find.text('programado'), findsOneWidget);
      expect(find.text('en vivo'), findsNothing);
    });

    testWidgets('cero minutos se dice con palabras, no con un cero', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        const EtaChip(
          eta: Duration.zero,
          confidence: EtaConfidence.live,
          dataAge: Duration(seconds: 5),
        ),
      );

      expect(find.text('llegando'), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('el estado desconocido aguanta el texto al 200 %', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        const EtaChip(
          eta: null,
          confidence: EtaConfidence.unknown,
          dataAge: Duration(minutes: 20),
        ),
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('sin señal'), findsOneWidget);
    });

    testWidgets('anuncia el ETA completo para lectores de pantalla', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        const EtaChip(
          eta: Duration(minutes: 4),
          confidence: EtaConfidence.live,
          dataAge: Duration(seconds: 12),
        ),
      );

      expect(
        find.bySemanticsLabel('llega en 4 minutos, dato en vivo'),
        findsOneWidget,
      );
    });

    testWidgets('se puede armar desde un arribo', (WidgetTester tester) async {
      await pumpComponent(
        tester,
        EtaChip.fromArrival(
          const Arrival(
            routeId: 'r20',
            routeShortName: '20',
            headsign: 'Centro',
            eta: Duration(minutes: 3),
            confidence: EtaConfidence.live,
            dataAge: Duration(seconds: 8),
          ),
        ),
      );

      expect(find.text('3'), findsOneWidget);
    });
  });

  group('RouteBadge', () {
    Color textColorOf(WidgetTester tester, String value) =>
        tester.widget<Text>(find.text(value)).style!.color!;

    testWidgets('sobre un tono claro, tinta oscura', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        const RouteBadge(shortName: '20', routeId: 'r20', gtfsColor: 'F5C542'),
      );

      expect(textColorOf(tester, '20'), const Color(0xFF0E1412));
    });

    testWidgets('sobre un tono oscuro, tinta clara', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        const RouteBadge(shortName: '20', routeId: 'r20', gtfsColor: '1B3A6B'),
      );

      expect(textColorOf(tester, '20'), const Color(0xFFFFFFFF));
    });

    testWidgets('sin color de GTFS usa el de la paleta', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        const RouteBadge(shortName: '31', routeId: 'r31'),
      );

      expect(_plateOf(tester, '31').color, RoutePalette.colorForRouteId('r31'));
    });

    testWidgets('en tema claro, un tono brillante lleva contorno', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        const RouteBadge(shortName: '20', routeId: 'r20', gtfsColor: 'F2843C'),
        brightness: Brightness.light,
      );

      expect(_plateOf(tester, '20').border, isNotNull);
    });

    testWidgets('en tema oscuro, el mismo tono no lo necesita', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        const RouteBadge(shortName: '20', routeId: 'r20', gtfsColor: 'F2843C'),
      );

      expect(_plateOf(tester, '20').border, isNull);
    });

    testWidgets('se anuncia como ruta, no como número suelto', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        const RouteBadge(shortName: '31-A', routeId: 'r31'),
      );

      expect(find.bySemanticsLabel('Ruta 31-A'), findsOneWidget);
    });
  });

  group('VehicleMarker', () {
    testWidgets('sin bearing se anuncia sin dirección', (
      WidgetTester tester,
    ) async {
      await pumpComponent(tester, const VehicleMarker(color: Colors.teal));

      expect(
        find.bySemanticsLabel('Camión, sin dirección conocida'),
        findsOneWidget,
      );
    });

    testWidgets('con bearing se anuncia en movimiento', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        const VehicleMarker(color: Colors.teal, bearing: 90),
      );

      expect(find.bySemanticsLabel('Camión en movimiento'), findsOneWidget);
    });

    testWidgets('se dibuja sin excepciones en sus tres variantes', (
      WidgetTester tester,
    ) async {
      for (final double? bearing in <double?>[null, 0, 220]) {
        await pumpComponent(
          tester,
          VehicleMarker(color: Colors.orange, bearing: bearing),
        );
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('FreshnessIndicator', () {
    testWidgets('traduce la edad a lenguaje humano', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        const FreshnessIndicator(dataAge: Duration(seconds: 20)),
      );
      expect(find.text('en vivo'), findsOneWidget);

      await pumpComponent(
        tester,
        const FreshnessIndicator(dataAge: Duration(seconds: 125)),
      );
      expect(find.text('hace 2 min'), findsOneWidget);

      await pumpComponent(
        tester,
        const FreshnessIndicator(dataAge: Duration(minutes: 8)),
      );
      expect(find.text('sin señal'), findsOneWidget);
    });

    testWidgets('el pulso no corre si el sistema pide reducir movimiento', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        const FreshnessIndicator(dataAge: Duration(seconds: 10), pulse: true),
        disableAnimations: true,
      );

      // Si el pulso siguiera corriendo, `pumpAndSettle` nunca terminaría.
      await tester.pumpAndSettle();
      expect(find.text('en vivo'), findsOneWidget);
    });
  });

  group('StopTile', () {
    const List<Arrival> arribos = <Arrival>[
      Arrival(
        routeId: 'r20',
        routeShortName: '20',
        headsign: 'Centro',
        eta: Duration(minutes: 4),
        confidence: EtaConfidence.live,
        dataAge: Duration(seconds: 14),
      ),
      Arrival(
        routeId: 'r31',
        routeShortName: '31',
        headsign: 'Morelos',
        eta: Duration(minutes: 11),
        confidence: EtaConfidence.live,
        dataAge: Duration(seconds: 140),
      ),
      Arrival(
        routeId: 'r09',
        routeShortName: '9',
        headsign: 'Norte',
        eta: Duration(minutes: 6),
        confidence: EtaConfidence.scheduled,
        dataAge: Duration(seconds: 25),
      ),
      Arrival(
        routeId: 'r44',
        routeShortName: '44',
        headsign: 'Insurgentes',
        dataAge: Duration(minutes: 7),
      ),
    ];

    testWidgets('muestra los primeros arribos y resume el resto', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        const StopTile(name: 'Bonanza', code: 'B-12', arrivals: arribos),
      );

      expect(find.text('Bonanza'), findsOneWidget);
      expect(find.text('Centro'), findsOneWidget);
      expect(find.text('Insurgentes'), findsNothing);
      expect(find.text('1 ruta más'), findsOneWidget);
    });

    testWidgets('sin arribos lo dice con palabras, no con una lista vacía', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        const StopTile(name: 'Héroes', arrivals: <Arrival>[]),
      );

      expect(find.text('Sin camiones en camino ahora'), findsOneWidget);
    });

    testWidgets('el botón de favorito responde', (WidgetTester tester) async {
      int toques = 0;

      await pumpComponent(
        tester,
        StopTile(
          name: 'Bonanza',
          arrivals: const <Arrival>[],
          onToggleFavorite: () => toques++,
        ),
      );
      await tester.tap(find.byIcon(Icons.star_border));

      expect(toques, 1);
    });

    testWidgets('aguanta el texto al 200 % sin desbordarse', (
      WidgetTester tester,
    ) async {
      // En la app la parada vive dentro de una lista, así que se prueba
      // dentro de una lista: lo que importa es que no se desborde a lo ancho.
      await pumpComponent(
        tester,
        SizedBox(
          width: 360,
          child: ListView(
            children: const <Widget>[
              StopTile(
                name: 'Avenida de la Convención',
                code: 'C-04',
                arrivals: arribos,
              ),
            ],
          ),
        ),
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('EmptyState y ErrorState', () {
    testWidgets('el vacío explica y ofrece una salida', (
      WidgetTester tester,
    ) async {
      int toques = 0;

      await pumpComponent(
        tester,
        EmptyState(
          icon: Icons.directions_bus_filled_outlined,
          title: 'Esta ruta no tiene servicio ahora',
          message: 'El último camión pasó a las 21:40.',
          actionLabel: 'Ver el horario',
          onAction: () => toques++,
        ),
      );
      await tester.tap(find.text('Ver el horario'));

      expect(toques, 1);
      expect(find.text('Esta ruta no tiene servicio ahora'), findsOneWidget);
    });

    testWidgets('el error ofrece reintentar', (WidgetTester tester) async {
      int reintentos = 0;

      await pumpComponent(
        tester,
        ErrorState(
          title: 'No se pudo cargar la parada',
          message: 'Revisa tu conexión y vuelve a intentar.',
          onRetry: () => reintentos++,
        ),
      );
      await tester.tap(find.text('Reintentar'));

      expect(reintentos, 1);
    });
  });

  group('AppMotion', () {
    testWidgets('las animaciones se anulan si el sistema lo pide', (
      WidgetTester tester,
    ) async {
      late Duration conAnimacion;
      late Duration sinAnimacion;

      await pumpComponent(
        tester,
        Builder(
          builder: (BuildContext context) {
            conAnimacion = AppMotion.resolve(context, AppMotion.standard);
            return const SizedBox.shrink();
          },
        ),
      );
      await pumpComponent(
        tester,
        Builder(
          builder: (BuildContext context) {
            sinAnimacion = AppMotion.resolve(context, AppMotion.standard);
            return const SizedBox.shrink();
          },
        ),
        disableAnimations: true,
      );

      expect(conAnimacion, AppMotion.standard);
      expect(sinAnimacion, Duration.zero);
    });
  });
}
