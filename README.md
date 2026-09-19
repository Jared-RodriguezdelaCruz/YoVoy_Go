# Yo Voy Go

Aplicación de transporte público para la zona metropolitana de Aguascalientes.

Yo Voy Go responde tres preguntas:

1. ¿Dónde viene mi camión y en cuánto llega?
2. ¿Qué rutas pasan por esta parada?
3. ¿Cómo llego de A a B?

A diferencia de otras aplicaciones de transporte, el objetivo principal no es verse mejor, sino comportarse mejor cuando los datos son incompletos, retrasados o incorrectos.

---

## Estado del proyecto

🚧 En desarrollo

Actualmente se encuentra en la implementación de la v1 utilizando datos simulados mediante un repositorio local (`MockTransitRepository`).

No existe integración con APIs externas ni servicios oficiales.

---

## Principios del proyecto

### El tiempo real debe ser honesto

La aplicación nunca muestra ETAs inventados.

Cuando la información pierde frescura:

- Menos de 60 segundos → dato en vivo.
- Entre 60 y 180 segundos → dato viejo.
- Más de 180 segundos → sin señal.

Si la aplicación no puede estimar una llegada de forma confiable, lo indica explícitamente.

---

### Diseñada para datos imperfectos

El simulador incorpora condiciones reales:

- Latencia de red.
- Errores aleatorios.
- Pérdida temporal de vehículos.
- Posiciones GPS con ruido.
- Reportes incompletos.
- Rutas sin servicio.

La interfaz debe seguir siendo útil incluso bajo estas condiciones.

---

### Arquitectura preparada para GTFS

Los modelos replican GTFS y GTFS-Realtime para minimizar cambios cuando exista acceso a una fuente oficial.

---

## Stack tecnológico

- Flutter
- Dart 3
- Riverpod 3
- Freezed
- Json Serializable
- Go Router
- Flutter Map
- LatLong2
- Intl
- Mocktail

---

## Arquitectura

```text
lib/
  app/
  core/
    models/
    data/
      mock/
      remote/
    config/
    utils/
  design/
    tokens/
    components/
  features/
    map/
    stop/
    route/
    planner/
    favorites/
    settings/
```

La arquitectura sigue una estructura feature-first.

Cada feature se divide en:

- application
- presentation
- data (cuando aplica)

Las dependencias siempre apuntan hacia adentro.

---

## Capas de datos

### MockTransitRepository

Implementación principal de desarrollo.

Lee datos desde:

```text
assets/mock/
```

y simula un sistema de transporte real.

### RemoteTransitRepository

Esqueleto preparado para futura integración con:

- GTFS Static
- GTFS Realtime

Actualmente todos los métodos lanzan:

```dart
UnimplementedError()
```

---

## Funcionalidades planeadas

### Mapa

- Vehículos en tiempo real.
- Paradas cercanas.
- Hoja inferior expandible.
- Indicador global de frescura.

### Paradas

- Próximos arribos.
- Alertas de servicio.
- Favoritos.

### Rutas

- Trazo completo.
- Vehículos activos.
- Sentido de recorrido.

### Planificador

- Origen y destino.
- Itinerarios simulados.
- Transbordos.
- Casos sin resultados.

### Favoritos

- Rutas favoritas.
- Paradas favoritas.
- Persistencia local.

### Ajustes

- Claro / oscuro.
- Reducir animaciones.
- Tamaño de texto.
- Panel de simulación para debug.

---

## Ejecución

Instalar dependencias:

```bash
flutter pub get
```

Generar código:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Ejecutar:

```bash
flutter run
```

---

## Calidad

Antes de integrar cambios:

```bash
flutter analyze
flutter test
```

No se aceptan warnings en análisis estático.

---

## Accesibilidad

Objetivos mínimos:

- Contraste AA.
- Área táctil mínima de 48x48 dp.
- Compatibilidad con tamaño de texto hasta 200%.
- Soporte