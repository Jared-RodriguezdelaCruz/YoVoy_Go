import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yovoy_go/core/data/mock/mock_dataset.dart';
import 'package:yovoy_go/core/data/mock/simulator_config.dart';
import 'package:yovoy_go/core/location/location_service.dart';
import 'package:yovoy_go/features/map/application/accessibility_filter.dart';
import 'package:yovoy_go/features/planner/application/trip_request.dart';
import 'package:yovoy_go/features/planner/presentation/itinerary_card.dart';
import 'package:yovoy_go/features/planner/presentation/itinerary_screen.dart';
import 'package:yovoy_go/features/planner/presentation/place_picker.dart';
import 'package:yovoy_go/features/planner/presentation/planner_screen.dart';
import 'package:yovoy_go/features/route/presentation/route_screen.dart';
import 'package:yovoy_go/features/stop/presentation/stop_screen.dart';

import '../../helpers/screen_harness.dart';

/// El planificador (§8.4): el formulario, los resultados, el detalle y el
/// "no encontré ruta" con salida útil.
void main() {
  late MockDataset dataset;

  setUpAll(() => dataset = loadTestDataset());

  PrecookedTrip pair(String id) =>
      dataset.precookedTrips.firstWhere((PrecookedTrip p) => p.id == id);

  String planFor(PrecookedTrip trip) => Uri(
    path: '/planner',
    queryParameters: TripRequest(
      from: PointPlace(trip.from),
      to: PointPlace(trip.to),
    ).toQuery(),
  ).toString();

  testWidgets('sin origen ni destino, guía en vez de pantalla vacía', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = makeContainer(dataset);
    await pumpAt(tester, container, '/planner');

    expect(find.byType(PlannerScreen), findsOneWidget);
    expect(find.text('¿De dónde sales?'), findsOneWidget);
    expect(find.text('Elegir el origen'), findsOneWidget);
    expect(find.text('Salir ahora'), findsOneWidget);
    expect(find.text('Solo accesibles'), findsOneWidget);

    await unmount(tester, container);
  });

  testWidgets('las opciones salen ordenadas, primero la más sencilla', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final ProviderContainer container = makeContainer(dataset);
    await pumpAt(tester, container, planFor(pair('directo')));

    final int options = pair('directo').itineraries.length;
    expect(
      find.textContaining(
        '$options formas de llegar · primero la más sencilla',
      ),
      findsOneWidget,
    );
    expect(find.byType(ItineraryCard), findsNWidgets(options));
    // Una tarjeta se lee completa en una sola frase.
    expect(
      find.bySemanticsLabel(RegExp(r'^Opción 1, \d+ min, directo')),
      findsOneWidget,
    );
    expect(find.textContaining('no cuentan la espera'), findsOneWidget);

    await unmount(tester, container);
    semantics.dispose();
  });

  testWidgets('tocar una opción abre su línea de tiempo', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = makeContainer(dataset);
    await pumpAt(tester, container, planFor(pair('un_transbordo')));

    await tester.tap(find.byType(ItineraryCard).first);
    await settle(tester);

    expect(find.byType(ItineraryScreen), findsOneWidget);
    expect(find.textContaining('Camina '), findsWidgets);
    expect(find.textContaining('Baja en '), findsWidgets);
    expect(find.text('Empezar viaje'), findsOneWidget);

    await unmount(tester, container);
  });

  testWidgets('sin ruta, sugiere lo que sí pasa cerca y lleva ahí', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = makeContainer(dataset);
    // Desde una parada de la R09 hacia un punto fuera de la red.
    await pumpAt(tester, container, '/planner?from=P453&to=21.6,-102.6');

    expect(
      find.text('No encontré un camión de Rosaura Zapata a Un punto del mapa'),
      findsOneWidget,
    );
    expect(find.text('Pasan cerca de tu origen'), findsOneWidget);

    final Finder firstRoute = find.bySemanticsLabel(RegExp('Ver la ruta'));
    await tester.ensureVisible(firstRoute.first);
    await tester.tap(firstRoute.first);
    await settle(tester);
    expect(find.byType(RouteScreen), findsOneWidget);

    await unmount(tester, container);
  });

  testWidgets('el par sin resultados no deja al usuario en un callejón', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = makeContainer(dataset);
    await pumpAt(tester, container, planFor(pair('sin_resultados')));

    expect(find.textContaining('No encontré un camión'), findsOneWidget);
    // O hay rutas cerca, o hay un camino al mapa: nunca solo la disculpa.
    expect(
      find.text('Pasan cerca de tu origen').evaluate().isNotEmpty ||
          find.text('Ver las rutas en el mapa').evaluate().isNotEmpty,
      isTrue,
    );

    await unmount(tester, container);
  });

  testWidgets('con "Solo accesibles" lo dice y deja verlas de todos modos', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = makeContainer(
      dataset,
      accessibility: InMemoryAccessibilityFilterStore(value: true),
    );
    await pumpAt(tester, container, planFor(pair('dos_transbordos')));

    expect(
      find.text('Ningún viaje es accesible de punta a punta'),
      findsOneWidget,
    );
    expect(find.byType(ItineraryCard), findsNothing);

    await tester.tap(find.text('Mostrarlas de todos modos'));
    await settle(tester);
    expect(
      find.byType(ItineraryCard),
      findsNWidgets(pair('dos_transbordos').itineraries.length),
    );
    // Verlas esta vez no apaga el filtro guardado.
    expect(await container.read(accessibleOnlyProvider.future), isTrue);

    await unmount(tester, container);
  });

  testWidgets('"mi ubicación" sin permiso lo dice y ofrece una parada', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = makeContainer(
      dataset,
      location: const UserLocation.fallback(LocationIssue.denied),
    );
    await pumpAt(tester, container, '/planner?from=here&to=P606');

    expect(find.text('No sé dónde estás'), findsOneWidget);
    expect(find.text('Elegir una parada'), findsOneWidget);

    await unmount(tester, container);
  });

  testWidgets('el buscador de lugares llena el campo', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = makeContainer(dataset);
    await pumpAt(tester, container, '/planner?to=P606');

    await tester.tap(find.bySemanticsLabel('Desde: sin elegir'));
    await settle(tester);
    expect(find.byType(PlacePickerScreen), findsOneWidget);
    expect(find.text('Mi ubicación'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'rosaura');
    await settle(tester);
    await tester.tap(find.text('Rosaura Zapata').first);
    await settle(tester);

    expect(find.byType(PlacePickerScreen), findsNothing);
    expect(find.bySemanticsLabel('Desde: Rosaura Zapata'), findsOneWidget);
    expect(find.bySemanticsLabel('Hacia: DIF Estatal'), findsOneWidget);

    await unmount(tester, container);
  });

  testWidgets('desde una parada, "Cómo llego aquí" abre el planificador', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = makeContainer(dataset);
    await pumpAt(tester, container, '/stop/P606');
    expect(find.byType(StopScreen), findsOneWidget);

    await tester.tap(find.byTooltip('Cómo llego aquí'));
    await settle(tester);

    expect(find.byType(PlannerScreen), findsOneWidget);
    expect(find.bySemanticsLabel('Desde: Mi ubicación'), findsOneWidget);
    expect(find.bySemanticsLabel('Hacia: DIF Estatal'), findsOneWidget);

    await unmount(tester, container);
  });

  testWidgets('una opción que ya no existe lo dice y deja replanear', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = makeContainer(dataset);
    final String option = planFor(pair('directo'))
        .replaceFirst('/planner', '/planner/option/9');
    await pumpAt(tester, container, option);

    expect(find.text('Este viaje ya no está'), findsOneWidget);
    await tester.tap(find.text('Planear de nuevo'));
    await settle(tester);
    expect(find.byType(PlannerScreen), findsOneWidget);

    await unmount(tester, container);
  });

  testWidgets('en modo hostil y con texto al 200 % no se desborda', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = makeContainer(
      dataset,
      config: SimulatorConfig.hostile,
    );
    await pumpAt(
      tester,
      container,
      planFor(pair('dos_transbordos')),
      textScale: 2,
      frames: 60,
    );
    expect(tester.takeException(), isNull);

    final Finder card = find.byType(ItineraryCard);
    if (card.evaluate().isNotEmpty) {
      await tester.tap(card.first);
      await settle(tester, frames: 60);
      expect(tester.takeException(), isNull);
    }

    await unmount(tester, container);
  });
}
