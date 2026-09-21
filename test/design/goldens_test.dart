import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yovoy_go/core/models/models.dart';
import 'package:yovoy_go/design/components/components.dart';
import 'package:yovoy_go/design/theme.dart';
import 'package:yovoy_go/design/tokens/colors.dart';
import 'package:yovoy_go/design/tokens/route_palette.dart';
import 'package:yovoy_go/design/tokens/spacing.dart';
import 'package:yovoy_go/design/tokens/typography.dart';

import '../helpers/golden_fonts.dart';

/// Imágenes de referencia del design system.
///
/// No son solo una red contra regresiones: son la forma de **ver** los
/// componentes sin emulador ni dispositivo. Los PNG viven en
/// `test/design/goldens/` y se abren como cualquier imagen.
///
/// Se regeneran con `flutter test --update-goldens`. Si alguno sale en rojo
/// después de un cambio de Flutter o de máquina, se regenera: es una foto, no
/// una aserción de comportamiento.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadAppFonts();
  });

  testWidgets('los cuatro estados del ETA', (WidgetTester tester) async {
    await _pumpSheet(
      tester,
      size: const Size(560, 440),
      title: 'EtaChip · los cuatro estados',
      child: const _EtaRow(),
    );

    await expectLater(
      find.byKey(_sheetKey),
      matchesGoldenFile('goldens/eta_chip_states.png'),
    );
  });

  testWidgets('la paleta de rutas', (WidgetTester tester) async {
    await _pumpSheet(
      tester,
      size: const Size(560, 360),
      title: 'RouteBadge · los doce tonos',
      child: const _PaletteRow(),
    );

    await expectLater(
      find.byKey(_sheetKey),
      matchesGoldenFile('goldens/route_badge_palette.png'),
    );
  });

  testWidgets('una parada con arribos de distinta frescura', (
    WidgetTester tester,
  ) async {
    await _pumpSheet(
      tester,
      size: const Size(560, 760),
      title: 'StopTile · una parada real',
      child: const _StopTileSample(),
    );

    await expectLater(
      find.byKey(_sheetKey),
      matchesGoldenFile('goldens/stop_tile.png'),
    );
  });

  testWidgets('la tira, encendida y apagada', (WidgetTester tester) async {
    await _pumpSheet(
      tester,
      size: const Size(560, 700),
      title: 'RouteStrip · la luz encendida y apagada',
      child: const _StripSample(),
    );

    await expectLater(
      find.byKey(_sheetKey),
      matchesGoldenFile('goldens/route_strip.png'),
    );
  });

  testWidgets('el vacío, el error y el camión', (WidgetTester tester) async {
    await _pumpSheet(
      tester,
      size: const Size(560, 1320),
      title: 'EmptyState, ErrorState y VehicleMarker',
      child: const _StatesSample(),
    );

    await expectLater(
      find.byKey(_sheetKey),
      matchesGoldenFile('goldens/empty_and_error.png'),
    );
  });
}

const Key _sheetKey = Key('golden-sheet');

