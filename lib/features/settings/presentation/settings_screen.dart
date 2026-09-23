import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/cache/tile_cache.dart';
import '../../../core/history/history_providers.dart';
import '../../../design/tokens/colors.dart';
import '../../../design/tokens/spacing.dart';
import '../../../design/tokens/typography.dart';
import '../application/settings_providers.dart';
import '../data/settings_store.dart';

/// Ajustes, como en la sección 8.6 del spec.
///
/// Todo lo que hay aquí es del teléfono: nada se sincroniza, nada se manda.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = context.colors;
    final AppSettings settings = ref.watch(appSettingsProvider);

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
                  const _SectionTitle('Apariencia'),
                  _ThemeChoice(mode: settings.themeMode),
                  const SizedBox(height: Spacing.lg),
                  _TextScaleChoice(scale: settings.textScale),
                  const SizedBox(height: Spacing.sm),
                  _ReduceMotionSwitch(reduce: settings.reduceMotion),
                  const SizedBox(height: Spacing.xl),
                  const _SectionTitle('Datos'),
                  const _ClearCacheRow(),
                  const _ClearHistoryRow(),
                  const SizedBox(height: Spacing.xl),
                  _Row(
                    icon: Icons.info_outline,
                    title: 'Acerca de Yo Voy Go',
                    subtitle: 'Quién la hace y de dónde salen los datos',
                    onTap: () => context.pushNamed(AppRoute.about.name),
                  ),
                  if (kDebugMode) ...<Widget>[
                    const SizedBox(height: Spacing.xl),
                    const _SectionTitle('Herramientas de desarrollo'),
                    _Row(
                      icon: Icons.tune,
                      title: 'Panel del simulador',
                      subtitle: 'Latencia, errores, señal perdida',
                      onTap: () => context.pushNamed(AppRoute.simulator.name),
                    ),
                    _Row(
                      icon: Icons.palette_outlined,
                      title: 'Design system',
                      subtitle: 'La galería de componentes',
                      onTap: () => context.pushNamed(AppRoute.gallery.name),
                    ),
                  ],
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
                : context.goNamed(AppRoute.map.name),
          ),
          const SizedBox(width: Spacing.xs),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                'Ajustes',
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Spacing.md),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: AppTypography.label.copyWith(
          color: context.colors.textSecondary,
        ),
      ),
    ),
  );
}

/// Claro, oscuro o el del sistema. Chips y no un desplegable: las tres
/// opciones caben y se ven de una.
class _ThemeChoice extends ConsumerWidget {
  const _ThemeChoice({required this.mode});

  final ThemeMode mode;

  static const Map<ThemeMode, String> _labels = <ThemeMode, String>{
    ThemeMode.light: 'Claro',
    ThemeMode.dark: 'Oscuro',
    ThemeMode.system: 'El del sistema',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Field(
      label: 'Tema',
      child: Wrap(
        spacing: Spacing.sm,
        runSpacing: Spacing.sm,
        children: <Widget>[
          for (final MapEntry<ThemeMode, String> entry in _labels.entries)
            _Choice(
              label: entry.value,
              selected: mode == entry.key,
              onSelected: () =>
                  ref.read(settingsProvider.notifier).setThemeMode(entry.key),
            ),
        ],
      ),
    );
  }
}

