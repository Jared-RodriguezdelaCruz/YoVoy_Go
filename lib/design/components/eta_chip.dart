import 'package:flutter/material.dart';

import '../../core/config/freshness.dart';
import '../../core/models/arrival.dart';
import '../../core/models/enums.dart';
import '../tokens/colors.dart';
import '../tokens/motion.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';
import 'freshness_indicator.dart';

/// En cuánto llega, y qué tan confiable es esa respuesta.
///
/// Es el componente más importante de la app, y la razón es esta: **pinta el
/// estado desconocido igual de bien que el conocido.** Nunca muestra un número
/// calculado desde una posición de más de tres minutos, porque un número
/// inventado es peor que un "no sé".
///
/// Recibe los tres datos que la sección 3 del spec declara inseparables: el
/// ETA, de dónde viene y qué tan viejo es.
class EtaChip extends StatelessWidget {
  const EtaChip({
    required this.eta,
    required this.confidence,
    required this.dataAge,
    this.scheduledTimeLabel,
    this.headway,
    this.size = EtaChipSize.medium,
    super.key,
  });

  /// El mismo chip, alimentado por un arribo ya armado.
  EtaChip.fromArrival(
    Arrival arrival, {
    this.scheduledTimeLabel,
    this.size = EtaChipSize.medium,
    super.key,
  }) : eta = arrival.eta,
       confidence = arrival.confidence,
       dataAge = arrival.dataAge,
       headway = arrival.headway;

  /// `null` es un estado válido y frecuente.
  final Duration? eta;

  /// De dónde sale el dato.
  final EtaConfidence confidence;

  /// Qué tan viejo es.
  final Duration dataAge;

  /// La hora del horario programado, ya formateada ("7:04"). Cuando no se
  /// puede dar un número de minutos, esto es lo mejor que se puede ofrecer.
  final String? scheduledTimeLabel;

  /// Cada cuánto pasa la ruta según su horario. Sin dato en vivo, el chip
  /// dice "cada 20 min" en vez de un minuto que no se puede prometer.
  final Duration? headway;

  final EtaChipSize size;

  /// Si el chip puede mostrar minutos.
  ///
  /// La decisión no vive aquí: vive en `Freshness`, y este widget la obedece.
  bool get showsNumericEta =>
      eta != null &&
      confidence != EtaConfidence.unknown &&
      Freshness.allowsNumericEta(Freshness.classify(dataAge));

  /// Si el chip da la frecuencia en lugar de minutos.
  bool get showsFrequency => _showsFrequency(
    eta: eta,
    confidence: confidence,
    dataAge: dataAge,
    headway: headway,
    scheduledTimeLabel: scheduledTimeLabel,
  );

