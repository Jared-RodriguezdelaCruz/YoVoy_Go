import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/transit_network.dart';
import '../../../design/tokens/colors.dart';
import '../../../design/tokens/spacing.dart';
import '../../../design/tokens/typography.dart';
import '../../map/application/map_providers.dart';
import '../../map/application/search_index.dart';
import '../application/trip_request.dart';

/// Abre el buscador de un extremo del viaje. Devuelve `null` si el usuario
/// se arrepiente.
Future<PlaceRef?> showPlacePicker(
  BuildContext context, {
  required String title,
  bool offerHere = true,
}) => Navigator.of(context).push<PlaceRef>(
  MaterialPageRoute<PlaceRef>(
    fullscreenDialog: true,
    builder: (BuildContext context) =>
        PlacePickerScreen(title: title, offerHere: offerHere),
  ),
);

/// La misma búsqueda única del mapa, pero solo con lugares: paradas y
/// destinos. Una ruta no es un lugar al que se llegue.
class PlacePickerScreen extends ConsumerStatefulWidget {
  const PlacePickerScreen({
    required this.title,
    this.offerHere = true,
    super.key,
  });

  final String title;

  /// "Mi ubicación" arriba de todo. Es lo que se elige casi siempre como
  /// origen.
  final bool offerHere;

  @override
  ConsumerState<PlacePickerScreen> createState() => _PlacePickerScreenState();
}

class _PlacePickerScreenState extends ConsumerState<PlacePickerScreen> {
  final TextEditingController _text = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _pickHit(SearchHit hit, TransitNetwork? network) {
    final PlaceRef? place = switch (hit.kind) {
      SearchKind.stop => StopPlace(hit.id),
      SearchKind.destination => switch (network == null
          ? null
          : terminalStopFor(
              network,
              headsign: hit.title,
              routeIds: hit.routeIds,
            )) {
        final String stopId => StopPlace(stopId),
        null => null,
      },
      SearchKind.route => null,
    };
    if (place != null) {
      Navigator.of(context).pop(place);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final SearchIndex? index = ref.watch(searchIndexProvider).value;
    final TransitNetwork? network = ref.watch(transitNetworkProvider).value;
    final List<SearchGroup> groups = <SearchGroup>[
      for (final SearchGroup group
          in index?.search(_query) ?? const <SearchGroup>[])
        if (group.kind != SearchKind.route) group,
    ];

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        title: Text(
          widget.title,
          style: AppTypography.title.copyWith(color: colors.textPrimary),
        ),
        leading: IconButton(
          tooltip: 'Cerrar',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.lg,
              Spacing.sm,
              Spacing.lg,
              Spacing.sm,
            ),
            child: TextField(
              controller: _text,
              autofocus: true,
              onChanged: (String value) => setState(() => _query = value),
              textInputAction: TextInputAction.search,
              style: AppTypography.body.copyWith(color: colors.textPrimary),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search, color: colors.textSecondary),
                hintText: 'Parada o destino',
                hintStyle: AppTypography.body.copyWith(
                  color: colors.textSecondary,
                ),
                filled: true,
                fillColor: colors.surfaceRaised,
                border: OutlineInputBorder(
                  borderRadius: AppRadius.cardRadius,
                  borderSide: BorderSide(color: colors.outline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadius.cardRadius,
                  borderSide: BorderSide(color: colors.outline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadius.cardRadius,
                  borderSide: BorderSide(color: colors.brand),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: <Widget>[
                if (widget.offerHere)
                  ListTile(
                    leading: Icon(Icons.my_location, color: colors.brand),
                    title: Text(
                      'Mi ubicación',
                      style: AppTypography.label.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    onTap: () => Navigator.of(context).pop(const HerePlace()),
                  ),
                if (_query.trim().isNotEmpty && groups.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(Spacing.lg),
                    child: Text(
                      'Ninguna parada ni destino se llama así. Prueba con el '
                      'nombre de una calle o de una colonia.',
                      style: AppTypography.body.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                for (final SearchGroup group in groups) ...<Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Spacing.lg,
                      Spacing.lg,
                      Spacing.lg,
                      Spacing.xs,
                    ),
                    child: Semantics(
                      header: true,
                      child: Text(
                        group.kind == SearchKind.stop ? 'Paradas' : 'Destinos',
                        style: AppTypography.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  for (final SearchHit hit in group.hits)
                    ListTile(
                      leading: Icon(
                        group.kind == SearchKind.stop
                            ? Icons.place_outlined
                            : Icons.flag_outlined,
                        color: colors.textSecondary,
                      ),
                      title: Text(
                        hit.title,
                        style: AppTypography.label.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      subtitle: hit.subtitle == null
                          ? null
                          : Text(
                              group.kind == SearchKind.destination
                                  ? 'Fin del recorrido · ${hit.subtitle}'
                                  : hit.subtitle!,
                              style: AppTypography.caption.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                      onTap: () => _pickHit(hit, network),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
