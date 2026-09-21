import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Un grupo de marcadores que se dibuja como uno solo.
@immutable
class ScreenCluster<T> {
  const ScreenCluster({required this.center, required this.members});

  /// Centro del grupo en píxeles de pantalla.
  final Offset center;

  final List<T> members;

  bool get isSingle => members.length == 1;
}

/// Agrupa marcadores en pantalla cuando son demasiados.
///
/// La sección 7 del spec pide agrupar **arriba de 30 marcadores visibles**.
/// Se agrupa por rejilla en píxeles, no en grados: dos camiones se estorban
/// por lo cerca que se dibujan, no por lo cerca que están en el mundo.
///
/// Recibe los puntos ya filtrados por viewport: agrupar lo que no se ve es
/// trabajo tirado.
abstract final class ScreenClusterer {
  /// Hasta cuántos marcadores visibles se dibujan sueltos.
  static const int threshold = 30;

  /// Lado de la celda de la rejilla. Un poco más que un marcador con su halo.
  static const double cellSize = 56;

  static List<ScreenCluster<T>> cluster<T>(
    List<({T item, Offset point})> visible, {
    int threshold = ScreenClusterer.threshold,
    double cellSize = ScreenClusterer.cellSize,
  }) {
    if (visible.length <= threshold) {
      return <ScreenCluster<T>>[
        for (final ({T item, Offset point}) row in visible)
          ScreenCluster<T>(center: row.point, members: <T>[row.item]),
      ];
    }

    final Map<(int, int), List<({T item, Offset point})>> cells =
        <(int, int), List<({T item, Offset point})>>{};
    for (final ({T item, Offset point}) row in visible) {
      final (int, int) key = (
        (row.point.dx / cellSize).floor(),
        (row.point.dy / cellSize).floor(),
      );
      cells.putIfAbsent(key, () => <({T item, Offset point})>[]).add(row);
    }

    return <ScreenCluster<T>>[
      for (final List<({T item, Offset point})> cell in cells.values)
        ScreenCluster<T>(
          // El centro es el promedio de sus miembros, no el centro de la
          // celda: un grupo de dos no debe brincar a una esquina.
          center:
              cell.fold<Offset>(
                Offset.zero,
                (Offset sum, ({T item, Offset point}) row) => sum + row.point,
              ) /
              cell.length.toDouble(),
          members: <T>[
            for (final ({T item, Offset point}) row in cell) row.item,
          ],
        ),
    ];
  }
}