  static bool _showsFrequency({
    required Duration? eta,
    required EtaConfidence confidence,
    required Duration dataAge,
    required Duration? headway,
    required String? scheduledTimeLabel,
  }) {
    if (headway == null || scheduledTimeLabel != null) {
      return false;
    }
    // Un número en vivo siempre gana: es la mejor respuesta que hay.
    final bool liveNumber =
        confidence == EtaConfidence.live &&
        eta != null &&
        Freshness.allowsNumericEta(Freshness.classify(dataAge));
    return !liveNumber;
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final DataFreshness freshness = Freshness.classify(dataAge);

    final Color accent = switch (confidence) {
      EtaConfidence.live => FreshnessCopy.color(colors, freshness),
      EtaConfidence.scheduled => colors.textSecondary,
      EtaConfidence.unknown => colors.unknown,
    };

    return Semantics(
      label: _semanticLabel(),
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minWidth: 64),
        padding: EdgeInsets.symmetric(
          horizontal: Spacing.sm,
          vertical: size == EtaChipSize.large ? Spacing.sm : Spacing.xs,
        ),
        decoration: BoxDecoration(
          color: colors.surfaceSunken,
          borderRadius: AppRadius.chipRadius,
          border: Border.all(
            color: showsNumericEta ? accent : colors.outline,
            width: AppSizes.outlineWidth,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            if (showsFrequency)
              _Frequency(headway: headway!, color: accent, size: size)
            else if (showsNumericEta)
              _NumericEta(minutes: eta!.inMinutes, color: accent, size: size)
            else
              _NoEta(
                scheduledTimeLabel: scheduledTimeLabel,
                color: accent,
                size: size,
              ),
            const SizedBox(height: 2),
            Text(
              _footnote(freshness),
              style: AppTypography.caption.copyWith(
                color: colors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// La línea chica: de dónde viene el dato o qué tan viejo es.
  String _footnote(DataFreshness freshness) {
    if (showsFrequency) {
      return 'según horario';
    }
    if (confidence == EtaConfidence.scheduled) {
      return 'programado';
    }
    if (confidence == EtaConfidence.unknown) {
      return 'sin dato';
    }
    // Arriba ya dice "sin señal": repetirlo no informa. La edad exacta sí, y
    // es lo que deja al usuario decidir si le sirve o no.
    if (freshness == DataFreshness.unknown) {
      return FreshnessCopy.age(dataAge);
    }
    return FreshnessCopy.label(dataAge);
  }

  /// El anuncio completo para lectores de pantalla, como pide la sección 11
  /// del spec: nunca un número suelto sin su contexto.
  String _semanticLabel() {
    final String text = describe(
      eta: eta,
      confidence: confidence,
      dataAge: dataAge,
      scheduledTimeLabel: scheduledTimeLabel,
      headway: headway,
    );
    // Sin número, el chip solo abre la frase y va con mayúscula; con número
    // se anuncia igual que siempre, "llega en 4 minutos".
    return showsNumericEta ? text : text[0].toUpperCase() + text.substring(1);
  }

  /// Lo que un lector de pantalla dice de un ETA: "llega en 4 minutos, dato
  /// en vivo". Es público para que una fila que junta placa, destino y chip
  /// lo anuncie en una sola frase.
  static String describe({
    required Duration? eta,
    required EtaConfidence confidence,
    required Duration dataAge,
    String? scheduledTimeLabel,
    Duration? headway,
  }) {
    if (_showsFrequency(
      eta: eta,
      confidence: confidence,
      dataAge: dataAge,
      headway: headway,
      scheduledTimeLabel: scheduledTimeLabel,
    )) {
      final String every =
          'pasa ${FrequencyCopy.spoken(headway!)}, según horario';
      return confidence == EtaConfidence.unknown
          ? 'sin señal de este camión; $every'
          : every;
    }
    final bool numeric =
        eta != null &&
        confidence != EtaConfidence.unknown &&
        Freshness.allowsNumericEta(Freshness.classify(dataAge));
    if (!numeric) {
      if (scheduledTimeLabel != null) {
        return 'sin dato en vivo, horario programado a las $scheduledTimeLabel';
      }
      return 'sin señal de este camión';
    }
    final int minutes = eta.inMinutes;
    final String tiempo = minutes <= 0
        ? 'está llegando'
        : 'llega en $minutes ${minutes == 1 ? 'minuto' : 'minutos'}';
    final String origen = confidence == EtaConfidence.scheduled
        ? 'según horario'
        : 'dato ${FreshnessCopy.label(dataAge)}';
    return '$tiempo, $origen';
  }

  /// [describe] para un arribo ya armado.
  static String describeArrival(
    Arrival arrival, {
    String? scheduledTimeLabel,
  }) => describe(
    eta: arrival.eta,
    confidence: arrival.confidence,
    dataAge: arrival.dataAge,
    scheduledTimeLabel: scheduledTimeLabel,
    headway: arrival.headway,
  );
}

/// Cómo se dice una frecuencia.
///
/// Se redondea a 5 minutos, que es como lo dice el poste. Cuando el intervalo
/// no cae cerca de un múltiplo, se da el rango entre los dos que lo encierran:
/// "cada 15–20 min" no promete más de lo que se sabe.
abstract final class FrequencyCopy {
  /// "cada 20 min" · "cada 15–20 min".
  static String label(Duration headway) {
    final (int low, int high) = _bounds(headway);
    return low == high ? 'cada $low min' : 'cada $low–$high min';
  }

  /// Lo mismo, para un lector de pantalla: "cada 20 minutos".
  static String spoken(Duration headway) {
    final (int low, int high) = _bounds(headway);
    return low == high
        ? 'cada $low ${low == 1 ? 'minuto' : 'minutos'}'
        : 'cada $low a $high minutos';
  }

  static (int, int) _bounds(Duration headway) {
    final double minutes = headway.inSeconds / 60;
    if (minutes < 5) {
      final int exact = minutes.round().clamp(1, 5);
      return (exact, exact);
    }
    final int nearest = (minutes / 5).round() * 5;
    if ((minutes - nearest).abs() <= 1) {
      return (nearest, nearest);
    }
    final int low = (minutes / 5).floor() * 5;
    return (low, low + 5);
  }
}

/// Tamaños del chip.
enum EtaChipSize {
  /// Filas de lista.
  medium,

  /// Encabezados y modo paradero.
  large,
}

class _NumericEta extends StatelessWidget {
  const _NumericEta({
    required this.minutes,
    required this.color,
    required this.size,
  });

  final int minutes;
  final Color color;
  final EtaChipSize size;

  @override
  Widget build(BuildContext context) {
    final TextStyle numberStyle =
        (size == EtaChipSize.large
                ? AppTypography.etaDisplay
                : AppTypography.eta)
            .copyWith(color: color);

    if (minutes <= 0) {
      return Text('llegando', style: AppTypography.eta.copyWith(color: color));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        // Único movimiento que no dispara el usuario: el número entra por
        // abajo cuando cambia. Se anula solo si el sistema pide reducir
        // animaciones.
        AnimatedSwitcher(
          duration: AppMotion.resolve(context, AppMotion.eta),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.4),
                end: Offset.zero,
              ).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: Text(
            '$minutes',
            key: ValueKey<int>(minutes),
            style: numberStyle,
          ),
        ),
        const SizedBox(width: 3),
        Text('min', style: AppTypography.caption.copyWith(color: color)),
      ],
    );
  }
}

class _Frequency extends StatelessWidget {
  const _Frequency({
    required this.headway,
    required this.color,
    required this.size,
  });

  final Duration headway;
  final Color color;
  final EtaChipSize size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.schedule, size: 14, color: color),
        const SizedBox(width: Spacing.xs),
        Text(
          FrequencyCopy.label(headway),
          style:
              (size == EtaChipSize.large
                      ? AppTypography.eta
                      : AppTypography.label)
                  .copyWith(color: color),
        ),
      ],
    );
  }
}

class _NoEta extends StatelessWidget {
  const _NoEta({
    required this.scheduledTimeLabel,
    required this.color,
    required this.size,
  });

  final String? scheduledTimeLabel;
  final Color color;
  final EtaChipSize size;

  @override
  Widget build(BuildContext context) {
    // Con horario a la mano se da la hora; sin él, se dice que no se sabe.
    // Lo que nunca pasa es que salga un número de minutos.
    final String text = scheduledTimeLabel ?? 'sin señal';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          scheduledTimeLabel != null
              ? Icons.schedule
              : Icons.signal_cellular_off,
          size: 14,
          color: color,
        ),
        const SizedBox(width: Spacing.xs),
        Text(
          text,
          style:
              (size == EtaChipSize.large
                      ? AppTypography.eta
                      : AppTypography.label)
                  .copyWith(color: color),
        ),
      ],
    );
  }
}
