import 'package:flutter/material.dart';

import 'contrast.dart';

/// Colores de ruta.
///
/// El color viene de `route_color` de GTFS. Cuando falta —que es lo normal—
/// se genera desde el `routeId` con un hash determinista contra una paleta
/// curada: la misma ruta tiene siempre el mismo color, entre sesiones y entre
/// dispositivos, porque el color de una ruta es parte de cómo la gente la
/// reconoce.
abstract final class RoutePalette {
  /// Doce tonos suficientemente distinguibles entre sí, todos con contraste
  /// mayor o igual a 4.5:1 contra la superficie oscura.
  ///
  /// Ninguno repite los hex de los estados de tiempo real: un color, un
  /// significado.
  static const List<Color> tones = <Color>[
    Color(0xFFEF5A5F), // rojo
    Color(0xFFF2843C), // naranja
    Color(0xFFF5C542), // ámbar
    Color(0xFFB9D444), // lima
    Color(0xFF47C2A0), // verde azulado
    Color(0xFF3BC9D9), // cian
    Color(0xFF4D9BEF), // azul
    Color(0xFF7C7CF0), // índigo
    Color(0xFFB07CF0), // morado
    Color(0xFFE86BC4), // magenta
    Color(0xFFF07595), // rosa
    Color(0xFFD2A15E), // ocre
  ];

  /// El color de una ruta sin `route_color`.
  static Color colorForRouteId(String routeId) =>
      tones[_stableHash(routeId) % tones.length];

  /// El color de una ruta, prefiriendo el de GTFS cuando existe.
  ///
  /// [gtfsColor] llega como hexadecimal sin `#`, que es como lo escribe GTFS.
  /// Si viene mal formado se ignora: un color inválido degrada al de la
  /// paleta, no revienta la pantalla.
  static Color colorForRoute({required String routeId, String? gtfsColor}) =>
      parseGtfsColor(gtfsColor) ?? colorForRouteId(routeId);

  /// Hexadecimal de GTFS (`"00854A"`) a [Color]. Nulo si no se puede leer.
  static Color? parseGtfsColor(String? hex) {
    if (hex == null) {
      return null;
    }
    final String clean = hex.replaceFirst('#', '').trim();
    if (clean.length != 6) {
      return null;
    }
    final int? value = int.tryParse(clean, radix: 16);
    return value == null ? null : Color(0xFF000000 | value);
  }

  /// Tinta oscura para las placas claras.
  static const Color _ink = Color(0xFF0E1412);

  /// Tinta clara para las placas oscuras.
  static const Color _paper = Color(0xFFFFFFFF);

  /// Texto legible sobre [background].
  ///
  /// Mide el contraste contra las dos tintas y se queda con la mejor. Un
  /// umbral fijo de luminancia se equivoca justo en los tonos medios, que son
  /// la mitad de esta paleta: un rojo brillante con texto blanco da 3.3:1 y no
  /// pasa el piso de la sección 11 del spec, aunque "se vea bien".
  static Color onColor(Color background) =>
      Contrast.bestOn(background, _ink, _paper);

  /// Texto legible sobre [background], prefiriendo la tinta que declara GTFS.
  ///
  /// El feed oficial de Aguascalientes trae `route_text_color` en sus 48 rutas
  /// y en varias no se puede leer: la R-08 es `#C4CBA6` con tinta `#F0F0F0`,
  /// que da 1.5:1. El feed manda en identidad, no en legibilidad, así que su
  /// tinta se respeta solo si pasa el piso de la sección 11 del spec; si no,
  /// se calcula.
  static Color inkFor(Color background, {String? gtfsTextColor}) {
    final Color? declared = parseGtfsColor(gtfsTextColor);
    if (declared != null &&
        Contrast.ratio(declared, background) >= Contrast.minText) {
      return declared;
    }
    return onColor(background);
  }

  /// Si una placa de este color necesita contorno para no disolverse en
  /// [surface].
  ///
  /// Pasa en tema claro con los tonos brillantes: la placa sigue siendo
  /// legible por dentro, pero su borde desaparece contra el fondo. En vez de
  /// oscurecer toda la paleta —y perder la identidad de cada ruta— se le pone
  /// un contorno de 1 px.
  static bool needsOutline(Color color, Color surface) =>
      Contrast.ratio(color, surface) < Contrast.minGraphic;

  /// Hash estable entre sesiones.
  ///
  /// `String.hashCode` de Dart **no** sirve aquí: puede cambiar entre
  /// ejecuciones, y entonces la ruta 20 sería azul hoy y morada mañana. Este
  /// es un FNV-1a de 32 bits, que siempre da lo mismo.
  static int _stableHash(String value) {
    int hash = 0x811c9dc5;
    for (final int unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }
}