/// La escala propia de la app, con una línea que se ve cambiar.
class _TextScaleChoice extends ConsumerWidget {
  const _TextScaleChoice({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = context.colors;
    return _Field(
      label: 'Tamaño de texto',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: <Widget>[
              for (final (double value, String label) in textScaleChoices)
                _Choice(
                  label: label,
                  selected: (scale - value).abs() < 0.001,
                  onSelected: () =>
                      ref.read(settingsProvider.notifier).setTextScale(value),
                ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          Text(
            'El 20 llega en 4 min',
            style: AppTypography.body.copyWith(color: colors.textSecondary),
          ),
          Text(
            'Se multiplica por el tamaño que trae tu teléfono, hasta el doble.',
            style: AppTypography.caption.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ReduceMotionSwitch extends ConsumerWidget {
  const _ReduceMotionSwitch({required this.reduce});

  final bool reduce;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = context.colors;
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      value: reduce,
      activeThumbColor: colors.brand,
      title: Text(
        'Reducir animaciones',
        style: AppTypography.body.copyWith(color: colors.textPrimary),
      ),
      subtitle: Text(
        'Sin latidos ni transiciones. Los datos siguen actualizándose.',
        style: AppTypography.caption.copyWith(color: colors.textSecondary),
      ),
      onChanged: (bool value) =>
          ref.read(settingsProvider.notifier).setReduceMotion(reduce: value),
    );
  }
}

class _ClearCacheRow extends ConsumerWidget {
  const _ClearCacheRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int bytes = ref.watch(tileCacheSizeProvider).value ?? 0;
    return _Row(
      icon: Icons.layers_clear_outlined,
      title: 'Limpiar el mapa guardado',
      subtitle: bytes <= 0
          ? 'No hay nada guardado todavía'
          : 'Ocupa ${cacheSizeLabel(bytes)}. Se vuelve a bajar al usarlo.',
      onTap: bytes <= 0
          ? null
          : () async {
              final ScaffoldMessengerState messenger = ScaffoldMessenger.of(
                context,
              );
              await clearTileCache(
                await ref.read(tileCachePathProvider.future),
              );
              ref.invalidate(tileCacheSizeProvider);
              messenger.showSnackBar(
                SnackBar(content: Text('Liberaste ${cacheSizeLabel(bytes)}')),
              );
            },
    );
  }
}

class _ClearHistoryRow extends ConsumerWidget {
  const _ClearHistoryRow();

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('¿Borrar lo que la app aprendió?'),
        content: const Text(
          'Se olvidan las paradas que sueles usar y lo que se observó sobre '
          'la puntualidad de cada ruta. Tus favoritos se quedan.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (yes ?? false) {
      await ref.read(historyMaintenanceProvider.notifier).clear();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int observations =
        ref.watch(arrivalHistoryProvider).value?.length ?? 0;
    return _Row(
      icon: Icons.history_toggle_off,
      title: 'Borrar el historial',
      subtitle: observations == 0
          ? 'Nada guardado todavía. Nunca sale del teléfono.'
          : '$observations observaciones. Nunca salen del teléfono.',
      onTap: () => _confirm(context, ref),
    );
  }
}

/// Una etiqueta arriba de su control, como en el planificador.
class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(
        label,
        style: AppTypography.body.copyWith(
          color: context.colors.textPrimary,
          // SemiBold: es la etiqueta de un campo, no texto corrido, y es lo
          // que se busca al recorrer la pantalla de arriba abajo.
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: Spacing.sm),
      child,
    ],
  );
}

/// Una fila que lleva a algún lado o hace algo.
class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: colors.textSecondary),
      title: Text(
        title,
        style: AppTypography.body.copyWith(color: colors.textPrimary),
      ),
      subtitle: Text(
        subtitle,
        style: AppTypography.caption.copyWith(color: colors.textSecondary),
      ),
      onTap: onTap,
    );
  }
}

/// Una opción de ajustes, con la paleta de la app.
///
/// El chip de Material trae su propio color de selección y aquí lo pintaría
/// de verde: la marca es índigo, y el color lo pone el tema, no el widget.
class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (bool _) => onSelected(),
      showCheckmark: false,
      labelStyle: AppTypography.label.copyWith(
        color: selected ? colors.onBrand : colors.textPrimary,
        // El elegido va en SemiBold: tinta oscura sobre el índigo aclarado del
        // tema oscuro es la combinación más floja de la app a 14 px.
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
      backgroundColor: colors.surfaceRaised,
      selectedColor: colors.brand,
      side: BorderSide(color: selected ? colors.brand : colors.outline),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.chipRadius),
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}
