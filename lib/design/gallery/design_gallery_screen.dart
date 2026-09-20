import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../components/components.dart';
import '../theme.dart';
import '../tokens/colors.dart';
import '../tokens/route_palette.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// Galería del design system, solo en builds de debug.
///
/// Cada componente en **todos** sus estados, con los dos temas y la escala de
/// texto hasta 200 % a un toque de distancia. Si un componente se rompe aquí,
/// se rompe en producción; esta pantalla existe para que eso se vea antes.
class DesignGalleryScreen extends StatefulWidget {
  const DesignGalleryScreen({super.key});

  @override
  State<DesignGalleryScreen> createState() => _DesignGalleryScreenState();
}

class _DesignGalleryScreenState extends State<DesignGalleryScreen> {
  Brightness _brightness = Brightness.dark;
  double _textScale = 1;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = _brightness == Brightness.dark
        ? AppTheme.dark
        : AppTheme.light;

    return Theme(
      data: theme,
      child: MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(_textScale)),
        child: Builder(
          builder: (BuildContext context) => Scaffold(
            backgroundColor: context.colors.surface,
            appBar: AppBar(
              title: const Text('Galería'),
              actions: <Widget>[
                IconButton(
                  tooltip: _brightness == Brightness.dark
                      ? 'Ver en tema claro'
                      : 'Ver en tema oscuro',
                  onPressed: () => setState(() {
                    _brightness = _brightness == Brightness.dark
                        ? Brightness.light
                        : Brightness.dark;
                  }),
                  icon: Icon(
                    _brightness == Brightness.dark
                        ? Icons.light_mode
                        : Icons.dark_mode,
                  ),
                ),
                PopupMenuButton<double>(
                  tooltip: 'Escala de texto',
                  initialValue: _textScale,
                  onSelected: (double value) =>
                      setState(() => _textScale = value),
                  itemBuilder: (BuildContext context) =>
                      const <PopupMenuEntry<double>>[
                        PopupMenuItem<double>(value: 1, child: Text('100 %')),
                        PopupMenuItem<double>(value: 1.5, child: Text('150 %')),
                        PopupMenuItem<double>(value: 2, child: Text('200 %')),
                      ],
                  icon: const Icon(Icons.format_size),
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(
                Spacing.lg,
                Spacing.sm,
                Spacing.lg,
                Spacing.xxxl,
              ),
              children: const <Widget>[
                _PaletteSection(),
                _TypographySection(),
                _RouteBadgeSection(),
                _EtaChipSection(),
                _FreshnessSection(),
                _StopTileSection(),
                _RouteLineSection(),
                _VehicleMarkerSection(),
                _StatesSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Andamio de la galería
// ---------------------------------------------------------------------------

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.note,
    required this.child,
  });

  final String title;
  final String note;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(top: Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: AppTypography.title.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            note,
            style: AppTypography.caption.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: Spacing.lg),
          child,
          const SizedBox(height: Spacing.sm),
          Divider(color: colors.outline),
        ],
      ),
    );
  }
}

