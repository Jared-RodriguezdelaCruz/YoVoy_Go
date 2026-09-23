import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/components/route_badge.dart';
import '../../../design/tokens/colors.dart';
import '../../../design/tokens/spacing.dart';
import '../../../design/tokens/typography.dart';
import '../application/map_providers.dart';
import '../application/search_index.dart';

/// "Búsqueda única": un solo campo para rutas, paradas y destinos.
///
/// Flota sobre el mapa con superficie sólida. Los resultados se abren debajo,
/// agrupados por tipo, con el grupo más probable arriba.
class MapSearchBar extends ConsumerStatefulWidget {
  const MapSearchBar({required this.onPick, this.trailing, super.key});

  /// Qué hacer con el resultado elegido.
  final ValueChanged<SearchHit> onPick;

  /// Lo que va a la derecha del campo: el chip de frescura, en el mapa.
  final Widget? trailing;

  @override
  ConsumerState<MapSearchBar> createState() => _MapSearchBarState();
}

class _MapSearchBarState extends ConsumerState<MapSearchBar> {
  final TextEditingController _text = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _clear() {
    _text.clear();
    ref.read(searchQueryProvider.notifier).set('');
  }

  void _pick(SearchHit hit) {
    _focus.unfocus();
    _clear();
    widget.onPick(hit);
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final String query = ref.watch(searchQueryProvider);
    final List<SearchGroup> groups = ref.watch(searchResultsProvider);
    final bool open = _focus.hasFocus && query.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          height: AppSizes.minTouchTarget + Spacing.xs,
          decoration: BoxDecoration(
            color: colors.surfaceRaised,
            borderRadius: AppRadius.cardRadius,
            border: Border.all(
              color: _focus.hasFocus ? colors.brand : colors.outline,
              width: AppSizes.outlineWidth,
            ),
          ),
          padding: const EdgeInsets.only(left: Spacing.md, right: Spacing.xs),
          // Estirados a lo alto: sin esto el campo mide lo que mide una línea
          // de texto —22 dp— y es lo único que se puede tocar de una barra de
          // 52. La sección 11 del spec pide 48.
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Icon(
                  Icons.search,
                  color: colors.textSecondary,
                  size: 22,
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: TextField(
                  controller: _text,
                  focusNode: _focus,
                  onChanged: ref.read(searchQueryProvider.notifier).set,
                  textInputAction: TextInputAction.search,
                  textAlignVertical: TextAlignVertical.center,
                  style: AppTypography.body.copyWith(color: colors.textPrimary),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: 'Ruta, parada o destino',
                    hintStyle: AppTypography.body.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ),
              if (query.isNotEmpty)
                Center(
                  child: IconButton(
                    tooltip: 'Borrar búsqueda',
                    onPressed: _clear,
                    icon: Icon(Icons.close, color: colors.textSecondary),
                  ),
                )
              else if (widget.trailing != null)
                Padding(
                  padding: const EdgeInsets.only(right: Spacing.xs),
                  child: Center(child: widget.trailing),
                ),
            ],
          ),
        ),
        if (open) ...<Widget>[
          const SizedBox(height: Spacing.sm),
          _Results(groups: groups, query: query, onPick: _pick),
        ],
      ],
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({
    required this.groups,
    required this.query,
    required this.onPick,
  });

  final List<SearchGroup> groups;
  final String query;
  final ValueChanged<SearchHit> onPick;

  static String _title(SearchKind kind) => switch (kind) {
    SearchKind.route => 'Rutas',
    SearchKind.stop => 'Paradas',
    SearchKind.destination => 'Destinos',
  };

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.5,
      ),
      child: Material(
        color: colors.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardRadius,
          side: BorderSide(color: colors.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: groups.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(Spacing.lg),
                child: Text(
                  'Nada con “${query.trim()}”. Prueba con el número de la '
                  'ruta o el nombre de una parada.',
                  style: AppTypography.body.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              )
            : ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
                children: <Widget>[
                  for (final SearchGroup group in groups) ...<Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Spacing.lg,
                        Spacing.sm,
                        Spacing.lg,
                        Spacing.xs,
                      ),
                      child: Text(
                        _title(group.kind),
                        style: AppTypography.caption.copyWith(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    for (final SearchHit hit in group.hits)
                      _HitTile(hit: hit, onTap: () => onPick(hit)),
                  ],
                ],
              ),
      ),
    );
  }
}

class _HitTile extends StatelessWidget {
  const _HitTile({required this.hit, required this.onTap});

  final SearchHit hit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final Widget leading = switch (hit.kind) {
      SearchKind.route => RouteBadge(
        shortName: hit.title,
        routeId: hit.id,
        gtfsColor: hit.gtfsColor,
        size: RouteBadgeSize.small,
      ),
      SearchKind.stop => Icon(
        Icons.place_outlined,
        color: colors.textSecondary,
      ),
      SearchKind.destination => Icon(
        Icons.flag_outlined,
        color: colors.textSecondary,
      ),
    };

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.minTouchTarget),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg,
            vertical: Spacing.sm,
          ),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 56,
                child: Align(alignment: Alignment.centerLeft, child: leading),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      hit.kind == SearchKind.route
                          ? (hit.subtitle ?? hit.title)
                          : hit.title,
                      style: AppTypography.body.copyWith(
                        color: colors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (hit.kind != SearchKind.route && hit.subtitle != null)
                      Text(
                        hit.subtitle!,
                        style: AppTypography.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
