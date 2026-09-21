import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yovoy_go/core/data/mock/mock_dataset.dart';
import 'package:yovoy_go/core/data/mock/mock_transit_repository.dart';
import 'package:yovoy_go/core/data/mock/simulator_config.dart';
import 'package:yovoy_go/core/data/transit_network.dart';
import 'package:yovoy_go/features/map/application/search_index.dart';

/// "Búsqueda única", contra el dataset real: un solo campo, y el grupo más
/// probable arriba.
void main() {
  late SearchIndex index;

  setUpAll(() async {
    final MockDataset dataset = MockDataset.fromJsonStrings(<String, String>{
      for (final String name in MockAssets.files)
        name: File('${MockAssets.directory}/$name').readAsStringSync(),
    });
    final TransitNetwork network = await MockTransitRepository(
      dataset: dataset,
      config: SimulatorConfig.perfect,
    ).getNetwork();
    index = SearchIndex(network);
  });

  test('"20" es la ruta 20, como la dice la gente', () {
    final List<SearchGroup> groups = index.search('20');
    expect(groups.first.kind, SearchKind.route);
    expect(
      groups.first.hits.map((SearchHit h) => h.title),
      containsAll(<String>['R20N', 'R20S']),
    );
  });

  test('"1" encuentra la R01 aunque tenga cero a la izquierda', () {
    final List<SearchGroup> groups = index.search('1');
    expect(groups.first.kind, SearchKind.route);
    expect(groups.first.hits.first.title, 'R01');
  });

  test('"plaza" da paradas primero', () {
    final List<SearchGroup> groups = index.search('plaza');
    expect(groups.first.kind, SearchKind.stop);
    expect(
      groups.first.hits.every(
        (SearchHit h) => h.title.toLowerCase().contains('plaza'),
      ),
      isTrue,
    );
  });

  test('"chicahuales" da un destino con las rutas que van', () {
    final List<SearchGroup> groups = index.search('chicahuales');
    final SearchGroup destinations = groups.firstWhere(
      (SearchGroup g) => g.kind == SearchKind.destination,
    );
    expect(destinations.hits.first.title, 'Chicahuales');
    expect(destinations.hits.first.routeIds, isNotEmpty);
  });

  test('los acentos y las mayúsculas no importan', () {
    List<String> titles(String q) => <String>[
      for (final SearchGroup g in index.search(q))
        for (final SearchHit h in g.hits) h.title,
    ];
    expect(titles('JESUS MARIA'), titles('Jesús María'));
    expect(titles('jesus maria'), isNotEmpty);
  });

  test('nada que coincida es una lista vacía, no un error', () {
    expect(index.search('zzzzqqq'), isEmpty);
    expect(index.search('   '), isEmpty);
  });

  test('cada grupo trae a lo más cinco resultados', () {
    for (final SearchGroup g in index.search('a')) {
      expect(g.hits.length, lessThanOrEqualTo(SearchIndex.perGroup));
    }
  });
}
