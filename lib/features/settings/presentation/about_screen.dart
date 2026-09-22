import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../design/tokens/colors.dart';
import '../../../design/tokens/spacing.dart';
import '../../../design/tokens/typography.dart';

/// Lo que la app dice de sí misma.
abstract final class AppInfo {
  static const String name = 'Yo Voy Go';
  static const String packageId = 'mx.yovoygo.app';

  /// Se mueve a mano con cada fase. Leerla del `pubspec` pediría un paquete
  /// más solo para pintar un número.
  static const String version = '0.8.0';
}

/// "Acerca de", con el aviso que exige la sección 10 del spec y la atribución
/// de los datos que exige la licencia.
///
/// No es letra chica: que esta app no sea la oficial es lo primero que se lee.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const _TopBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.lg,
                  Spacing.sm,
                  Spacing.lg,
                  Spacing.xxxl,
                ),
                children: <Widget>[
                  Text(
                    AppInfo.name,
                    style: AppTypography.title.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    'Versión ${AppInfo.version} · ${AppInfo.packageId}',
                    style: AppTypography.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: Spacing.xl),
                  const _Block(
                    title: 'Es una app independiente',
                    body:
                        'Yo Voy Go no tiene relación con la Coordinación '
                        'General de Movilidad (CMOV) ni con el operador del '
                        'sistema de transporte de Aguascalientes, y no está '
                        'afiliada, patrocinada ni respaldada por ellos. Es un '
                        'proyecto propio, hecho con datos públicos.',
                  ),
                  const _Block(
                    title: 'De dónde salen los datos',
                    body:
                        'Datos de transporte: Gobierno del Estado de '
                        'Aguascalientes (CMOV), vía el Hub de Datos de '
                        'Transporte Público de Codeando México. CC BY-SA 4.0. '
                        'Atribuir una fuente no es afiliarse a ella.',
                  ),
                  const _Block(
                    title: 'Los tiempos que ves',
                    body:
                        'Esta versión corre con un simulador: las posiciones '
                        'de los camiones son de mentira, construidas sobre los '
                        'horarios reales. Cuando el feed en vivo exista, la '
                        'app se conecta y nada más cambia.',
                  ),
                  const _Block(
                    title: 'El mapa',
                    body:
                        '© OpenMapTiles © OpenStreetMap, servido por '
                        'OpenFreeMap.',
                  ),
                  const _Block(
                    title: 'Lo tuyo se queda en tu teléfono',
                    body:
                        'Los favoritos, los ajustes y lo que la app aprende de '
                        'tus viajes se guardan aquí y no se mandan a ningún '
                        'lado. No hay cuenta, no hay servidor, no hay '
                        'seguimiento. Todo se borra desde Ajustes.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.xs, 0, Spacing.lg, 0),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: 'Volver',
            icon: Icon(Icons.arrow_back, color: context.colors.textPrimary),
            onPressed: () => context.canPop()
                ? context.pop()
                : context.goNamed(AppRoute.settings.name),
          ),
          const SizedBox(width: Spacing.xs),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                'Acerca de',
                style: AppTypography.title.copyWith(
                  color: context.colors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              title,
              style: AppTypography.label.copyWith(color: colors.textPrimary),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            body,
            style: AppTypography.body.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
