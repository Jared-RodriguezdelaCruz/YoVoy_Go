# Yo Voy Go — Especificación de frontend (v1)

App de transporte público para la zona metropolitana de Aguascalientes.
Cliente Flutter, sin backend propio todavía.

> **Nombre del producto:** Yo Voy Go. Package id `mx.yovoygo.app` en Android e iOS.
> La identidad propia (ícono, tipografía, layout) no imita a la app oficial. Ver §10.

---

## 0. Instrucciones para el agente

Lee este documento completo antes de escribir código. Reglas que no se negocian:

1. **No inventes endpoints ni consumas ninguna API externa.** Todos los datos de v1 salen
   de mocks locales. Si una tarea parece requerir red, es que la estás interpretando mal.
2. **No cambies la forma de los modelos de datos** (§3). Están calcados de GTFS a propósito.
3. Si una decisión no está en este documento, **detente y pregunta**. No improvises
   arquitectura, no agregues paquetes fuera de la lista de §2.
4. Al terminar cada fase de §12, corre `dart analyze` y los tests. Cero warnings.
   Usa `dart analyze`, no `flutter analyze`: `riverpod_lint` usa el sistema nuevo de plugins
   del analizador y solo corre ahí.
5. Verifica en pub.dev la versión actual de cada paquete antes de fijarla en `pubspec.yaml`.
   No copies números de versión de tu memoria.

---

## 1. Objetivo y alcance

### Qué es
Un cliente de transporte público que responde tres preguntas, en este orden de importancia:

1. ¿Dónde viene mi camión y en cuánto llega?
2. ¿Qué rutas pasan por esta parada?
3. ¿Cómo llego de A a B?

### Por qué existe
La app oficial existente falla en lo mismo de lo que se quejan sus usuarios: posiciones
que no se actualizan, trazos de ruta que no cargan, lentitud general. **El objetivo no es
verse mejor, es comportarse mejor cuando los datos son malos** — que es siempre.

### No-objetivos de v1
- Motor de ruteo real (RAPTOR / Connection Scan / OpenTripPlanner). La UI del planificador
  se construye completa; el mock devuelve itinerarios precocinados. Ver §4.3.
- Cualquier integración con la Tarjeta YoVoy: saldo, recargas, movimientos. **Fuera de
  alcance por completo.** No hay pantalla, no hay modelo, no hay mock.
- Cuentas de usuario, login, sincronización en la nube.
- Notificaciones push.
- Web y desktop. Solo Android e iOS.

---

## 2. Stack

| Área | Decisión |
|---|---|
| Framework | Flutter estable, Dart 3 con null-safety estricto |
| Estado | **Riverpod 3 con generación de código** (`@riverpod`) |
| Modelos | `freezed` + `json_serializable` |
| Navegación | `go_router` |
| Mapa | `flutter_map` + tiles vectoriales con `flutter_map_vector_tiles`, sobre OpenFreeMap (esquema OpenMapTiles, sin llave). Estilos propios generados desde los tokens; caché en disco del mismo paquete (§7). *Acordado en la fase 5* |
| Ubicación | `geolocator`, solo permiso "mientras se usa". *Acordado en la fase 5* |
| Persistencia local | `shared_preferences`, detrás de `FavoritesStore`. Guarda listas de ids; no hace falta una base de datos. *Acordado en la fase 6* |
| Geometría | `latlong2` |
| Formato | `intl` + `flutter_localizations` (locale `es_MX`) |
| Tipografía | **Barlow**, **Barlow Semi Condensed** y **Barlow Condensed** empaquetadas en `assets/fonts/` (OFL). Sin paquete adicional |
| Tests | `flutter_test`, `mocktail` |

**Riverpod — advertencia crítica.** La mayor parte del material público de Riverpod es de
v1/v2. Está prohibido en este proyecto:
- `StateNotifier` / `StateNotifierProvider`
- `ChangeNotifierProvider`
- Declarar providers a mano en vez de generarlos

