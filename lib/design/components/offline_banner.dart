import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import 'notice_banner.dart';

/// "Sin conexión", y qué significa eso aquí.
///
/// No dice "no se pudo cargar" ni pide reintentar: el contenido que se ve
/// sigue siendo válido, solo dejó de refrescarse. Es el cuarto estado de la
/// sección 9 del spec aplicado a la red entera —el dato no se borra, se
/// marca— y la franja no ocupa más de una línea por eso mismo.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  static const String message =
      'Sin conexión. El mapa y los horarios son los que ya tenías.';

  @override
  Widget build(BuildContext context) => NoticeBanner(
    icon: Icons.cloud_off,
    text: message,
    edge: context.colors.alert,
  );
}
