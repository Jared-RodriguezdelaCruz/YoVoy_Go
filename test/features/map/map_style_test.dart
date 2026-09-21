import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:yovoy_go/design/tokens/colors.dart';

/// Los estilos del mapa de fondo salen de los tokens.
///
/// `tool/map_styles.py` los genera con los colores copiados de `colors.dart`.
/// Si alguien mueve un token y no regenera el mapa, este test lo avisa: el
/// suelo del mapa y la superficie de la app tienen que ser el mismo color, o
/// la hoja inferior se ve como un parche.
void main() {
  Map<String, dynamic> load(String name) =>
      jsonDecode(File('assets/map/style_$name.json').readAsStringSync())
          as Map<String, dynamic>;

  Map<String, dynamic> layer(Map<String, dynamic> style, String id) =>
      (style['layers'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .firstWhere((Map<String, dynamic> l) => l['id'] == id);

  String hex(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  for (final (String name, AppColors colors) in <(String, AppColors)>[
    ('dark', AppColors.dark),
    ('light', AppColors.light),
  ]) {
    group('style_$name', () {
      final Map<String, dynamic> style = load(name);

      test('el suelo es la superficie de la app', () {
        final Map<String, dynamic> paint =
            layer(style, 'background')['paint'] as Map<String, dynamic>;
        expect(
          (paint['background-color'] as String).toUpperCase(),
          hex(colors.surface),
        );
      });

      test(
        'las etiquetas usan el texto secundario y su halo la superficie',
        () {
          final Map<String, dynamic> paint =
              layer(style, 'label-neighbourhood')['paint']
                  as Map<String, dynamic>;
          expect(
            (paint['text-color'] as String).toUpperCase(),
            hex(colors.textSecondary),
          );
          expect(
            (paint['text-halo-color'] as String).toUpperCase(),
            hex(colors.surface),
          );
        },
      );

      test('no hay POIs, íconos ni números de casa', () {
        final List<Map<String, dynamic>> layers =
            (style['layers'] as List<dynamic>).cast<Map<String, dynamic>>();
        final Set<Object?> sourceLayers = <Object?>{
          for (final Map<String, dynamic> l in layers) l['source-layer'],
        };
        expect(sourceLayers, isNot(contains('poi')));
        expect(sourceLayers, isNot(contains('housenumber')));
        expect(sourceLayers, isNot(contains('aerodrome_label')));
        for (final Map<String, dynamic> l in layers) {
          final Map<String, dynamic> layout =
              (l['layout'] as Map<String, dynamic>?) ?? <String, dynamic>{};
          expect(
            layout.containsKey('icon-image'),
            isFalse,
            reason: '${l['id']} dibuja un ícono',
          );
        }
      });

      test('atribuye a OpenMapTiles y OpenStreetMap', () {
        final Map<String, dynamic> source =
            (style['sources'] as Map<String, dynamic>)['openmaptiles']
                as Map<String, dynamic>;
        expect(source['attribution'], contains('OpenStreetMap'));
        expect(source['attribution'], contains('OpenMapTiles'));
      });
    });
  }

  test('los dos temas tienen las mismas capas, salvo los bordes de calle', () {
    List<String> ids(String name) => <String>[
      for (final dynamic l in load(name)['layers'] as List<dynamic>)
        if (!(l['id'] as String).endsWith('-casing')) l['id'] as String,
    ];
    expect(ids('light'), ids('dark'));
  });
}
