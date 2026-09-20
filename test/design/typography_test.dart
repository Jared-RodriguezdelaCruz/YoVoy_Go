import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yovoy_go/design/tokens/typography.dart';

void main() {
  group('AppTypography', () {
    test('el contador va en el ancho más estrecho, y solo él', () {
      // El tercer ancho existe para un rol y se gasta si se usa en más: es lo
      // que hace que 48 px se lean como instrumento y no como titular.
      expect(AppTypography.etaDisplay.fontFamily, 'BarlowCondensed');
      expect(AppTypography.routeBadge.fontFamily, 'BarlowSemiCondensed');
      expect(AppTypography.eta.fontFamily, 'BarlowSemiCondensed');
      expect(AppTypography.body.fontFamily, 'Barlow');
      expect(AppTypography.title.fontFamily, 'Barlow');
    });

    test('el contador lleva tracking negativo', () {
      expect(AppTypography.etaDisplay.letterSpacing, lessThan(0));
      // −2 % de 48 px.
      expect(AppTypography.etaDisplay.letterSpacing, closeTo(-0.96, 0.01));
    });

    test('todo lo que muestra números usa cifras tabulares', () {
      for (final TextStyle style in <TextStyle>[
        AppTypography.etaDisplay,
        AppTypography.routeBadge,
        AppTypography.eta,
      ]) {
        expect(
          style.fontFeatures,
          contains(const FontFeature.tabularFigures()),
        );
      }
    });
  });
}
