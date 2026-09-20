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
       dataAge = arrival.dataAge;

  /// `null` es un estado válido y frecuente.
  final Duration? eta;

  /// De dónde sale el dato.
  final EtaConfidence confidence;

  /// Qué tan viejo es.
  final Duration dataAge;

  /// La hora del horario programado, ya formateada ("7:04"). Cuando no se
  /// puede dar un número de minutos, esto es lo mejor que se puede ofrecer.
  final String? scheduledTimeLabel;

  final EtaChipSize size;

  /// Si el chip puede mostrar minutos.
  ///
  /// La decisión no vive aquí: vive en `Freshness`, y este widget la obedece.
  bool get showsNumericEta =>
      eta != null &&
      confidence != EtaConfidence.unknown &&
      Freshness.allowsNumericEta(Freshness.classify(dataAge));

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
      label: _semanticLabel(freshness),
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
            showsNumericEta
                ? _NumericEta(
                    minutes: eta!.inMinutes,
                    color: accent,
                    size: size,
                  )
                : _NoEta(
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
  String _semanticLabel(DataFreshness freshness) {
    if (!showsNumericEta) {
      if (scheduledTimeLabel != null) {
        return 'Sin dato en vivo. Horario programado a las $scheduledTimeLabel';
      }
      return 'Sin señal de este camión';
    }
    final int minutes = eta!.inMinutes;
    final String tiempo = minutes <= 0
        ? 'está llegando'
        : 'llega en $minutes ${minutes == 1 ? 'minuto' : 'minutos'}';
    final String origen = confidence == EtaConfidence.scheduled
        ? 'según horario'
        : 'dato ${FreshnessCopy.label(dataAge)}';
    return '$tiempo, $origen';
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