Se usa exclusivamente la sintaxis con anotación `@riverpod` sobre funciones o clases
`Notifier`/`AsyncNotifier`, con `riverpod_generator` + `build_runner`. Si generas código
con la API vieja, está mal aunque compile.

No agregues paquetes que no estén en esta tabla sin preguntar.

---

## 3. Modelo de datos

**Regla dura: los modelos son GTFS.** No inventamos entidades propias. El día que se
consiga el feed oficial, la app no se refactoriza. Nombres de campo en `snake_case` en el
JSON, `camelCase` en Dart, mapeados con `@JsonKey`.

### Estáticas (GTFS)

```dart
Agency   { id, name, url, timezone }
Route    { id, shortName, longName, type, color, textColor }
Trip     { id, routeId, serviceId, headsign, directionId, shapeId }
Stop     { id, code, name, lat, lon, wheelchairBoarding }
StopTime { tripId, stopId, stopSequence, arrivalTime, departureTime }
Shape    { id, points: List<LatLng> }   // shape_pt_sequence ya ordenado
Calendar { serviceId, days: Set<Weekday>, startDate, endDate }
Frequency{ tripId, startTime, endTime, headway, exactTimes }
```

**Enmienda (fase 4a).** `Frequency` no estaba en la lista original y entró al llegar el feed
oficial: el sistema no opera con horarios, opera con intervalos. Es una entidad GTFS de
primera clase —`frequencies.txt`— así que entra por la misma regla que las demás. De ahí
sale el reparto de la flota del simulador y el respaldo "pasa cada 20 min" cuando ningún
vehículo está reportando.

### Tiempo real (GTFS-Realtime)

```dart
VehiclePosition {
  vehicleId, tripId, routeId,
  position: LatLng,
  bearing: double?,          // grados, 0 = norte. Puede faltar.
  speed: double?,
  timestamp: DateTime,       // cuándo reportó el vehículo, NO cuándo lo recibimos
  occupancyStatus: OccupancyStatus?,
  currentStopSequence: int?,
}

StopTimeUpdate { tripId, stopId, stopSequence, arrivalDelay, predictedArrival }

ServiceAlert { id, affectedRouteIds, affectedStopIds, cause, effect, header, description, activePeriod }
```

### Derivadas (solo presentación)

```dart
Arrival {
  routeId, routeShortName, headsign,
  eta: Duration?,            // null = desconocido, es un estado válido y frecuente
  confidence: EtaConfidence, // live | scheduled | unknown
  vehicleId?,
  dataAge: Duration,         // now - timestamp del vehículo
}

enum EtaConfidence { live, scheduled, unknown }
```

**`EtaConfidence` y `dataAge` no son opcionales ni cosméticos.** Son el corazón de la
propuesta de valor: la app dice qué tan confiable es lo que muestra. Todo componente que
pinte un ETA debe recibir ambos.

Reglas de degradación (constantes en `core/config/freshness.dart`):

| `dataAge` | Estado | Presentación |
|---|---|---|
| < 60 s | `live` | Valor + indicador de pulso |
| 60–180 s | `stale` | Valor + "hace X min" en el chip |
| > 180 s | `unknown` | **No mostrar ETA numérico.** Mostrar horario programado o "sin señal" |

Nunca mostrar un ETA numérico calculado a partir de una posición de más de 3 minutos.
Un número inventado es peor que un "no sé".

---

## 4. Capa de datos

### 4.1 Contrato

```dart
abstract interface class TransitRepository {
  Future<TransitNetwork> getNetwork();
  Future<List<Route>> getRoutes();
  Future<Route> getRoute(String routeId);
  Future<Shape> getShape(String shapeId);
  Future<List<Stop>> getStopsNear(LatLng center, {double radiusMeters});
  Future<List<Stop>> getStopsForRoute(String routeId);
  Future<List<Arrival>> getArrivals(String stopId);
  Stream<List<VehiclePosition>> watchVehicles({String? routeId});
  Stream<List<ServiceAlert>> watchAlerts();
  Future<List<Itinerary>> planTrip({required LatLng from, required LatLng to, DateTime? departAt});
}
```

