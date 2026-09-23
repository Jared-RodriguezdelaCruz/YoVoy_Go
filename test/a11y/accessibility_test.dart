import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yovoy_go/app/routes.dart';
import 'package:yovoy_go/core/data/mock/mock_dataset.dart';
import 'package:yovoy_go/design/theme.dart';
import 'package:yovoy_go/features/favorites/data/favorites_store.dart';
import 'package:yovoy_go/features/planner/application/trip_request.dart';

import '../helpers/golden_fonts.dart';
import '../helpers/screen_harness.dart';

/// La auditoría de accesibilidad de la sección 11 del spec, hecha máquina.
///
/// Los tres pisos que Flutter sabe medir solo —contraste de 4.5:1, toque de
/// 48×48 dp y ningún botón sin nombre— se corren sobre **cada pantalla, en los
/// dos temas**. Lo que ningún matcher sabe leer —que un ETA se anuncie
/// completo, que el orden de lectura tenga sentido— se revisa con TalkBack en
/// el teléfono, y eso queda anotado en el ROADMAP.
///
/// Que esto sea una tabla y no una lista de casos es a propósito: una pantalla
/// nueva se audita agregando un renglón, y olvidarlo se nota.
void main() {
  // El dataset se lee aquí y no en `setUpAll` porque la tabla de pantallas se
  // arma al declarar los casos, antes de que corra cualquier `setUp`.
  final MockDataset dataset = loadTestDataset();
  const String stopId = 'P074';
  final String routeId = dataset.routes.first.id;
  final PrecookedTrip pair = dataset.precookedTrips.firstWhere(
    (PrecookedTrip p) => p.id == 'dos_transbordos',
  );
  final TripRequest trip = TripRequest(
    from: PointPlace(pair.from),
    to: PointPlace(pair.to),
  );

  setUpAll(loadAppFonts);

  String query(String path) =>
      Uri(path: path, queryParameters: trip.toQuery()).toString();

  /// Cada pantalla de la app, con la ruta que la monta.
  List<(String, String)> screens() => <(String, String)>[
    ('parada', AppPaths.stop(stopId)),
    ('modo paradero', AppPaths.stopBoard(stopId)),
    ('ruta', AppPaths.route(routeId)),
    ('planificador', query('/planner')),
    ('itinerario', query(AppPaths.plannerOption(0))),
    ('modo viaje', query(AppPaths.ride(0))),
    ('favoritos', AppPaths.favorites),
    ('ajustes', AppPaths.settings),
    ('acerca de', AppPaths.about),
  ];

  /// Favoritos con algo dentro: una pantalla vacía no audita nada.
  ProviderContainer container() => makeContainer(
    dataset,
    favorites: InMemoryFavoritesStore(
      <String>{stopId},
      <String>{dataset.routes.first.id},
    ),
  );

  for (final (String theme, ThemeData data) in <(String, ThemeData)>[
    ('oscuro', AppTheme.dark),
    ('claro', AppTheme.light),
  ]) {
    for (final (String name, String path) in screens()) {
      testWidgets('$name, tema $theme: contraste, toque y nombre', (
        WidgetTester tester,
      ) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        final ProviderContainer box = container();
        await pumpAt(tester, box, path, theme: data);

        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

        await unmount(tester, box);
        handle.dispose();
      });
    }
  }

  // -- El mapa, que no es una pantalla más ----------------------------------
  // `pumpAt` lo sustituye por un `Scaffold` de cartón porque los demás tests
  // no son del mapa. Aquí sí: la hoja, la barra de búsqueda y los controles
  // son controles de verdad y tienen que pasar los mismos pisos.

  for (final (String theme, ThemeData data) in <(String, ThemeData)>[
    ('oscuro', AppTheme.dark),
    ('claro', AppTheme.light),
  ]) {
    testWidgets('mapa, tema $theme: contraste, toque y nombre', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final ProviderContainer box = container();
      await pumpMapScreen(tester, box, theme: data);

      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      await unmount(tester, box);
      handle.dispose();
    });
  }

  // -- Texto del sistema al 200 % -------------------------------------------
  // El spec (§11) pide que ningún layout se rompa. No hay nada que afirmar: un
  // `RenderFlex` que se desborda lanza, y el test falla solo.

  for (final (String theme, ThemeData data) in <(String, ThemeData)>[
    ('oscuro', AppTheme.dark),
    ('claro', AppTheme.light),
  ]) {
    for (final (String name, String path) in screens()) {
      testWidgets('$name, tema $theme: al 200 % no se rompe', (
        WidgetTester tester,
      ) async {
        final ProviderContainer box = container();
        await pumpAt(tester, box, path, theme: data, textScale: 2);
        expect(tester.takeException(), isNull);
        await unmount(tester, box);
      });
    }
  }

  testWidgets('mapa: al 200 % no se rompe', (WidgetTester tester) async {
    final ProviderContainer box = container();
    await pumpMapScreen(tester, box, textScale: 2);
    expect(tester.takeException(), isNull);
    await unmount(tester, box);
  });
}
