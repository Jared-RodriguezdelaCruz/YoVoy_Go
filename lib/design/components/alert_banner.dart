import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../tokens/colors.dart';
import '../tokens/motion.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// Una alerta de servicio: un desvío, una parada movida, una ruta sin
/// servicio.
///
/// Es una franja y no una tarjeta roja: el filo en `alert` a la izquierda
/// basta para separarla de los arribos, y el encabezado se lee en una línea.
/// La descripción, que puede ser larga, se abre al tocar. Un aviso que
/// empuja los arribos fuera de la pantalla estorba justo cuando más se
/// necesitan.
class AlertBanner extends StatefulWidget {
  const AlertBanner({
    required this.header,
    required this.effect,
    this.description,
    this.initiallyExpanded = false,
    super.key,
  });

  AlertBanner.fromAlert(
    ServiceAlert alert, {
    this.initiallyExpanded = false,
    super.key,
  }) : header = alert.header,
       effect = alert.effect,
       description = alert.description;

  final String header;
  final AlertEffect effect;
  final String? description;
  final bool initiallyExpanded;

  /// Qué ícono lleva cada efecto. El ícono acompaña al texto, nunca lo
  /// sustituye.
  static IconData iconFor(AlertEffect effect) => switch (effect) {
    AlertEffect.noService => Icons.block,
    AlertEffect.reducedService => Icons.hourglass_bottom,
    AlertEffect.significantDelays => Icons.schedule,
    AlertEffect.detour => Icons.alt_route,
    AlertEffect.stopMoved => Icons.wrong_location_outlined,
    AlertEffect.additionalService => Icons.add_circle_outline,
    AlertEffect.modifiedService => Icons.edit_calendar_outlined,
    AlertEffect.otherEffect || AlertEffect.unknownEffect => Icons.info_outline,
  };

  @override
  State<AlertBanner> createState() => _AlertBannerState();
}

class _AlertBannerState extends State<AlertBanner> {
  late bool _expanded = widget.initiallyExpanded;

  bool get _canExpand =>
      widget.description != null && widget.description!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return Semantics(
      container: true,
      label: 'Aviso de servicio',
      child: Material(
        color: colors.surfaceRaised,
        borderRadius: AppRadius.chipRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _canExpand
              ? () => setState(() => _expanded = !_expanded)
              : null,
          child: Container(
            // 48 dp de alto aunque el encabezado quepa en una línea: se abre
            // al tocar, y la sección 11 del spec no hace excepciones con los
            // controles que además son texto.
            constraints: const BoxConstraints(
              minHeight: AppSizes.minTouchTarget,
            ),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: colors.alert, width: 3)),
            ),
            padding: const EdgeInsets.fromLTRB(
              Spacing.md,
              Spacing.md,
              Spacing.sm,
              Spacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      AlertBanner.iconFor(widget.effect),
                      size: 18,
                      color: colors.alert,
                    ),
                    const SizedBox(width: Spacing.sm),
                    Expanded(
                      child: Text(
                        widget.header,
                        style: AppTypography.label.copyWith(
                          color: colors.textPrimary,
                        ),
                        maxLines: _expanded ? null : 2,
                        overflow: _expanded
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                      ),
                    ),
                    if (_canExpand)
                      Semantics(
                        button: true,
                        label: _expanded ? 'Ocultar detalle' : 'Ver detalle',
                        child: AnimatedRotation(
                          turns: _expanded ? 0.5 : 0,
                          duration: AppMotion.resolve(
                            context,
                            AppMotion.standard,
                          ),
                          child: Icon(
                            Icons.expand_more,
                            size: 20,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
                if (_expanded && _canExpand) ...<Widget>[
                  const SizedBox(height: Spacing.sm),
                  Padding(
                    padding: const EdgeInsets.only(left: 18 + Spacing.sm),
                    child: Text(
                      widget.description!,
                      style: AppTypography.body.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