**`getNetwork()` se agregó en la fase 5.** Devuelve la red estática completa —rutas, viajes,
trazos, paradas y qué paradas recorre cada viaje— en una sola llamada. El mapa necesita los 92
trazos de golpe; pedirlos uno por uno multiplicaría la latencia y las fallas simuladas por cada
trazo. En GTFS la parte estática se descarga de una vez, en un solo zip, así que pedirla entera
es lo que hará también el repositorio real.

Dos implementaciones: `MockTransitRepository` y `RemoteTransitRepository`.

`RemoteTransitRepository` se crea en v1 **como esqueleto con `UnimplementedError` en cada
método** y un comentario `// TODO(api):` indicando qué endpoint GTFS-RT lo alimentaría.
Existe para que la forma del código ya contemple su llegada. No se implementa.

Selección por flag de compilación:

```dart
@riverpod
TransitRepository transitRepository(Ref ref) =>
    const bool.fromEnvironment('USE_REMOTE_API')
        ? RemoteTransitRepository(...)
        : MockTransitRepository(...);
```

Ninguna capa superior sabe cuál está activa. Ningún widget importa una implementación
concreta.

### 4.2 El simulador — la parte importante

`MockTransitRepository` lee JSON de `assets/mock/` y **simula un sistema de transporte
real, con sus fallas**. Un mock de datos perfectos hace que diseñes una UI que se rompe en
producción. Configurable desde una pantalla de debug:

- **Movimiento:** cada vehículo avanza interpolado sobre los puntos de su `shape` a
  velocidad variable (20–40 km/h), con paradas de 15–30 s en cada `Stop`.
- **Cadencia de reporte:** posiciones nuevas cada **30 s**, no cada frame. Es la cadencia
  real. La UI debe interpolar visualmente entre reportes (§7).
- **Ruido GPS:** desplazamiento aleatorio de 5–20 m perpendicular al trazo.
- **Pérdida de señal:** ~10% de los vehículos desaparece 1–3 minutos y reaparece adelantado
  en la ruta.
- **`bearing` ausente:** en ~15% de los reportes viene `null`.
- **Latencia de red:** todos los `Future` con retraso aleatorio de 200–1500 ms.
- **Errores:** ~5% de las llamadas lanza excepción.
- **Rutas sin servicio:** al menos una ruta del dataset sin ningún vehículo activo.

**Dataset (enmendado en la fase 4a).** Ya no se traza a mano. `assets/mock/` se genera con
`tool/gtfs_to_mock.py` a partir del **GTFS estático oficial** del transporte concesionado de
Aguascalientes, que publica el Gobierno del Estado (CMOV) y distribuye el Hub de Datos de
Transporte Público de Codeando México bajo **CC BY-SA 4.0**:

- 48 rutas con su `route_color` real, 1 507 paradas, 92 trazos del operador (41 252 puntos).
- Servicio por frecuencia, no por horarios: un intervalo por ruta.
- 323 vehículos repartidos con `ceil(vuelta ÷ intervalo)`, y dos rutas sin servicio a propósito.
- 2 alertas de servicio y 4 pares de itinerarios, escritos a mano sobre ids reales.

Lo que el feed no publica —código de parada, accesibilidad, alertas, itinerarios, tarifa— se
simula con semilla fija y queda declarado campo por campo en `assets/mock/DATASET.md`. Que el
dataset alimente un simulador no es excusa para que un dato inventado parezca oficial.

### 4.3 Planificador

