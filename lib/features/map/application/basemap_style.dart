import 'package:flutter/foundation.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/cache/tile_cache.dart';

part 'basemap_style.g.dart';

/// Los estilos del mapa de fondo, generados por `tool/map_styles.py` a partir
/// de los tokens de color.
abstract final class BasemapAssets {
  static const String dark = 'assets/map/style_dark.json';
  static const String light = 'assets/map/style_light.json';

  static String forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}

/// El estilo vectorial cargado, o `null` si no se pudo.
///
/// `null` no es un error que haya que enseñar: sin red y sin caché, el mapa se
/// queda con la superficie lisa y las rutas encima. Las rutas son el
/// contenido; el fondo es contexto (sección 7).
///
/// Los tests lo sustituyen por `null` para no tocar la red.
@Riverpod(keepAlive: true)
Future<vt.Style?> basemapStyle(Ref ref, Brightness brightness) async {
  try {
    final vt.Style style = await vt.StyleReader(
      uri: 'asset://${BasemapAssets.forBrightness(brightness)}',
      logger: kDebugMode ? const vt.Logger.console() : const vt.Logger.noop(),
      // El estilo sale de un asset, pero lo que declara —las fuentes de
      // tiles y los sprites— sí se baja y se guarda. Va a la carpeta de la
      // app para que "limpiar caché" en ajustes lo alcance.
      cachePath: tileCacheFolder,
    ).read();
    ref.onDispose(style.dispose);
    return style;
  } on Object catch (error) {
    debugPrint('Mapa de fondo no disponible: $error');
    return null;
  }
}
