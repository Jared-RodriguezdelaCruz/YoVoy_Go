import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// El tono de la app, verificado y no prometido.
///
/// La sección 9 del spec lo dice en una línea: **verbos activos, sentence
/// case, sin disculpas.** "Sin señal de esta ruta", no "Lo sentimos, no fue
/// posible obtener la información en este momento".
///
/// Lo que sí se puede revisar solo es la disculpa y el giro pasivo: son
/// palabras concretas. El sentence case y el verbo activo se leen a mano, y
/// quedan anotados en el ROADMAP como lo que son —lectura, no lint—.
///
/// La lista es corta y precisa a propósito. Un linter de tono con falsos
/// positivos se termina apagando, y apagado no cuida nada. Por eso también
/// **solo mira literales de texto**: los comentarios explican la regla y la
/// nombran, y `hasError:` es un identificador, no una pantalla.
void main() {
  /// Lo que no se dice, y por qué.
  const Map<String, String> banned = <String, String>{
    'lo sentimos': 'la app no se disculpa por el mundo',
    'lo lamentamos': 'la app no se disculpa por el mundo',
    'disculpa las molestias': 'no hubo molestia, hubo un camión sin señal',
    'por favor': 'no se ruega: se dice qué hacer',
    'ups': 'no hay chistes cuando alguien está esperando el camión',
    'no fue posible': 'pasiva: decir qué falló, no que algo no fue posible',
    'ha ocurrido un error': 'genérico: no dice qué falló ni qué hacer',
    'se ha producido': 'pasiva refleja, y además no dice qué',
    'más tarde': '"más tarde" no es una instrucción',
    // La app informa, no exclama.
    '¡': 'la app no exclama',
  };

  /// Comentarios fuera: ahí se nombra lo que no se dice, justamente para
  /// explicar por qué no se dice.
  String withoutComments(String source) => source
      .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
      .split('\n')
      .map((String line) {
        final int slashes = line.indexOf('//');
        return slashes == -1 ? line : line.substring(0, slashes);
      })
      .join('\n');

  /// Los literales de texto de un archivo Dart, en minúsculas.
  ///
  /// No es un parser: es una expresión regular que alcanza para esto porque
  /// la app no tiene literales retorcidos. Si algún día los tuviera, este test
  /// se quedaría corto, no mentiría.
  List<String> literals(String source) {
    final RegExp quoted = RegExp(
      r"'''(.*?)'''"
      r'|"""(.*?)"""'
      r"|'((?:[^'\\\n]|\\.)*)'"
      r'|"((?:[^"\\\n]|\\.)*)"',
      dotAll: true,
    );
    return <String>[
      for (final RegExpMatch m in quoted.allMatches(withoutComments(source)))
        (m.group(1) ?? m.group(2) ?? m.group(3) ?? m.group(4) ?? '')
            .toLowerCase(),
    ];
  }

  List<File> sources(String root) => Directory(root)
      .listSync(recursive: true)
      .whereType<File>()
      .where(
        (File f) =>
            f.path.endsWith('.dart') &&
            !f.path.endsWith('.g.dart') &&
            !f.path.endsWith('.freezed.dart'),
      )
      .toList();

  List<String> scan(Iterable<File> files) {
    final List<String> offenders = <String>[];
    for (final File file in files) {
      for (final String text in literals(file.readAsStringSync())) {
        for (final MapEntry<String, String> rule in banned.entries) {
          if (text.contains(rule.key)) {
            offenders.add(
              '${file.path}: "${rule.key}" en "$text" — ${rule.value}',
            );
          }
        }
      }
    }
    return offenders;
  }

  test('ninguna pantalla se disculpa, ruega ni exclama', () {
    final List<String> offenders = scan(sources('lib'));
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('la regla vale también para los textos de los tests', () {
    // Si un test escribe la disculpa que la app no dice, el día que alguien
    // copie ese texto a una pantalla nadie lo va a notar.
    final List<String> offenders = scan(
      sources('test').where((File f) => !f.path.endsWith('copy_test.dart')),
    );
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('el propio test se atrapa a sí mismo', () {
    // Una red que no atrapa nada se ve igual que una red que funciona.
    expect(
      scan(<File>[File('test/design/copy_test.dart')]),
      isNotEmpty,
      reason: 'este archivo escribe las frases prohibidas a propósito',
    );
  });
}