`planTrip` en el mock hace matching por proximidad contra 4 pares origen-destino
precocinados en `assets/mock/itineraries.json`, cubriendo: viaje directo, viaje con un
transbordo, viaje con dos transbordos, y **caso sin resultados**.

Si el origen o destino no cae cerca de ninguno de los pares, devuelve lista vacía. La
pantalla de resultados vacíos es tan importante como la de resultados.

```dart
Itinerary { legs: List<Leg>, totalDuration, walkingDistance, transferCount, fare? }
Leg       { type: walk|bus, from, to, route?, duration, geometry: List<LatLng> }
```

---

## 5. Arquitectura

Feature-first. Tres capas por feature, dependencias solo hacia adentro.

```
lib/
  main.dart                 ProviderScope + YoVoyGoApp, sin lógica
  app/                      app.dart · router.dart · routes.dart (nombres y paths)
  core/
    models/                 modelos GTFS compartidos (freezed)
    data/
      transit_repository.dart
      mock/                 MockTransitRepository + simulador
      remote/               RemoteTransitRepository (esqueleto)
    config/                 constantes, umbrales de frescura
    utils/
  design/                   § 6 — design system
    tokens/                 colors, typography, spacing, motion, elevation
    components/             widgets compartidos
    theme.dart
  features/
    map/                    data/ · application/ · presentation/
    stop/
    route/
    planner/
    favorites/
    settings/
```

- `presentation/` — widgets. **Sin lógica de negocio, sin cálculos, sin acceso a repos.**
- `application/` — providers Riverpod, casos de uso, transformación a modelos de vista.
- `data/` — solo si la feature tiene fuentes propias (ej. favoritos en almacenamiento local).

Un widget que llama `ref.read(transitRepositoryProvider)` directamente es un bug de
arquitectura. Siempre a través de un provider de `application/`.

### Convenciones Riverpod

- Todo lo async expone `AsyncValue`. **Prohibido** un `isLoading` booleano manual.
- Todo provider con polling o stream lleva `autoDispose` (es el default en la sintaxis
  generada — no lo desactives). Salir de una pantalla **debe** apagar su suscripción.
  Esto es batería y datos móviles del usuario, no un detalle.
- Parametrizar con `family`, nunca con estado global mutable.
- `ref.watch` en `build`, `ref.read` en callbacks. Sin excepciones.
- Tests: `ProviderContainer` con `overrides` inyectando repos falsos.

---

## 6. Design system

### 6.1 Dirección

**Señalética de transporte sobre base Material 3.** Material 3 aporta la infraestructura
(accesibilidad, tamaños de toque, componentes, temas). La capa visual viene del lenguaje
de la señalética de transporte: color plano, jerarquía por peso y tamaño, la línea de ruta
como el elemento gráfico protagonista.

Tres principios:

1. **La ruta es el héroe.** El trazo de color es el objeto visual más importante de la app,
   no un adorno sobre el mapa. Grueso, saturado, con halo de contraste.
2. **La expresividad se gasta en el tiempo real.** Springs, pulsos y morfeo solo en el
   marcador del vehículo y el contador de ETA. Todo lo demás está quieto. Motion en cada
   card y cada transición es el default genérico y además cuesta frames.
3. **Legible a mediodía en un paradero.** Contraste alto siempre. Nada de traslucidez
   decorativa, nada de texto sobre fotografía, nada de `BackdropFilter` (§7).

### 6.2 Color

**El color institucional es índigo, no verde.** Extraído con cuentagotas el 20 de septiembre
de 2026 del splash y el ícono de la app oficial (`com.mx.nrtec.agsstopbus`) y de la fotografía
oficial de la Tarjeta Soluciones YoVoy: `#3A3578`, dominante en las tres fuentes. Las versiones
anteriores de este documento afirmaban que el sistema era verde y fijaban un `#00854A` que nadie
había medido; era falso, y además daba 3.95:1 contra la superficie oscura, por debajo del piso de
la sección 11.

