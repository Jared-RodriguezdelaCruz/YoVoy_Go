import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yovoy_go/design/gallery/design_gallery_screen.dart';

void main() {
  Future<void> pumpGallery(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: DesignGalleryScreen()));
    await tester.pump();
  }

  testWidgets('la galería se recorre completa sin reventar', (
    WidgetTester tester,
  ) async {
    await pumpGallery(tester);

    // Recorrerla entera importa: un componente que no se construye es un
    // componente que no se revisó.
    for (int i = 0; i < 14; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pump();
      expect(tester.takeException(), isNull);
    }

    expect(find.text('EmptyState y ErrorState'), findsOneWidget);
  });

  testWidgets('el interruptor de tema cambia la superficie', (
    WidgetTester tester,
  ) async {
    await pumpGallery(tester);

    final Color oscuro = tester
        .widget<Scaffold>(find.byType(Scaffold))
        .backgroundColor!;

    await tester.tap(find.byIcon(Icons.light_mode));
    await tester.pumpAndSettle();

    final Color claro = tester
        .widget<Scaffold>(find.byType(Scaffold))
        .backgroundColor!;

    expect(claro, isNot(oscuro));
    expect(claro.computeLuminance(), greaterThan(oscuro.computeLuminance()));
  });

  testWidgets('se puede ver con el texto al 200 %', (
    WidgetTester tester,
  ) async {
    await pumpGallery(tester);

    await tester.tap(find.byIcon(Icons.format_size));
    await tester.pumpAndSettle();
    await tester.tap(find.text('200 %'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
