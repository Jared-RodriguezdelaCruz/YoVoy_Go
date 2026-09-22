import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../tokens/colors.dart';
import '../tokens/spacing.dart';
import 'route_badge.dart';

/// Las placas en el orden en que se toman, con la caminata marcada al
/// principio y al final. Envuelve si no caben: con dos transbordos y texto
/// al 200 % no hay renglón que alcance.
class RouteSequence extends StatelessWidget {
  const RouteSequence({required this.legs, super.key});

  final List<Leg> legs;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final List<Widget> items = <Widget>[];
    for (int i = 0; i < legs.length; i++) {
      final Leg leg = legs[i];
      if (i > 0) {
        items.add(
          Icon(Icons.chevron_right, size: 18, color: colors.textSecondary),
        );
      }
      final TransitRoute? route = leg.route;
      items.add(
        leg.isWalk || route == null
            ? Icon(Icons.directions_walk, size: 20, color: colors.textSecondary)
            : RouteBadge(
                shortName: route.shortName,
                routeId: route.id,
                gtfsColor: route.color,
                gtfsTextColor: route.textColor,
              ),
      );
    }
    return Wrap(
      spacing: Spacing.xs,
      runSpacing: Spacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: items,
    );
  }
}
