import 'package:flutter/material.dart';

/// Andamio temporal para una pantalla que todavía no se construye.
///
/// Dice qué pantalla es, qué sección del spec la define y en qué fase del orden
/// de implementación llega. Cada uso desaparece cuando su fase aterriza; cuando
/// no quede ninguno, este archivo se borra.
class PhasePlaceholder extends StatelessWidget {
  const PhasePlaceholder({
    required this.title,
    required this.specSection,
    required this.phase,
    this.detail,
    super.key,
  });

  /// Nombre de la pantalla, como en la sección 8 del spec (pantallas).
  final String title;

  /// Sección del spec que la define, por ejemplo `8.2`.
  final String specSection;

  /// Fase del orden de implementación (sección 12 del spec) en la que se
  /// construye.
  final int phase;

  /// Contexto extra, por ejemplo el parámetro de path recibido.
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(title, style: textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Sección $specSection del spec · se construye en la fase $phase',
                style: textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              if (detail != null) ...<Widget>[
                const SizedBox(height: 12),
                Text(detail!, style: textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
