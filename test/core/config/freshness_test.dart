import 'package:flutter_test/flutter_test.dart';
import 'package:yovoy_go/core/config/freshness.dart';

void main() {
  group('Freshness.classify', () {
    test('un dato de segundos está en vivo', () {
      expect(
        Freshness.classify(const Duration(seconds: 30)),
        DataFreshness.live,
      );
    });

    test('los 60 s exactos ya son dato viejo', () {
      expect(
        Freshness.classify(const Duration(seconds: 59)),
        DataFreshness.live,
      );
      expect(
        Freshness.classify(const Duration(seconds: 60)),
        DataFreshness.stale,
      );
    });

    test('entre 60 y 180 s el dato es viejo', () {
      expect(
        Freshness.classify(const Duration(seconds: 120)),
        DataFreshness.stale,
      );
    });

    test('los 180 s exactos siguen siendo dato viejo', () {
      expect(
        Freshness.classify(const Duration(seconds: 180)),
        DataFreshness.stale,
      );
      expect(
        Freshness.classify(const Duration(seconds: 181)),
        DataFreshness.unknown,
      );
    });

    test('más de 3 minutos es desconocido', () {
      expect(
        Freshness.classify(const Duration(minutes: 10)),
        DataFreshness.unknown,
      );
    });
  });

  group('Freshness.allowsNumericEta', () {
    test('nunca se muestra un ETA numérico con dato desconocido', () {
      expect(Freshness.allowsNumericEta(DataFreshness.unknown), isFalse);
    });

    test('el dato viejo sí muestra ETA, marcado como viejo', () {
      expect(Freshness.allowsNumericEta(DataFreshness.live), isTrue);
      expect(Freshness.allowsNumericEta(DataFreshness.stale), isTrue);
    });
  });
}
