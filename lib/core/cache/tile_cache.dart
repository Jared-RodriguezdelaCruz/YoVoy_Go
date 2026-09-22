import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'tile_cache.g.dart';

/// La caché del mapa de fondo, en una carpeta que elige la app.
///
/// El paquete del mapa la maneja solo (14 días, 50 MB) y no ofrece manera de
/// borrarla. Diciéndole dónde guardarla, "limpiar caché" de ajustes deja de ser
/// una promesa vacía: la carpeta se puede medir y borrar.
///
/// Se le pasa **esta función**, no la ruta ya resuelta: el paquete abre su
/// caché al montar la capa, y para entonces un provider asíncrono todavía no
/// habría respondido. La capa se quedaría con la carpeta del paquete y el
/// botón de ajustes borraría una carpeta vacía.
Future<String> tileCacheFolder() async {
  final Directory support = await getApplicationSupportDirectory();
  final Directory cache = Directory('${support.path}/tiles');
  await cache.create(recursive: true);
  return cache.path;
}

/// La misma carpeta para quien necesita medirla o borrarla, o `null` cuando no
/// hay sistema de archivos —en los tests, sin plugins—.
@Riverpod(keepAlive: true)
Future<String?> tileCachePath(Ref ref) async {
  try {
    return await tileCacheFolder();
  } on Object catch (error) {
    debugPrint('Sin carpeta de caché: $error');
    return null;
  }
}

/// Lo que ocupa la caché ahora mismo. Ajustes lo muestra antes de ofrecer
/// borrarla: un botón que no dice cuánto libera no se toca.
@riverpod
Future<int> tileCacheSize(Ref ref) async =>
    tileCacheBytes(await ref.watch(tileCachePathProvider.future));

/// Cuánto ocupa la caché, en bytes. Cero si no hay carpeta.
Future<int> tileCacheBytes(String? path) async {
  if (path == null) {
    return 0;
  }
  final Directory cache = Directory(path);
  if (!cache.existsSync()) {
    return 0;
  }
  int total = 0;
  await for (final FileSystemEntity entity in cache.list(recursive: true)) {
    if (entity is File) {
      total += await entity.length();
    }
  }
  return total;
}

/// Borra la caché. La carpeta se vuelve a crear vacía para que el mapa siga
/// escribiendo donde esperaba.
Future<void> clearTileCache(String? path) async {
  if (path == null) {
    return;
  }
  final Directory cache = Directory(path);
  if (cache.existsSync()) {
    await cache.delete(recursive: true);
  }
  await cache.create(recursive: true);
}

/// "12.4 MB", "820 KB", "vacía". Lo que se le dice al usuario antes de borrar.
String cacheSizeLabel(int bytes) {
  if (bytes <= 0) {
    return 'vacía';
  }
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).round()} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