Dos hex por token y por tema, como ya hacían los semánticos: el índigo institucional es oscuro y
sobre fondo negro no se lee.

```
brand           #3A3578   tema claro  — el índigo institucional, tal cual
brand           #8179DC   tema oscuro — el mismo índigo aclarado hasta pasar 4.5:1

cantera         #8A4B32   tema claro  — SOLO lo que el teléfono aprendió de ti
cantera         #E0A98F   tema oscuro

surface         #0E1016   base neutra oscura con tinte índigo frío
surfaceRaised   #171A24
surfaceSunken   #080910
outline         #2A2E3D
textPrimary     #F2F3F7
textSecondary   #A2A7BD
lumen           blanco al 4 % — el tinte del gradiente de superficie (§6.4)
```

**Regla de `cantera`: el índigo es del sistema, lo cálido es tuyo.** El índigo y los cuatro
semánticos son la voz del sistema —dónde viene el camión, qué tan fresco es el dato—. `cantera`,
el rosa de la piedra con la que está construida Aguascalientes, marca únicamente lo que el
teléfono aprendió del usuario: favoritos, rutas de siempre, "sal en 6 min". El color dice de
quién es el dato, y eso es información, no decoración.

`cantera` y `stale` son los dos cálidos del sistema y los separan 26° de tono. **Regla dura:
`cantera` jamás aparece en la misma fila que un estado de frescura.**

Semánticos de tiempo real (**no reutilizan el índigo de marca**):

```
live            #3DDC84   dato fresco, < 60 s
stale           #F2B705   dato viejo, 60–180 s
unknown         #7A8A82   sin dato
alert           #E5484D   alerta de servicio
```

**Regla: un color, un significado.** El índigo de marca identifica a la app y marca acciones
primarias. **No** significa "camión llegando". Si el mismo color es marca y estado, el
usuario no puede leer estado.

Color de ruta: viene de `Route.color` (campo GTFS). Cuando falte, generarlo determinísticamente
desde el `routeId` con un hash contra una paleta curada de 12 tonos suficientemente
distinguibles entre sí y todos con contraste ≥ 4.5:1 contra `surface`. La misma ruta debe
tener siempre el mismo color entre sesiones.

Tema claro: obligatorio, el mapa de día se usa más. Mismos tokens semánticos, valores
invertidos. El tema oscuro es el default de la app.

### 6.3 Tipografía

Una sola familia, tres anchos. **Barlow** — grotesca de linaje señalético, contrapunto
industrial, excelente en tamaños chicos, con dos anchos estrechos disponibles.

- `Barlow Condensed` — **solo el contador de minutos**, con tracking de −2 %. Condensada y
  apretada se lee como instrumento de tablero y no como texto grande, que es justo la
  diferencia entre un dato y una decoración.
- `Barlow Semi Condensed` — números, códigos de ruta, datos densos.
- `Barlow` — texto corrido, etiquetas, botones.

Escala (razón 1.25, sentence case en todo):

| Rol | Tamaño / peso | Uso |
|---|---|---|
| `etaDisplay` | 48 / 700 condensada, tracking −2 % | El número grande de minutos |
| `routeBadge` | 20 / 700 semi-cond. | Código de ruta en su placa |
| `title` | 22 / 600 | Nombre de parada, encabezado de hoja |
| `body` | 16 / 400 | Texto general |
| `label` | 14 / 500 | Etiquetas de control |
| `caption` | 13 / 400 | Metadatos, frescura del dato |

Prohibido: versalitas / ALL CAPS para etiquetas, resaltar una sola palabra del encabezado
con otro color, poner etiquetas tipográficas decorativas sobre los bloques de contenido.

Números de ruta y ETAs con `FontFeature.tabularFigures()`. Un contador que cambia de ancho
al pasar de 9 a 10 se ve barato y salta.

### 6.4 Espaciado y forma

Escala de 4: `4 8 12 16 24 32 48`. Nada intermedio.

