import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yovoy_go/design/tokens/typography.dart';

/// Las fuentes de la app y los íconos del SDK, para que una imagen de
/// referencia se parezca a la app y no a la tipografía de prueba.
Future<void> loadAppFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _loadBarlow();
  await _loadMaterialIcons();
}

/// Carga las Barlow de `assets/fonts/`.
///
/// Sin esto, `flutter test` dibuja con la tipografía de prueba y la imagen no
/// se parece a la app.
Future<void> _loadBarlow() async {
  const Map<String, List<String>> families = <String, List<String>>{
    AppTypography.family: <String>[
      'assets/fonts/Barlow-Regular.ttf',
      'assets/fonts/Barlow-Medium.ttf',
      'assets/fonts/Barlow-SemiBold.ttf',
      'assets/fonts/Barlow-Bold.ttf',
    ],
    AppTypography.condensedFamily: <String>[
      'assets/fonts/BarlowSemiCondensed-SemiBold.ttf',
      'assets/fonts/BarlowSemiCondensed-Bold.ttf',
    ],
    AppTypography.tightFamily: <String>[
      'assets/fonts/BarlowCondensed-Bold.ttf',
    ],
  };

  for (final MapEntry<String, List<String>> family in families.entries) {
    final FontLoader loader = FontLoader(family.key);
    for (final String path in family.value) {
      loader.addFont(rootBundle.load(path));
    }
    await loader.load();
  }
}

/// Carga la tipografía de íconos del SDK.
///
/// `flutter test` no la registra, y sin ella cada ícono sale como un cuadrito
/// vacío. Si no se encuentra el archivo, la foto se toma igual: los cuadritos
/// molestan, pero no valen romper la prueba.
Future<void> _loadMaterialIcons() async {
  final String? flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot == null) {
    return;
  }

  final File font = File(
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (!font.existsSync()) {
    return;
  }

  final Uint8List bytes = await font.readAsBytes();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)))).load();
}
