import 'package:flutter/foundation.dart';

import '../../../core/data/transit_network.dart';
import '../../../core/models/models.dart';

/// Qué clase de cosa encontró la búsqueda.
enum SearchKind { route, stop, destination }

/// Un resultado. [id] es el de la ruta o la parada; en un destino es el id de
/// una ruta que va hacia allá.
@immutable
class SearchHit {
  const SearchHit({
    required this.kind,
    required this.id,
    required this.title,
    required this.score,
    this.subtitle,
    this.routeIds = const <String>[],
    this.gtfsColor,
  });

  final SearchKind kind;
  final String id;
  final String title;
  final String? subtitle;

  /// Las rutas asociadas: la propia, las que paran aquí o las que van al
  /// destino.
  final List<String> routeIds;

  /// El color del feed, en las rutas: la placa del resultado tiene que ser
  /// del mismo color que la línea del mapa.
  final String? gtfsColor;

  final int score;
}

/// Un grupo de resultados del mismo tipo.
@immutable
class SearchGroup {
  const SearchGroup({required this.kind, required this.hits});

  final SearchKind kind;
  final List<SearchHit> hits;

  int get bestScore => hits.first.score;
}

/// "Búsqueda única", la feature 9 de `FEATURES.md`.
///
/// Un solo campo: `20` da rutas, `Plaza` da paradas, `Chicahuales` da
/// destinos. Nadie tiene que elegir pestaña antes de saber qué busca. Los
/// grupos vienen ordenados por su mejor resultado, así que el grupo más
/// probable queda arriba.
///
/// Todo es local: el índice se arma una vez con la red estática.
class SearchIndex {
  SearchIndex(TransitNetwork network)
    : _routes = <_Entry>[
        for (final TransitRoute route in network.routes)
          _Entry(
            id: route.id,
            title: route.shortName,
            subtitle: route.longName,
            keys: <String>[
              normalize(route.shortName),
              normalize(route.longName),
            ],
            number: _routeNumber(route.shortName),
            routeIds: <String>[route.id],
            gtfsColor: route.color,
          ),
      ],
      _stops = <_Entry>[
        for (final Stop stop in network.stops)
          _Entry(
            id: stop.id,
            title: stop.name,
            subtitle: stop.code,
            keys: <String>[
              normalize(stop.name),
              if (stop.code case final String code) normalize(code),
            ],
          ),
      ],
      _destinations = _destinationsOf(network);

  /// Cuántos resultados por grupo.
  static const int perGroup = 5;

  final List<_Entry> _routes;
  final List<_Entry> _stops;
  final List<_Entry> _destinations;

  List<SearchGroup> search(String query) {
    final String q = normalize(query);
    if (q.isEmpty) {
      return const <SearchGroup>[];
    }
    final String? number = _routeNumber(q);

    final List<SearchGroup> groups =
        <SearchGroup>[
            _group(SearchKind.route, _routes, q, number: number),
            _group(SearchKind.stop, _stops, q),
            _group(SearchKind.destination, _destinations, q),
          ].where((SearchGroup group) => group.hits.isNotEmpty).toList()
          ..sort((SearchGroup a, SearchGroup b) => b.bestScore - a.bestScore);
    return groups;
  }

  SearchGroup _group(
    SearchKind kind,
    List<_Entry> entries,
    String q, {
    String? number,
  }) {
    final List<SearchHit> hits = <SearchHit>[];
    for (final _Entry entry in entries) {
      int score = 0;
      if (number != null && entry.number == number) {
        // "20" es la ruta 20 y nada le gana: es como la gente la nombra.
        score = 100;
      }
      for (final String key in entry.keys) {
        score = _max(score, _scoreText(key, q));
      }
      if (score > 0) {
        hits.add(
          SearchHit(
            kind: kind,
            id: entry.id,
            title: entry.title,
            subtitle: entry.subtitle,
            routeIds: entry.routeIds,
            gtfsColor: entry.gtfsColor,
            score: score,
          ),
        );
      }
    }
    hits.sort((SearchHit a, SearchHit b) {
      final int byScore = b.score - a.score;
      return byScore != 0 ? byScore : a.title.compareTo(b.title);
    });
    return SearchGroup(kind: kind, hits: hits.take(perGroup).toList());
  }

  /// Minúsculas y sin acentos: "Jesús María" y "jesus maria" son lo mismo.
  static String normalize(String text) {
    final StringBuffer out = StringBuffer();
    for (final int rune in text.toLowerCase().trim().runes) {
      out.write(_plain[String.fromCharCode(rune)] ?? String.fromCharCode(rune));
    }
    return out.toString().replaceAll(RegExp(r'\s+'), ' ');
  }

  static const Map<String, String> _plain = <String, String>{
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
  };

  /// El número que la gente dice de una ruta: `R20N` → `20`, `R01` → `1`.
  /// También sirve con lo que se escribe en el campo: `20`, `r20`, `ruta 20`.
  static String? _routeNumber(String text) {
    final RegExpMatch? match = RegExp(
      r'^(?:r|ruta\s*)?0*(\d+)',
      caseSensitive: false,
    ).firstMatch(text.trim());
    return match?.group(1);
  }

  static int _scoreText(String key, String q) {
    if (key == q) {
      return 90;
    }
    if (key.startsWith(q)) {
      return 70;
    }
    if (key.split(RegExp(r'[\s()\-—]+')).any((String w) => w.startsWith(q))) {
      return 60;
    }
    if (q.length >= 3 && key.contains(q)) {
      return 40;
    }
    return 0;
  }

  static List<_Entry> _destinationsOf(TransitNetwork network) {
    final Map<String, List<String>> routesByHeadsign = <String, List<String>>{};
    for (final Trip trip in network.trips) {
      final List<String> ids = routesByHeadsign.putIfAbsent(
        trip.headsign,
        () => <String>[],
      );
      if (!ids.contains(trip.routeId)) {
        ids.add(trip.routeId);
      }
    }
    return <_Entry>[
      for (final MapEntry<String, List<String>> row in routesByHeadsign.entries)
        _Entry(
          id: row.value.first,
          title: row.key,
          subtitle: <String>[
            for (final String id in row.value)
              network.route(id)?.shortName ?? id,
          ].join(' · '),
          keys: <String>[normalize(row.key)],
          routeIds: row.value,
        ),
    ];
  }
}

int _max(int a, int b) => a > b ? a : b;

class _Entry {
  const _Entry({
    required this.id,
    required this.title,
    required this.keys,
    this.subtitle,
    this.number,
    this.routeIds = const <String>[],
    this.gtfsColor,
  });

  final String id;
  final String title;
  final String? subtitle;
  final List<String> keys;
  final String? number;
  final List<String> routeIds;
  final String? gtfsColor;
}
