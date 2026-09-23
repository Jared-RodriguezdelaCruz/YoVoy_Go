import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../tokens/colors.dart';
import 'notice_banner.dart';

/// De cuándo es el horario en el que esta pantalla se está apoyando.
///
/// **Un horario sin fecha se lee como si fuera de hoy.** Cuando no hay camión
/// que confirme un arribo, lo que queda en pantalla sale del feed estático que
/// la app trae empacado, y ese feed tiene fecha de publicación y una vigencia
/// que él mismo declaró. Si la vigencia ya terminó, esto lo dice: el usuario
/// decide si le sirve (§9 del spec).
///
/// Se pinta **una vez por pantalla**, nunca por fila: repetida en cada renglón
/// dejaría de leerse.
class ScheduleNote extends StatelessWidget {
  const ScheduleNote({required this.feed, required this.now, super.key});

  final FeedInfo feed;
  final DateTime now;

  /// Si esta pantalla se está apoyando en el horario empacado.
  ///
  /// Basta con que un arribo no venga de un camión: ese renglón ya salió del
  /// feed estático, sea una hora programada o una frecuencia.
  static bool leansOnSchedule(Iterable<Arrival> arrivals) => arrivals.any(
    (Arrival arrival) => arrival.confidence != EtaConfidence.live,
  );

  String get message {
    final String base = 'Horario del ${feed.versionLabel}';
    return feed.expiredAt(now) ? '$base · su vigencia terminó' : base;
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return NoticeBanner(
      icon: Icons.event_note,
      text: message,
      // Con la vigencia vencida es una advertencia; mientras vale, es una nota
      // al margen y no compite con los arribos.
      edge: feed.expiredAt(now) ? colors.alert : colors.outline,
    );
  }
}