Radios con jerarquía, no uno solo para todo:
- `0` — placas de ruta (la señalética no redondea)
- `8` — chips, botones
- `16` — cards
- `28` — hoja inferior (solo esquinas superiores)

Sombras: ninguna. La jerarquía se resuelve con superficie y borde (`outline`, 1px). En tema
oscuro, la sombra gris genérica no comunica nada y cuesta render.

**Pero prohibir la sombra no obliga a que todo sea plano.** Las superficies elevadas se
iluminan: un gradiente vertical de 4 % que baja desde el borde superior y un filo de 1px un
punto más claro que la superficie. Un panel encendido, una lámpara en un cuarto. Cuesta un
`LinearGradient`: cero `saveLayer`, cero `BackdropFilter`, nada de lo que prohíbe la §7.

Los radios no se mueven. La placa de ruta sigue en `0` porque la señalética no redondea, y esa
es la herencia directa de las unidades.

### 6.5 Motion

- Estándar: 200 ms, `Curves.easeOutCubic`. Para todo.
- Vehículo: interpolación lineal continua a lo largo de 30 s (§7).
- ETA: el número cambia con `AnimatedSwitcher` + slide vertical de 150 ms. Único lugar con
  motion no disparado por el usuario.
- Indicador `live`: pulso de opacidad, 2 s, infinito. **Uno solo por pantalla**, en el chip
  de frescura global — no uno por cada fila de la lista.
- Respetar `MediaQuery.disableAnimations`: si está activo, todo lo anterior se vuelve
  transición instantánea.

### 6.6 Componentes compartidos

Construir en `design/components/` antes que cualquier pantalla:

- `RouteBadge` — placa rectangular con el color de la ruta. Ajusta el color de texto por
  luminancia. Tres tamaños.
- `EtaChip` — recibe `Duration?` + `EtaConfidence` + `dataAge`. **Renderiza el estado
  desconocido igual de bien que el conocido.** Este es el componente más importante de la app.
- `FreshnessIndicator` — traduce `dataAge` a lenguaje humano ("en vivo", "hace 2 min",
  "sin señal").
- `StopTile` — parada + lista de próximos arribos.
- `RouteLine` — polilínea con halo, ancho por nivel de zoom.
- `VehicleMarker` — ícono direccional; degrada a círculo sin dirección cuando `bearing` es null.
- `EmptyState` — ícono, qué pasó, qué hacer. Nunca solo "No hay datos".
- `ErrorState` — qué falló, botón de reintentar.
- `LitSurface` — el panel encendido de §6.4. Sustituye a la sombra prohibida.
- `RouteStrip` — **la firma de la app**. La línea de ruta con las paradas como marcas y el
  vehículo como frontera: lo recorrido en `cantera`, lo que falta en el índigo de marca, el
  vehículo con halo. Cuando el dato vence la luz se apaga —sin halo, el índigo se vuelve gris,
  el trazo se puntea— y el texto se queda, porque el color nunca carga el significado solo.

---

## 7. Mapa y rendimiento

El dispositivo objetivo es un Android de gama media-baja. Presupuesto: **60 fps con 40
vehículos visibles**, y nunca por debajo de 30.

Reglas:

1. **Prohibido `BackdropFilter` / `ImageFilter.blur` sobre el mapa.** Cada instancia fuerza
   un `saveLayer` por frame. Con un mapa repintando debajo es el peor caso posible de la
   GPU. La hoja inferior usa superficie sólida con gradiente sutil.
2. **Interpolar posiciones.** El feed llega cada 30 s. Un marcador que teletransporta se ve
   peor que la app original. Cada `VehicleMarker` anima linealmente de la posición anterior
   a la nueva a lo largo de la ventana de 30 s, con un solo `Ticker` compartido para todos
   los marcadores — no un `AnimationController` por vehículo.