class _Labeled extends StatelessWidget {
  const _Labeled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        child,
        const SizedBox(height: Spacing.xs),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Secciones
// ---------------------------------------------------------------------------

class _PaletteSection extends StatelessWidget {
  const _PaletteSection();

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return _Section(
      title: 'Color',
      note:
          'Los estados de tiempo real no comparten color con la marca: '
          'un color, un significado.',
      child: Wrap(
        spacing: Spacing.md,
        runSpacing: Spacing.md,
        children: <Widget>[
          _Swatch(color: colors.surface, label: 'surface'),
          _Swatch(color: colors.surfaceRaised, label: 'raised'),
          _Swatch(color: colors.surfaceSunken, label: 'sunken'),
          _Swatch(color: colors.outline, label: 'outline'),
          _Swatch(color: colors.brand, label: 'marca'),
          _Swatch(color: colors.live, label: 'en vivo'),
          _Swatch(color: colors.stale, label: 'viejo'),
          _Swatch(color: colors.unknown, label: 'sin dato'),
          _Swatch(color: colors.alert, label: 'alerta'),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return _Labeled(
      label: label,
      child: Container(
        width: 64,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(
            color: context.colors.outline,
            width: AppSizes.outlineWidth,
          ),
        ),
      ),
    );
  }
}

class _TypographySection extends StatelessWidget {
  const _TypographySection();

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return _Section(
      title: 'Tipografía',
      note:
          'Barlow y Barlow Semi Condensed. Los números, con cifras tabulares.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '14',
            style: AppTypography.etaDisplay.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'Avenida de la Convención',
            style: AppTypography.title.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            'Texto general en Barlow, el que se lee de corrido.',
            style: AppTypography.body.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            'Etiqueta de control',
            style: AppTypography.label.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            'Metadato · frescura del dato',
            style: AppTypography.caption.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _RouteBadgeSection extends StatelessWidget {
  const _RouteBadgeSection();

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'RouteBadge',
      note:
          'El color sale de GTFS; cuando falta, de un hash del id. '
          'El texto se elige por luminancia del fondo.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: Spacing.xl,
            runSpacing: Spacing.lg,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: const <Widget>[
              _Labeled(
                label: 'small',
                child: RouteBadge(
                  shortName: '20',
                  routeId: 'r20',
                  size: RouteBadgeSize.small,
                ),
              ),
              _Labeled(
                label: 'medium',
                child: RouteBadge(shortName: '20', routeId: 'r20'),
              ),
              _Labeled(
                label: 'large',
                child: RouteBadge(
                  shortName: '20',
                  routeId: 'r20',
                  size: RouteBadgeSize.large,
                ),
              ),
              _Labeled(
                label: 'color de GTFS',
                child: RouteBadge(
                  shortName: '31-A',
                  routeId: 'r31',
                  gtfsColor: '00854A',
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.lg),
          Text(
            'La paleta de doce, la que usa una ruta sin color propio',
            style: AppTypography.caption.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: <Widget>[
              for (int i = 0; i < RoutePalette.tones.length; i++)
                RouteBadge(
                  shortName: '${i + 1}',
                  routeId: 'tono-$i',
                  gtfsColor: RoutePalette.tones[i]
                      .toARGB32()
                      .toRadixString(16)
                      .substring(2),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EtaChipSection extends StatelessWidget {
  const _EtaChipSection();

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'EtaChip',
      note:
          'El componente más importante de la app. Pasados los 180 segundos '
          'no hay número: hay estado.',
      child: Wrap(
        spacing: Spacing.lg,
        runSpacing: Spacing.lg,
        children: const <Widget>[
          _Labeled(
            label: 'en vivo',
            child: EtaChip(
              eta: Duration(minutes: 4),
              confidence: EtaConfidence.live,
              dataAge: Duration(seconds: 12),
            ),
          ),
          _Labeled(
            label: 'dato viejo',
            child: EtaChip(
              eta: Duration(minutes: 7),
              confidence: EtaConfidence.live,
              dataAge: Duration(seconds: 130),
            ),
          ),
          _Labeled(
            label: 'programado',
            child: EtaChip(
              eta: Duration(minutes: 12),
              confidence: EtaConfidence.scheduled,
              dataAge: Duration(seconds: 20),
            ),
          ),
          _Labeled(
            label: 'sin señal',
            child: EtaChip(
              eta: Duration(minutes: 4),
              confidence: EtaConfidence.live,
              dataAge: Duration(minutes: 9),
            ),
          ),
          _Labeled(
            label: 'sin dato, con horario',
            child: EtaChip(
              eta: null,
              confidence: EtaConfidence.unknown,
              dataAge: Duration(minutes: 20),
              scheduledTimeLabel: '7:04',
            ),
          ),
          _Labeled(
            label: 'llegando',
            child: EtaChip(
              eta: Duration.zero,
              confidence: EtaConfidence.live,
              dataAge: Duration(seconds: 5),
            ),
          ),
          _Labeled(
            label: 'grande, modo paradero',
            child: EtaChip(
              eta: Duration(minutes: 3),
              confidence: EtaConfidence.live,
              dataAge: Duration(seconds: 8),
              size: EtaChipSize.large,
            ),
          ),
        ],
      ),
    );
  }
}

class _FreshnessSection extends StatelessWidget {
  const _FreshnessSection();

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'FreshnessIndicator',
      note: 'El pulso va una sola vez por pantalla, en el indicador global.',
      child: Wrap(
        spacing: Spacing.lg,
        runSpacing: Spacing.lg,
        children: const <Widget>[
          _Labeled(
            label: 'global, con pulso',
            child: FreshnessIndicator(
              dataAge: Duration(seconds: 15),
              pulse: true,
            ),
          ),
          _Labeled(
            label: 'viejo',
            child: FreshnessIndicator(dataAge: Duration(seconds: 120)),
          ),
          _Labeled(
            label: 'sin señal',
            child: FreshnessIndicator(dataAge: Duration(minutes: 6)),
          ),
          _Labeled(
            label: 'compacto',
            child: FreshnessIndicator(
              dataAge: Duration(seconds: 30),
              compact: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _StopTileSection extends StatelessWidget {
  const _StopTileSection();

  static const List<Arrival> _arrivals = <Arrival>[
    Arrival(
      routeId: 'r20',
      routeShortName: '20',
      headsign: 'Centro',
      eta: Duration(minutes: 4),
      confidence: EtaConfidence.live,
      dataAge: Duration(seconds: 14),
    ),
    Arrival(
      routeId: 'r31',
      routeShortName: '31',
      headsign: 'Morelos',
      eta: Duration(minutes: 11),
      confidence: EtaConfidence.live,
      dataAge: Duration(seconds: 140),
    ),
    Arrival(
      routeId: 'r09',
      routeShortName: '9',
      headsign: 'Norte',
      eta: Duration(minutes: 6),
      confidence: EtaConfidence.scheduled,
      dataAge: Duration(seconds: 25),
    ),
    Arrival(
      routeId: 'r44',
      routeShortName: '44',
      headsign: 'Insurgentes',
      dataAge: Duration(minutes: 7),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'StopTile',
      note: 'Una parada y sus arribos. Sin camiones, lo dice con palabras.',
      child: Column(
        children: <Widget>[
          StopTile(
            name: 'Bonanza',
            code: 'B-12',
            distanceLabel: 'a 240 m',
            accessibility: WheelchairBoarding.accessible,
            isFavorite: true,
            arrivals: _arrivals,
            onTap: () {},
            onToggleFavorite: () {},
          ),
          const SizedBox(height: Spacing.md),
          StopTile(
            name: 'Héroes de Nacozari',
            code: 'H-03',
            arrivals: const <Arrival>[],
            onTap: () {},
            onToggleFavorite: () {},
          ),
        ],
      ),
    );
  }
}

class _RouteLineSection extends StatelessWidget {
  const _RouteLineSection();

  static const List<Offset> _points = <Offset>[
    Offset(8, 60),
    Offset(70, 24),
    Offset(140, 52),
    Offset(210, 18),
    Offset(280, 56),
  ];

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'RouteLine',
      note: 'El trazo es el héroe: grueso, saturado y con halo de contraste.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final (String label, double zoom, bool dashed)
              in <(String, double, bool)>[
                ('zoom 11', 11, false),
                ('zoom 14', 14, false),
                ('zoom 17', 17, false),
                ('tramo a pie', 14, true),
              ])
            _Labeled(
              label: label,
              child: SizedBox(
                height: 76,
                width: 300,
                child: RouteLine(
                  points: _points,
                  color: RoutePalette.colorForRouteId('r20'),
                  zoom: zoom,
                  dashed: dashed,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _VehicleMarkerSection extends StatelessWidget {
  const _VehicleMarkerSection();

  @override
  Widget build(BuildContext context) {
    final Color color = RoutePalette.colorForRouteId('r20');

    return _Section(
      title: 'VehicleMarker',
      note: 'Sin bearing degrada a círculo. Una flecha que miente es peor.',
      child: Wrap(
        spacing: Spacing.xl,
        runSpacing: Spacing.lg,
        children: <Widget>[
          _Labeled(
            label: 'al norte',
            child: VehicleMarker(color: color, bearing: 0),
          ),
          _Labeled(
            label: 'al este',
            child: VehicleMarker(color: color, bearing: 90),
          ),
          _Labeled(
            label: 'al suroeste',
            child: VehicleMarker(color: color, bearing: 220),
          ),
          _Labeled(
            label: 'sin bearing',
            child: VehicleMarker(color: color),
          ),
          _Labeled(
            label: 'dato viejo',
            child: VehicleMarker(color: color, bearing: 120, isStale: true),
          ),
          _Labeled(
            label: 'grande',
            child: VehicleMarker(color: color, bearing: 45, size: 40),
          ),
        ],
      ),
    );
  }
}

class _StatesSection extends StatelessWidget {
  const _StatesSection();

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'EmptyState y ErrorState',
      note: 'Los dos estados que casi nadie diseña, y que se ven todo el día.',
      child: Column(
        children: <Widget>[
          EmptyState(
            icon: Icons.directions_bus_filled_outlined,
            title: 'Esta ruta no tiene servicio ahora',
            message:
                'El último camión pasó a las 21:40. Mañana empieza a las 5:30.',
            actionLabel: 'Ver el horario',
            onAction: () {},
          ),
          const SizedBox(height: Spacing.xl),
          ErrorState(
            title: 'No se pudo cargar la parada',
            message: 'Revisa tu conexión y vuelve a intentar.',
            onRetry: () {},
          ),
        ],
      ),
    );
  }
}
