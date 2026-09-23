import 'package:freezed_annotation/freezed_annotation.dart';

import 'converters/epoch_date_time_converter.dart';

part 'feed_info.freezed.dart';
part 'feed_info.g.dart';

/// La cédula del feed estático, calcada de `feed_info.txt` de GTFS.
///
/// Existe porque **un horario sin fecha se lee como si fuera de hoy**. Este no
/// lo es: el feed de Aguascalientes que la app trae empacado se publicó el 2 de
/// septiembre de 2025 y declaró vigencia hasta el 31 de diciembre de 2025. La
/// app lo dice en vez de callarlo (§9 del spec: el dato viejo no se borra, se
/// marca).
@freezed
abstract class FeedInfo with _$FeedInfo {
  const factory FeedInfo({
    @JsonKey(name: 'feed_publisher_name') required String publisherName,
    @JsonKey(name: 'feed_publisher_url') required String publisherUrl,
    @JsonKey(name: 'feed_start_date')
    @GtfsDateConverter()
    required DateTime startDate,
    @JsonKey(name: 'feed_end_date')
    @GtfsDateConverter()
    required DateTime endDate,
    @JsonKey(name: 'feed_version') required String version,
  }) = _FeedInfo;

  const FeedInfo._();

  factory FeedInfo.fromJson(Map<String, dynamic> json) =>
      _$FeedInfoFromJson(json);

  /// Si la vigencia que el propio feed declaró ya terminó.
  ///
  /// Se compara contra el día, no contra el instante: un feed que vence hoy
  /// vale hoy completo.
  bool expiredAt(DateTime now) {
    final DateTime day = DateTime.utc(now.year, now.month, now.day);
    return day.isAfter(endDate);
  }

  /// La fecha de publicación en letras: "2 de septiembre de 2025".
  ///
  /// El `feed_version` de este feed es una fecha `AAAAMMDD`. Cuando no lo sea
  /// —el campo es texto libre en GTFS— se muestra tal cual, que es más honesto
  /// que inventarle una fecha.
  String get versionLabel => spelledDate(version) ?? version;

  /// El último día que el feed dijo valer, en letras.
  String get endLabel => spellDate(endDate);
}

/// "2 de septiembre de 2025".
String spellDate(DateTime date) =>
    '${date.day} de ${_months[date.month - 1]} de ${date.year}';

/// Lo mismo, desde `"20250902"`. `null` si no es una fecha.
String? spelledDate(String yyyymmdd) {
  if (yyyymmdd.length != 8 || int.tryParse(yyyymmdd) == null) {
    return null;
  }
  final int month = int.parse(yyyymmdd.substring(4, 6));
  if (month < 1 || month > 12) {
    return null;
  }
  return spellDate(
    DateTime.utc(
      int.parse(yyyymmdd.substring(0, 4)),
      month,
      int.parse(yyyymmdd.substring(6, 8)),
    ),
  );
}

// A mano y no con `intl`: los nombres de mes en español exigen cargar los datos
// de locale al arrancar, y son doce palabras.
const List<String> _months = <String>[
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];
