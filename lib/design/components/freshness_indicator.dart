import 'package:flutter/material.dart';

import '../../core/config/freshness.dart';
import '../tokens/colors.dart';
import '../tokens/motion.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// Traduce la edad de un dato a lenguaje humano.
///
/// Es el vocabulario compartido de toda la app: si la frescura se nombra
/// distinto en cada pantalla, el usuario no aprende a leerla.
abstract final class FreshnessCopy {
  /// "en vivo" · "hace 2 min" · "sin señal".
  static String label(Duration dataAge) {
    switch (Freshness.classify(dataAge)) {
      case DataFreshness.live:
        return 'en vivo';
      case DataFreshness.stale:
        final int minutes = dataAge.inMinutes;
        return minutes < 1 ? 'hace menos de 1 min' : 'hace $minutes min';
      case DataFreshness.unknown:
        return 'sin señal';
    }
  }

  /// La edad cruda, sin traducirla a estado: "hace 9 min".
  ///
  /// Sirve donde [label] diría "sin señal" y esa palabra ya está en pantalla:
  /// repetirla no informa, y la edad exacta sí.
  static String age(Duration dataAge) {
    final int minutes = dataAge.inMinutes;
    if (minutes < 1) {
      return 'hace menos de 1 min';
    }
    if (minutes < 60) {
      return 'hace $minutes min';
    }
    final int hours = dataAge.inHours;
    return hours == 1 ? 'hace 1 h' : 'hace $hours h';
  }

  /// El color del estado. Nunca va solo: siempre acompañado de texto e ícono,
  /// porque hay daltonismo y hay sol directo.
  static Color color(AppColors colors, DataFreshness freshness) {
    switch (freshness) {
      case DataFreshness.live:
        return colors.live;
      case DataFreshness.stale:
        return colors.stale;
      case DataFreshness.unknown:
        return colors.unknown;
    }
  }

  static IconData icon(DataFreshness freshness) {
    switch (freshness) {
      case DataFreshness.live:
        return Icons.circle;
      case DataFreshness.stale:
        return Icons.history;
      case DataFreshness.unknown:
        return Icons.signal_cellular_off;
    }
  }
}

/// Qué tan viejo es lo que estás viendo.
///
/// El [pulse] es el único movimiento continuo de la app y va **una sola vez
/// por pantalla**, en el chip de frescura global. Uno por fila convierte la
/// lista en un árbol de navidad y cuesta frames.
class FreshnessIndicator extends StatefulWidget {
  const FreshnessIndicator({
    required this.dataAge,
    this.pulse = false,
    this.compact = false,
    super.key,
  });

  final Duration dataAge;

  /// Solo en el indicador global de la pantalla.
  final bool pulse;

  /// Sin fondo ni borde, para meterlo dentro de otro componente.
  final bool compact;

  @override
  State<FreshnessIndicator> createState() => _FreshnessIndicatorState();
}

class _FreshnessIndicatorState extends State<FreshnessIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.pulse,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  @override
  void didUpdateWidget(FreshnessIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
  }

  void _syncPulse() {
    final bool shouldPulse =
        widget.pulse &&
        AppMotion.allowsLooping(context) &&
        Freshness.classify(widget.dataAge) == DataFreshness.live;

    if (shouldPulse && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!shouldPulse && _controller.isAnimating) {
      _controller
        ..stop()
        ..value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final DataFreshness freshness = Freshness.classify(widget.dataAge);
    final Color color = FreshnessCopy.color(colors, freshness);
    final String label = FreshnessCopy.label(widget.dataAge);

    final Widget dot = Icon(
      FreshnessCopy.icon(freshness),
      size: freshness == DataFreshness.live ? 8 : 14,
      color: color,
    );

    final Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (widget.pulse)
          FadeTransition(
            opacity: Tween<double>(begin: 0.35, end: 1).animate(_controller),
            child: dot,
          )
        else
          dot,
        const SizedBox(width: Spacing.xs),
        Text(label, style: AppTypography.caption.copyWith(color: color)),
      ],
    );

    return Semantics(
      label: 'Dato $label',
      excludeSemantics: true,
      child: widget.compact
          ? content
          : Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.sm,
                vertical: Spacing.xs,
              ),
              decoration: BoxDecoration(
                color: colors.surfaceRaised,
                borderRadius: AppRadius.chipRadius,
                border: Border.all(
                  color: colors.outline,
                  width: AppSizes.outlineWidth,
                ),
              ),
              child: content,
            ),
    );
  }
}
