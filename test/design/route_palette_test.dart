import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yovoy_go/design/tokens/colors.dart';
import 'package:yovoy_go/design/tokens/contrast.dart';
import 'package:yovoy_go/design/tokens/route_palette.dart';

/// Contraste WCAG entre dos colores opacos, con la misma cuenta que usa la app.
double contrastRatio(Color a, Color b) => Contrast.ratio(a, b);

void main() {
  group('RoutePalette', () {
    test('son doce tonos y ninguno se repite', () {
      expect(RoutePalette.tones, hasLength(12));
      expect(RoutePalette.tones.toSet(), hasLength(12));
    });

    test('todos pasan 4.5:1 contra la superficie oscura', () {
      // Es el requisito de la sección 6.2 del spec: un color de ruta que no
      // se distingue del fondo no identifica nada.
      for (final Color tone in RoutePalette.tones) {
        expect(
          contrastRatio(tone, AppColors.dark.surface),
          greaterThanOrEqualTo(4.5),
          reason: 'el tono $tone no contrasta contra la superficie oscura',
        );
      }
    });

    test('en tema claro, el tono que no contrasta pide contorno', () {
      // Bajar toda la paleta hasta que pase 3:1 sobre blanco la volvería una
      // fila de tonos apagados y casi iguales entre sí, que es justo lo que no
      // debe pasar: el color de ruta existe para distinguirlas. La salida es
      // el contorno, y esto verifica que la regla se aplica a cada tono.
      for (final Color tone in RoutePalette.tones) {
        final bool contrasta =
            contrastRatio(tone, AppColors.light.surface) >= Contrast.minGraphic;

        expect(
          RoutePalette.needsOutline(tone, AppColors.light.surface),
          !contrasta,
          reason: 'el tono $tone no decide bien si lleva contorno',
        );
      }
    });

    test('en tema oscuro ningún tono necesita contorno', () {
      for (final Color tone in RoutePalette.tones) {
        expect(
          RoutePalette.needsOutline(tone, AppColors.dark.surface),
          isFalse,
        );
      }
    });

    test('ninguno repite un color con significado propio', () {
      // Un color, un significado: si una ruta fuera exactamente del verde de
      // "en vivo", el usuario dejaría de poder leer el estado. Lo mismo con la
      // marca y con cantera, que dice de quién es el dato.
      final List<Color> reservados = <Color>[
        for (final AppColors colors in <AppColors>[
          AppColors.dark,
          AppColors.light,
        ]) ...<Color>[
          colors.live,
          colors.stale,
          colors.unknown,
          colors.alert,
          colors.brand,
          colors.cantera,
        ],
      ];

      for (final Color tone in RoutePalette.tones) {
        expect(reservados, isNot(contains(tone)));
      }
    });

    test('el color de una ruta es el mismo siempre', () {
      // Con el hashCode de Dart esto fallaría entre ejecuciones: la ruta 20
      // sería azul hoy y morada mañana.
      final Color primera = RoutePalette.colorForRouteId('r20');

      for (int i = 0; i < 50; i++) {
        expect(RoutePalette.colorForRouteId('r20'), primera);
      }
      expect(RoutePalette.colorForRouteId('r31'), isNot(primera));
    });

    test('el color de GTFS gana sobre el hash', () {
      expect(
        RoutePalette.colorForRoute(routeId: 'r20', gtfsColor: '00854A'),
        const Color(0xFF00854A),
      );
    });

    test('un color de GTFS inválido degrada a la paleta, no revienta', () {
      expect(RoutePalette.parseGtfsColor('xyz'), isNull);
      expect(RoutePalette.parseGtfsColor('12345'), isNull);
      expect(RoutePalette.parseGtfsColor(null), isNull);
      expect(
        RoutePalette.colorForRoute(routeId: 'r20', gtfsColor: 'no-es-color'),
        RoutePalette.colorForRouteId('r20'),
      );
    });

    test('acepta el hexadecimal con numeral, por si acaso', () {
      expect(RoutePalette.parseGtfsColor('#00854A'), const Color(0xFF00854A));
    });

    group('onColor', () {
      test('texto oscuro sobre un fondo claro', () {
        expect(
          RoutePalette.onColor(const Color(0xFFF5C542)),
          const Color(0xFF0E1412),
        );
      });

      test('texto claro sobre un fondo oscuro', () {
        expect(
          RoutePalette.onColor(const Color(0xFF1B3A6B)),
          const Color(0xFFFFFFFF),
        );
      });

      test('la tinta que declara GTFS se respeta si se puede leer', () {
        // El feed oficial trae `route_text_color` en sus 48 rutas. Cuando es
        // legible manda el feed: es parte de la identidad de la ruta.
        expect(
          RoutePalette.inkFor(const Color(0xFF1125FA), gtfsTextColor: 'F0F0F0'),
          const Color(0xFFF0F0F0),
        );
      });

      test('la tinta ilegible del feed cae a la calculada', () {
        // La R-08 del feed es #C4CBA6 con tinta #F0F0F0: 1.5:1. El feed manda
        // en identidad, no en legibilidad.
        const Color r08 = Color(0xFFC4CBA6);
        final Color tinta = RoutePalette.inkFor(r08, gtfsTextColor: 'F0F0F0');

        expect(tinta, isNot(const Color(0xFFF0F0F0)));
        expect(contrastRatio(tinta, r08), greaterThanOrEqualTo(4.5));
      });

      test('una tinta de GTFS inválida no tumba la placa', () {
        expect(
          RoutePalette.inkFor(const Color(0xFF1B3A6B), gtfsTextColor: 'nope'),
          RoutePalette.onColor(const Color(0xFF1B3A6B)),
        );
      });

      test('el texto elegido siempre pasa 4.5:1 contra su placa', () {
        for (final Color tone in RoutePalette.tones) {
          expect(
            contrastRatio(RoutePalette.onColor(tone), tone),
            greaterThanOrEqualTo(4.5),
            reason: 'el texto sobre $tone no es legible',
          );
        }
      });
    });
  });

  group('AppColors', () {
    test('los estados de tiempo real no reutilizan el verde de marca', () {
      for (final AppColors colors in <AppColors>[
        AppColors.dark,
        AppColors.light,
      ]) {
        expect(colors.live, isNot(colors.brand));
        expect(colors.stale, isNot(colors.brand));
        expect(colors.unknown, isNot(colors.brand));
        expect(colors.alert, isNot(colors.brand));
      }
    });

    test('el texto pasa 4.5:1 en los dos temas', () {
      for (final AppColors colors in <AppColors>[
        AppColors.dark,
        AppColors.light,
      ]) {
        expect(
          contrastRatio(colors.textPrimary, colors.surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrastRatio(colors.textSecondary, colors.surface),
          greaterThanOrEqualTo(4.5),
        );
      }
    });

    test('los cuatro estados pasan 4.5:1 en los dos temas', () {
      // Esta es la razón de que el tema claro no reuse los mismos hex: el
      // verde de "en vivo" sobre blanco da 2:1 y sería ilegible al sol.
      for (final AppColors colors in <AppColors>[
        AppColors.dark,
        AppColors.light,
      ]) {
        for (final Color estado in <Color>[
          colors.live,
          colors.stale,
          colors.unknown,
          colors.alert,
        ]) {
          expect(
            contrastRatio(estado, colors.surface),
            greaterThanOrEqualTo(4.5),
            reason: 'el estado $estado no es legible sobre ${colors.surface}',
          );
        }
      }
    });

    test('la marca se lee sobre su propia superficie, en los dos temas', () {
      // Este test faltaba, y su ausencia costó caro: el `#00854A` que la app
      // usó durante tres fases daba 3.95:1 contra la superficie oscura y nadie
      // se enteró. El índigo institucional es oscuro, así que el tema oscuro
      // usa el mismo color aclarado.
      for (final AppColors colors in <AppColors>[
        AppColors.dark,
        AppColors.light,
      ]) {
        expect(
          contrastRatio(colors.brand, colors.surface),
          greaterThanOrEqualTo(4.5),
          reason: 'la marca ${colors.brand} no se lee sobre ${colors.surface}',
        );
      }
    });

    test('la marca del tema claro es el índigo institucional, tal cual', () {
      // Extraído con cuentagotas de la app oficial y de la Tarjeta Soluciones
      // YoVoy. No se redondea ni se "mejora": es el color del sistema.
      expect(AppColors.light.brand, const Color(0xFF3A3578));
    });

    test('cantera se lee, y no se confunde con ningún estado', () {
      for (final AppColors colors in <AppColors>[
        AppColors.dark,
        AppColors.light,
      ]) {
        expect(
          contrastRatio(colors.cantera, colors.surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrastRatio(colors.onCantera, colors.cantera),
          greaterThanOrEqualTo(4.5),
        );
        // Un color, un significado: cantera marca lo que es tuyo y no puede
        // ser además un estado del dato.
        expect(colors.cantera, isNot(colors.live));
        expect(colors.cantera, isNot(colors.stale));
        expect(colors.cantera, isNot(colors.unknown));
        expect(colors.cantera, isNot(colors.alert));
        expect(colors.cantera, isNot(colors.brand));
      }
    });

    test('el texto sobre la marca es legible', () {
      for (final AppColors colors in <AppColors>[
        AppColors.dark,
        AppColors.light,
      ]) {
        expect(
          contrastRatio(colors.onBrand, colors.brand),
          greaterThanOrEqualTo(4.5),
        );
      }
    });

    test('lerp entre temas no pierde ningún token', () {
      final AppColors medio = AppColors.dark.lerp(AppColors.light, 0.5);

      expect(medio.surface, isNot(AppColors.dark.surface));
      expect(medio.live, isNot(AppColors.dark.live));
    });
  });
}