3. **Clustering** arriba de 30 marcadores visibles.
4. **Filtrar por viewport** antes de construir marcadores. No construir widgets fuera de
   pantalla.
5. **Simplificar shapes** con Douglas-Peucker según el zoom. Un trazo completo tiene miles
   de puntos; a zoom bajo no se distinguen.
6. `RepaintBoundary` alrededor de la capa de marcadores.
7. **Tiles cacheadas en disco.** El usuario está en la calle con datos limitados.
8. Pausar todo polling cuando la app pasa a background (`AppLifecycleState`).

Tema de mapa oscuro por defecto, personalizado: calles desaturadas, POIs ocultos, etiquetas
al mínimo. El mapa es fondo; las rutas son el contenido. Un mapa con toda su información
compite con el trazo de ruta y gana.

---

## 8. Pantallas

### 8.1 Mapa (inicio)

Mapa a pantalla completa, hoja inferior arrastrable en tres posiciones (colapsada 120px /
media 45% / expandida 90%).

- Colapsada: paradas cercanas con sus próximos arribos.
- Barra de búsqueda flotante arriba, con `SafeArea`.
- FAB de ubicación abajo a la derecha, sobre la hoja.
- Chip de frescura global arriba, visible siempre: "En vivo" / "Hace 2 min" / "Sin señal".
- Tocar una parada → la hoja pasa a media con el detalle de esa parada.
- Tocar un vehículo → callout con ruta, destino y próxima parada.

### 8.2 Detalle de parada

Nombre y código, lista de arribos ordenada por ETA. Cada fila: `RouteBadge`, destino,
`EtaChip`. Botón de favorito. Pull-to-refresh. Alertas de servicio activas arriba, si las hay.

### 8.3 Detalle de ruta

Trazo completo en mapa arriba, lista de paradas en secuencia abajo, con la posición de los
vehículos activos marcada entre paradas. Selector de sentido (ida/vuelta). Si la ruta no
tiene vehículos activos, decirlo explícitamente — no mostrar una lista vacía.

### 8.4 Planificador

Formulario origen/destino (con "mi ubicación" y búsqueda), selector de hora de salida,
lista de itinerarios resultantes. Cada resultado: duración total, número de transbordos,
placas de las rutas en secuencia, distancia a pie.

Detalle de itinerario: timeline vertical con tramos de caminata y de camión, mapa con la
geometría completa.

**Debe existir un estado de "no encontré ruta" con salida útil** (sugerir destino cercano,
o mostrar las rutas que sí pasan cerca del origen).

### 8.5 Favoritos

Paradas y rutas guardadas, persistidas localmente (`shared_preferences` o `drift` — elige
y justifica). **Elegido en la fase 6: `shared_preferences`**, porque lo que se guarda son listas
de ids. Los favoritos de parada muestran ETA en vivo directamente en la lista.

### 8.6 Ajustes

Tema (claro/oscuro/sistema), reducir animaciones, tamaño de texto, limpiar caché, acerca de.
En build de debug: panel de control del simulador (§4.2).

---

## 9. Estados obligatorios

Cada pantalla que consuma datos implementa **los cuatro**, con diseño explícito. Ninguno se
resuelve con un spinner centrado:

| Estado | Tratamiento |
|---|---|
| Cargando | Skeleton con la forma del contenido real, no `CircularProgressIndicator` |
| Vacío | Qué pasó y qué puede hacer el usuario |
| Error | Qué falló, en lenguaje del usuario, con reintentar |
| **Dato viejo** | Contenido visible + advertencia de frescura. **No** vaciar la pantalla |

El cuarto es el que distingue esta app. Cuando el dato envejece, no se borra: se marca. El
usuario decide si le sirve.

Copy: verbos activos, sentence case, sin disculpas. "Sin señal de esta ruta" y no "Lo
sentimos, no fue posible obtener la información en este momento".

---

## 10. Marca y legal

