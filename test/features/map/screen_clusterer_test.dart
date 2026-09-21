import 'package:flutter_test/flutter_test.dart';
import 'package:yovoy_go/features/map/application/screen_clusterer.dart';

/// El agrupador: arriba de 30 visibles se agrupa, y nunca se pierde un camión.
void main() {
  List<({int item, Offset point})> grid(int count, {double step = 10}) =>
      <({int item, Offset point})>[
        for (int i = 0; i < count; i++)
          (item: i, point: Offset((i % 10) * step, (i ~/ 10) * step)),
      ];

  test('con 30 visibles no agrupa: se dibujan sueltos', () {
    final List<ScreenCluster<int>> clusters = ScreenClusterer.cluster<int>(
      grid(30),
    );
    expect(clusters, hasLength(30));
    expect(clusters.every((ScreenCluster<int> c) => c.isSingle), isTrue);
  });

  test('con 31 visibles agrupa', () {
    final List<ScreenCluster<int>> clusters = ScreenClusterer.cluster<int>(
      grid(31),
    );
    expect(clusters.length, lessThan(31));
  });

  test('nunca pierde un camión: la suma de los grupos es el total', () {
    for (final int count in <int>[31, 57, 323]) {
      final List<ScreenCluster<int>> clusters = ScreenClusterer.cluster<int>(
        grid(count, step: 23),
      );
      final List<int> members = <int>[
        for (final ScreenCluster<int> c in clusters) ...c.members,
      ]..sort();
      expect(members, List<int>.generate(count, (int i) => i));
    }
  });

  test('el centro de un grupo es el promedio de sus miembros', () {
    final List<ScreenCluster<int>> clusters = ScreenClusterer.cluster<int>(
      <({int item, Offset point})>[
        (item: 0, point: const Offset(10, 10)),
        (item: 1, point: const Offset(20, 30)),
      ],
      threshold: 0,
    );
    expect(clusters.single.center, const Offset(15, 20));
  });

  test('los que están lejos no se juntan', () {
    final List<ScreenCluster<int>> clusters = ScreenClusterer.cluster<int>(
      <({int item, Offset point})>[
        (item: 0, point: const Offset(10, 10)),
        (item: 1, point: const Offset(300, 300)),
      ],
      threshold: 0,
    );
    expect(clusters, hasLength(2));
  });
}
