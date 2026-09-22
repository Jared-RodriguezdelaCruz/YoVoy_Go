import 'package:shared_preferences/shared_preferences.dart';

import 'observation.dart';

/// Dónde vive lo que este teléfono ha visto.
///
/// Sigue siendo `shared_preferences`, la decisión de la fase 6: cada
/// observación es una línea corta y lo que se pregunta —"todo lo de esta ruta
/// en esta parada"— se responde leyendo la lista completa, que está topada.
/// Una base de datos para trescientas líneas sería una dependencia nueva a
/// cambio de nada.
abstract interface class HistoryStore {
  Future<List<ArrivalObservation>> loadArrivals();

  Future<void> saveArrivals(List<ArrivalObservation> observations);

  Future<List<UseEvent>> loadUses();

  Future<void> saveUses(List<UseEvent> uses);

  Future<Set<String>> loadHidden();

  Future<void> saveHidden(Set<String> stopIds);

  /// Borra las tres cosas. Es lo que hace "borrar historial" en ajustes.
  Future<void> clear();
}

/// Cuántas observaciones de arribo se guardan. Lo viejo se cae solo.
const int maxArrivalObservations = 500;

/// Cuántos eventos de uso se guardan.
const int maxUseEvents = 300;

final class SharedPreferencesHistoryStore implements HistoryStore {
  const SharedPreferencesHistoryStore();

  static const String arrivalsKey = 'history.arrivals';
  static const String usesKey = 'history.uses';
  static const String hiddenKey = 'history.hidden';

  @override
  Future<List<ArrivalObservation>> loadArrivals() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    return <ArrivalObservation>[
      for (final String line
          in preferences.getStringList(arrivalsKey) ?? const <String>[])
        if (ArrivalObservation.decode(line) case final ArrivalObservation o) o,
    ];
  }

  @override
  Future<void> saveArrivals(List<ArrivalObservation> observations) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(arrivalsKey, <String>[
      for (final ArrivalObservation o in _tail(
        observations,
        maxArrivalObservations,
      ))
        o.encode(),
    ]);
  }

  @override
  Future<List<UseEvent>> loadUses() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    return <UseEvent>[
      for (final String line
          in preferences.getStringList(usesKey) ?? const <String>[])
        if (UseEvent.decode(line) case final UseEvent use) use,
    ];
  }

  @override
  Future<void> saveUses(List<UseEvent> uses) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(usesKey, <String>[
      for (final UseEvent use in _tail(uses, maxUseEvents)) use.encode(),
    ]);
  }

  @override
  Future<Set<String>> loadHidden() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    return preferences.getStringList(hiddenKey)?.toSet() ?? <String>{};
  }

  @override
  Future<void> saveHidden(Set<String> stopIds) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(hiddenKey, stopIds.toList()..sort());
  }

  @override
  Future<void> clear() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.remove(arrivalsKey);
    await preferences.remove(usesKey);
    await preferences.remove(hiddenKey);
  }
}

/// Se queda con los últimos [max]: el historial no crece sin fin.
List<T> _tail<T>(List<T> items, int max) =>
    items.length <= max ? items : items.sublist(items.length - max);

/// Para tests: se olvida con el proceso.
final class InMemoryHistoryStore implements HistoryStore {
  InMemoryHistoryStore({
    List<ArrivalObservation>? arrivals,
    List<UseEvent>? uses,
    Set<String>? hidden,
  }) : _arrivals = <ArrivalObservation>[...?arrivals],
       _uses = <UseEvent>[...?uses],
       _hidden = <String>{...?hidden};

  List<ArrivalObservation> _arrivals;
  List<UseEvent> _uses;
  Set<String> _hidden;

  /// Cuántas veces se escribió: los tests verifican que observar guarde.
  int saves = 0;

  @override
  Future<List<ArrivalObservation>> loadArrivals() async => <ArrivalObservation>[
    ..._arrivals,
  ];

  @override
  Future<void> saveArrivals(List<ArrivalObservation> observations) async {
    saves++;
    _arrivals = _tail(observations, maxArrivalObservations);
  }

  @override
  Future<List<UseEvent>> loadUses() async => <UseEvent>[..._uses];

  @override
  Future<void> saveUses(List<UseEvent> uses) async {
    saves++;
    _uses = _tail(uses, maxUseEvents);
  }

  @override
  Future<Set<String>> loadHidden() async => <String>{..._hidden};

  @override
  Future<void> saveHidden(Set<String> stopIds) async {
    saves++;
    _hidden = <String>{...stopIds};
  }

  @override
  Future<void> clear() async {
    saves++;
    _arrivals = <ArrivalObservation>[];
    _uses = <UseEvent>[];
    _hidden = <String>{};
  }
}
