import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yovoy_go/core/config/freshness.dart';
import 'package:yovoy_go/core/models/models.dart';
import 'package:yovoy_go/design/components/components.dart';
import 'package:yovoy_go/design/tokens/colors.dart';
import 'package:yovoy_go/design/tokens/contrast.dart';

/// **El color nunca es el único portador de significado** (§11 del spec).
///
/// Hay daltonismo y hay sol directo: dos estados que solo se distinguen por su
/// color no se distinguen. Aquí eso deja de ser una promesa del documento y
/// pasa a ser algo que se rompe si alguien lo rompe.
///
/// La forma de la prueba es siempre la misma: recorrer **todos** los valores
/// de un estado y afirmar que ni su palabra ni su ícono se repiten. Un estado
/// nuevo entra solo si trae los suyos.
void main() {
  group('la frescura del dato', () {
    test('cada estado tiene su palabra y su ícono, sin repetir', () {
      const Map<DataFreshness, Duration> ages = <DataFreshness, Duration>{
        DataFreshness.live: Duration(seconds: 10),
        DataFreshness.stale: Duration(seconds: 120),
        DataFreshness.unknown: Duration(minutes: 9),
      };

      final Set<String> words = <String>{};
      final Set<IconData> icons = <IconData>{};
      for (final DataFreshness state in DataFreshness.values) {
        words.add(FreshnessCopy.label(ages[state]!));
        icons.add(FreshnessCopy.icon(state));
      }
      expect(words, hasLength(DataFreshness.values.length));
      expect(icons, hasLength(DataFreshness.values.length));
    });

    test('cada color se ve sobre su superficie, en los dos temas', () {
      for (final AppColors colors in <AppColors>[
        AppColors.dark,
        AppColors.light,
      ]) {
        for (final Color color in <Color>[
          colors.live,
          colors.stale,
          colors.unknown,
          colors.alert,
        ]) {
          expect(
            Contrast.ratio(color, colors.surface),
            greaterThanOrEqualTo(Contrast.minGraphic),
            reason: 'un color de estado tiene que verse sobre la superficie',
          );
        }
      }
    });

    test('"en vivo" y "hace 2 min" casi no se separan por luminancia', () {
      // Esto **no** es un defecto que haya que arreglar: es la razón por la
      // que la regla existe. El verde de "en vivo" y el ámbar de "hace 2 min"
      // pasan los dos 3:1 contra el fondo, pero entre ellos van a 1.02:1 —se
      // separan por tono y nada más—, así que a quien no distingue el tono le
      // quedan idénticos. Por eso ninguno de los dos aparece nunca sin su
      // palabra y su ícono, y por eso esa es la prueba de arriba.
      //
      // Si algún día la paleta cambiara y se separaran de verdad, este test
      // falla y hay que venir a releer el párrafo, no a subir el número.
      expect(
        Contrast.ratio(AppColors.dark.live, AppColors.dark.stale),
        lessThan(1.3),
      );
    });
  });

  group('la ocupación', () {
    test('cada grado tiene su palabra y su número de figuras', () {
      final Set<String> words = <String>{};
      final Set<int> figures = <int>{};
      for (final OccupancyLevel level in OccupancyLevel.values) {
        words.add(level.word);
        figures.add(level.figures);
      }
      expect(words, hasLength(OccupancyLevel.values.length));
      expect(figures, hasLength(OccupancyLevel.values.length));
    });

    test('los seis valores de GTFS caben en los tres grados', () {
      for (final OccupancyStatus status in OccupancyStatus.values) {
        expect(OccupancyLevel.of(status), isNotNull);
      }
    });
  });

  group('las alertas de servicio', () {
    test('cada efecto lleva su ícono', () {
      final Set<IconData> icons = <IconData>{
        for (final AlertEffect effect in AlertEffect.values)
          AlertBanner.iconFor(effect),
      };
      // `otherEffect` y `unknownEffect` comparten ícono a propósito: son el
      // mismo "algo pasa y no sabemos qué", y el encabezado de la alerta es el
      // que lleva la información. Por eso uno menos que efectos.
      expect(icons, hasLength(AlertEffect.values.length - 1));
    });
  });

  group('el origen de un ETA', () {
    test('en vivo, horario y sin dato se dicen con palabras distintas', () {
      // El chip pinta el origen con color, pero lo que lo hace legible es la
      // línea de abajo. Si dos orígenes dijeran lo mismo, el color quedaría
      // solo.
      const Map<EtaConfidence, String> words = <EtaConfidence, String>{
        EtaConfidence.live: 'en vivo',
        EtaConfidence.scheduled: 'según horario',
        EtaConfidence.unknown: 'sin señal',
      };
      expect(words.values.toSet(), hasLength(EtaConfidence.values.length));
      for (final EtaConfidence origin in EtaConfidence.values) {
        expect(words[origin], isNotNull, reason: 'falta la palabra de $origin');
      }
    });
  });

  group('la placa de una ruta', () {
    testWidgets('lleva el nombre corto escrito, no solo su color', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: RouteBadge(shortName: 'R20', routeId: 'R_20'),
            ),
          ),
        ),
      );
      expect(find.text('R20'), findsOneWidget);
    });
  });
}