- El producto se llama **Yo Voy Go**; el package id es `mx.yovoygo.app`. Decisión tomada a
  conciencia: el nombre evoca al sistema de transporte y se asume ese riesgo de marca.
- No usar "StopBus" ni el nombre de la app oficial en textos o metadatos de tienda.
- No imitar el ícono ni la identidad de la app oficial.
- Pantalla "Acerca de" con aviso: app independiente, sin afiliación con CMOV ni con el
  operador del sistema.
- **El índigo `#3A3578` se conserva porque es el color del sistema de transporte** y da
  reconocimiento inmediato. Está extraído con cuentagotas de la app oficial y de la Tarjeta
  Soluciones YoVoy (§6.2), no inventado. La identidad (nombre, ícono, tipografía, layout) es
  propia.
- **Los acentos neón del wordmark oficial** —cian `#10AFE6`, lima `#BDD52F`, magenta `#EC3B94`,
  amarillo `#FFD200`— se descartan a propósito: adoptarlos acercaría la app a imitar la
  identidad oficial, y el lima compite con los colores de estado.
- **Atribución de los datos (enmienda de la fase 4a).** La pantalla "Acerca de" y
  `assets/mock/LICENSE.txt` llevan: *Datos de transporte: Gobierno del Estado de
  Aguascalientes (CMOV), vía el Hub de Datos de Transporte Público de Codeando México.
  CC BY-SA 4.0.* CompartirIgual alcanza al dataset derivado, no al código. Atribuir una
  fuente no es afiliarse a ella: el aviso de app independiente se queda tal cual.

---

## 11. Accesibilidad

Piso no negociable:

- Contraste ≥ 4.5:1 en texto, ≥ 3:1 en elementos gráficos, en ambos temas.
- Área de toque ≥ 48×48 dp.
- `Semantics` en todo control. Los ETAs se anuncian como "ruta 20, llega en 4 minutos,
  dato en vivo".
- Respetar el tamaño de texto del sistema hasta 200%. Ningún layout se rompe.
- Respetar reducción de movimiento.
- **El color nunca es el único portador de significado.** El estado de frescura lleva texto
  e ícono además del color — hay daltonismo, y hay sol directo.

---

## 12. Orden de implementación

Una fase por PR. No empieces la siguiente sin cerrar la anterior.

1. **Base** — proyecto, `pubspec`, análisis estricto, estructura de carpetas, `go_router`
   con rutas vacías.
2. **Modelos** — entidades GTFS con freezed + serialización. Tests de round-trip JSON.
3. **Design system** — tokens, tema claro y oscuro, todos los componentes de §6.6, y una
   pantalla de galería en debug que los muestre en todos sus estados.
4. **Mock** — dataset en assets, `MockTransitRepository`, simulador completo con sus fallas,
   panel de control de debug.
5. **Mapa** — mapa, capa de rutas, marcadores interpolados, hoja inferior. Medir fps.
6. **Parada y ruta** — pantallas 8.2 y 8.3.
7. **Planificador** — 8.4 con itinerarios mock.
8. **Favoritos y ajustes** — 8.5 y 8.6.
9. **Pulido** — auditoría de accesibilidad, perfilado de rendimiento, los cuatro estados
   revisados pantalla por pantalla.

---

## 13. Definición de terminado

Una feature está lista cuando:

- [ ] `dart analyze` limpio (incluye `riverpod_lint`).
- [ ] Los cuatro estados de §9 implementados y verificables desde el panel de debug.
- [ ] Funciona con el simulador en su configuración más hostil (latencia alta, 20% de error,
      pérdida de señal frecuente).
- [ ] Sin regresión de fps en el mapa.
- [ ] Contraste y tamaños de toque verificados en ambos temas.
- [ ] Legible con texto del sistema al 200%.
- [ ] Tests de providers con repositorio falso inyectado por override.
- [ ] Cero referencias a implementaciones concretas de repositorio fuera de `core/data/`.
