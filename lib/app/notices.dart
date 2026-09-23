/// Los dos avisos que cualquier pantalla puede necesitar, ya conectados.
///
/// Viven aquí y no en `design/components/` porque leen providers, y los
/// componentes del sistema de diseño no leen nada: se les pasa todo, y por eso
/// la galería puede pintarlos sin montar la app.
///
/// Los dos desaparecen **con todo y su margen** cuando no aplican, para que
/// insertarlos sea una línea y no deje un hueco los días que no hay nada que
/// avisar.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/clock/clock_provider.dart';
import '../core/data/transit_network.dart';
import '../core/models/models.dart';
import '../core/network/connectivity.dart';
import '../core/transit/live_providers.dart';
import '../design/components/components.dart';

/// "Sin conexión", cuando el teléfono no tiene ninguna interfaz de red.
class OfflineNotice extends ConsumerWidget {
  const OfflineNotice({this.padding = EdgeInsets.zero, super.key});

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NetworkStatus? status = ref.watch(networkStatusProvider).value;
    if (status == null || !status.isOffline) {
      return const SizedBox.shrink();
    }
    return Padding(padding: padding, child: const OfflineBanner());
  }
}

/// De cuándo es el horario, cuando la pantalla se está apoyando en él.
class ScheduleNotice extends ConsumerWidget {
  const ScheduleNotice({
    required this.arrivals,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  /// Lo que la pantalla está mostrando. Si todo viene de un camión en vivo, no
  /// hay horario que fechar y el aviso no aparece.
  final Iterable<Arrival>? arrivals;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Iterable<Arrival>? rows = arrivals;
    if (rows == null || !ScheduleNote.leansOnSchedule(rows)) {
      return const SizedBox.shrink();
    }
    final TransitNetwork? network = ref.watch(transitNetworkProvider).value;
    if (network == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: padding,
      child: ScheduleNote(feed: network.feed, now: ref.watch(clockProvider)()),
    );
  }
}
