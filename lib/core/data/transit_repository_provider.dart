import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../clock/clock_provider.dart';
import 'mock/mock_dataset.dart';
import 'mock/mock_transit_repository.dart';
import 'mock/simulator_config.dart';
import 'remote/remote_transit_repository.dart';
import 'transit_repository.dart';

part 'transit_repository_provider.g.dart';

/// El dataset de `assets/mock/`, cargado una sola vez.
///
/// `keepAlive` porque son 2.8 MB de JSON: volver a parsearlos cada vez que una
/// pantalla se va de pantalla sería tirar trabajo a la basura.
@Riverpod(keepAlive: true)
Future<MockDataset> mockDataset(Ref ref) => MockDataset.load();

/// Los parámetros del simulador, ajustables desde `/debug/simulator`.
///
/// Vive aparte del repositorio para que moverlos no obligue a recargar el
/// dataset: cambiar la tasa de error no tiene por qué costar 2.8 MB de parseo.
@Riverpod(keepAlive: true)
class SimulatorSettings extends _$SimulatorSettings {
  @override
  SimulatorConfig build() => const SimulatorConfig();

  void update(SimulatorConfig next) => state = next;

  /// El simulador sin fallas. No es "el modo bueno": es el modo con el que se
  /// prueba otra cosa.
  void makePerfect() => state = SimulatorConfig.perfect;

  /// El peor caso razonable, el de la lista de cierre del roadmap.
  void makeHostile() => state = SimulatorConfig.hostile;
}

/// El repositorio activo.
///
/// La selección es por flag de compilación, como pide la sección 4.1 del spec:
///
/// ```bash
/// flutter run --dart-define=USE_REMOTE_API=true
/// ```
///
/// **Ninguna capa superior sabe cuál está activa.** Ningún widget importa una
/// implementación concreta: todo pasa por aquí.
@Riverpod(keepAlive: true)
Future<TransitRepository> transitRepository(Ref ref) async {
  if (const bool.fromEnvironment('USE_REMOTE_API')) {
    return const RemoteTransitRepository();
  }

  final MockDataset dataset = await ref.watch(mockDatasetProvider.future);
  final MockTransitRepository repository = MockTransitRepository(
    dataset: dataset,
    config: ref.read(simulatorSettingsProvider),
    clock: ref.watch(clockProvider),
  );

  // Los cambios del panel de debug entran en caliente. Reconstruir el
  // repositorio en cada ajuste teletransportaría la flota a cada toque de un
  // control deslizante.
  ref.listen(simulatorSettingsProvider, (
    SimulatorConfig? previous,
    SimulatorConfig next,
  ) {
    repository.updateConfig(next);
  });

  return repository;
}