/// Una hoja con el mismo contenido en los dos temas, uno encima del otro.
Future<void> _pumpSheet(
  WidgetTester tester, {
  required Size size,
  required String title,
  required Widget child,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(
        key: _sheetKey,
        child: Column(
          children: <Widget>[
            Expanded(
              child: _Panel(
                theme: AppTheme.dark,
                title: '$title · oscuro',
                child: child,
              ),
            ),
            Expanded(
              child: _Panel(
                theme: AppTheme.light,
                title: '$title · claro',
                child: child,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _Panel extends StatelessWidget {
  const _Panel({required this.theme, required this.title, required this.child});

  final ThemeData theme;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: theme,
      child: Builder(
        builder: (BuildContext context) {
          final AppColors colors = context.colors;
          return Material(
            color: colors.surface,
            child: Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: AppTypography.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: Spacing.md),
                  Expanded(child: child),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Contenido de cada hoja
// ---------------------------------------------------------------------------

class _EtaRow extends StatelessWidget {
  const _EtaRow();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Spacing.lg,
      runSpacing: Spacing.lg,
      children: const <Widget>[
        EtaChip(
          eta: Duration(minutes: 4),
          confidence: EtaConfidence.live,
          dataAge: Duration(seconds: 12),
        ),
        EtaChip(
          eta: Duration(minutes: 7),
          confidence: EtaConfidence.live,
          dataAge: Duration(seconds: 130),
        ),
        EtaChip(
          eta: Duration(minutes: 12),
          confidence: EtaConfidence.scheduled,
          dataAge: Duration(seconds: 20),
        ),
        EtaChip(
          eta: Duration(minutes: 4),
          confidence: EtaConfidence.live,
          dataAge: Duration(minutes: 9),
        ),
        EtaChip(
          eta: null,
          confidence: EtaConfidence.unknown,
          dataAge: Duration(minutes: 20),
          scheduledTimeLabel: '7:04',
        ),
        // Sin `pulse`: el pulso es infinito y la foto tendría que esperarlo.
        FreshnessIndicator(dataAge: Duration(seconds: 15)),
        FreshnessIndicator(dataAge: Duration(seconds: 130)),
        FreshnessIndicator(dataAge: Duration(minutes: 9)),
      ],
    );
  }
}

class _PaletteRow extends StatelessWidget {
  const _PaletteRow();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Spacing.sm,
      runSpacing: Spacing.sm,
      children: <Widget>[
        for (int i = 0; i < RoutePalette.tones.length; i++)
          RouteBadge(
            shortName: '${i + 1}0',
            routeId: 'tono-$i',
            gtfsColor: RoutePalette.tones[i]
                .toARGB32()
                .toRadixString(16)
                .substring(2),
          ),
      ],
    );
  }
}

class _StopTileSample extends StatelessWidget {
  const _StopTileSample();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.topCenter,
      child: StopTile(
        name: 'Bonanza',
        code: 'B-12',
        distanceLabel: 'a 240 m',
        accessibility: WheelchairBoarding.accessible,
        isFavorite: true,
        arrivals: <Arrival>[
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
            routeId: 'r44',
            routeShortName: '44',
            headsign: 'Insurgentes',
            dataAge: Duration(minutes: 7),
          ),
        ],
      ),
    );
  }
}

class _StatesSample extends StatelessWidget {
  const _StatesSample();

  @override
  Widget build(BuildContext context) {
    final Color color = RoutePalette.colorForRouteId('r20');

    return Column(
      children: <Widget>[
        Expanded(
          child: EmptyState(
            icon: Icons.directions_bus_filled_outlined,
            title: 'Esta ruta no tiene servicio ahora',
            message: 'El último camión pasó a las 21:40.',
            actionLabel: 'Ver el horario',
            onAction: () {},
          ),
        ),
        Expanded(
          child: ErrorState(
            title: 'No se pudo cargar la parada',
            message: 'Revisa tu conexión y vuelve a intentar.',
            onRetry: () {},
          ),
        ),
        Wrap(
          spacing: Spacing.lg,
          children: <Widget>[
            VehicleMarker(color: color, bearing: 0),
            VehicleMarker(color: color, bearing: 120),
            VehicleMarker(color: color),
            VehicleMarker(color: color, bearing: 45, isStale: true),
          ],
        ),
      ],
    );
  }
}

class _StripSample extends StatelessWidget {
  const _StripSample();

  static const List<String> _paradas = <String>[
    'Bonanza',
    'Héroes',
    'CBTIS',
    'Centro',
    'Terminal Sur',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        // En vivo: el halo encendido y el índigo entero.
        const RouteStrip(
          stops: _paradas,
          vehicleProgress: 0.55,
          dataAge: Duration(seconds: 20),
        ),
        const RouteStrip(
          stops: _paradas,
          vehicleProgress: 0.38,
          dataAge: Duration(seconds: 120),
        ),
        // Sin señal: sin halo, el índigo en gris y el trazo punteado.
        const RouteStrip(
          stops: _paradas,
          vehicleProgress: 0.22,
          dataAge: Duration(minutes: 9),
        ),
        LitSurface(
          padding: const EdgeInsets.all(Spacing.md),
          child: Text(
            'Sal en 6 min para alcanzarlo',
            style: AppTypography.body.copyWith(color: context.colors.cantera),
          ),
        ),
      ],
    );
  }
}
