/// Umbrales de frescura del dato de tiempo real.
///
/// Como en la sección 3 del spec (modelo de datos): la app nunca muestra un ETA
/// numérico calculado a partir de una posición de más de 3 minutos. Un número
/// inventado es peor que un "no sé".
library;

/// Clasificación de presentación para la edad de un dato de tiempo real.
///
/// No confundir con `EtaConfidence` (modelo, fase 2), que describe el *origen*
/// del dato (en vivo, programado, desconocido). Esto describe su *edad*.
enum DataFreshness {
  /// Menos de [Freshness.liveMax]: valor + indicador de pulso.
  live,

  /// Entre [Freshness.liveMax] y [Freshness.staleMax]: valor + "hace X min".
  stale,

  /// Más de [Freshness.staleMax]: sin ETA numérico.
  unknown,
}

/// Constantes y reglas de degradación por frescura.
abstract final class Freshness {
  /// Debajo de este valor el dato es [DataFreshness.live].
  static const Duration liveMax = Duration(seconds: 60);

  /// Encima de este valor el dato es [DataFreshness.unknown].
  static const Duration staleMax = Duration(seconds: 180);

  /// Traduce la edad de un dato a su estado de presentación.
  ///
  /// Fronteras según la tabla de la sección 3 del spec: `< 60 s` en vivo,
  /// `60–180 s` viejo, `> 180 s` desconocido.
  static DataFreshness classify(Duration dataAge) {
    if (dataAge < liveMax) {
      return DataFreshness.live;
    }
    if (dataAge <= staleMax) {
      return DataFreshness.stale;
    }
    return DataFreshness.unknown;
  }

  /// Si es `false`, la UI muestra horario programado o "sin señal", nunca un
  /// ETA en minutos.
  static bool allowsNumericEta(DataFreshness freshness) =>
      freshness != DataFreshness.unknown;
}
