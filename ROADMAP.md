# Roadmap — Yo Voy Go

Plan de construcción de la v1. El **qué** y el **por qué** viven en
[`YOVOY_GO_SPEC.md`](YOVOY_GO_SPEC.md); aquí está el **en qué orden** y el **cuándo se da por
terminado**. Las features propuestas encima del spec, con su justificación, están en
[`FEATURES.md`](FEATURES.md).

**Estado:** fases 1 a 8 cerradas, más el repintado de la marca. Siguiente: fase 9, pulido.
Pendiente heredado: medir los fps en un teléfono real de gama media-baja.

La dirección visual completa —de dónde salió cada color, la regla que los organiza y la firma de la
app— vive en [`DESIGN.md`](DESIGN.md).

Regla de trabajo: **una fase por PR, y no se empieza la siguiente sin cerrar la anterior.** Las
fases 1 a 9 son las de la sección 12 del spec. Los hitos marcados como **(extra)** no están en el
spec, pero sin ellos la app no es entregable.

---

## Progreso

| # | Fase | Depende de | Estado |
|---|---|---|---|
| 1 | Base: proyecto, dependencias, análisis estricto, estructura, router | — | ✅ cerrada |
| 2 | Modelos GTFS | 1 | ✅ cerrada |
| — | **(extra)** Integración continua | 2 | ⏳ |
| 3 | Design system | 2 | ✅ cerrada |
| — | **(extra)** Identidad visual: ícono y splash | 3 | ⏳ |
| 4a | Dataset del simulador | 2 | ✅ cerrada |
| 4b | `MockTransitRepository` y simulador | 2, 4a | ✅ cerrada |
| 5 | Mapa | 3, 4b | ✅ cerrada · fps en hardware pendiente |
| 6 | Parada y ruta | 5 | ✅ cerrada |
| 7 | Planificador | 6 | ✅ cerrada |
| 8 | Favoritos y ajustes | 6 | ✅ cerrada |
| 9 | Pulido: accesibilidad, rendimiento, los cuatro estados | 7, 8 | ⏳ siguiente |
| — | **(extra)** Build de release firmado | 9 | ⏳ |

Las fases 3 y 4 pueden avanzar en paralelo: ambas solo necesitan los modelos de la fase 2. La 4a
estaba marcada como la tarea más larga del proyecto porque suponía trazar las rutas a mano; dejó de
serlo cuando apareció el GTFS oficial.

---

## Cómo se cierra una fase

Checklist reutilizable, tomado de la definición de terminado de la sección 13 del spec. Se pega en
el PR y se marca punto por punto:

- [ ] `dart analyze` limpio, incluidas las reglas de `riverpod_lint`.
- [ ] `flutter test` en verde, con tests de providers que inyectan un repositorio falso por
      `override`.
- [ ] Los cuatro estados de la sección 9 del spec implementados y verificables desde el panel de
      debug: cargando, vacío, error y **dato viejo**.
- [ ] Funciona con el simulador en su configuración más hostil: latencia alta, 20 % de error,
      pérdida de señal frecuente.
- [ ] Sin regresión de fps en el mapa.
- [ ] Contraste y tamaños de toque verificados en tema claro y oscuro.
- [ ] Legible con el texto del sistema al 200 %.
- [ ] Cero referencias a implementaciones concretas de repositorio fuera de `lib/core/data/`.

Los tres últimos no aplican hasta que exista mapa (fase 5) o design system (fase 3); mientras
tanto se marcan como no aplicables, no se omiten.

---

## Fase 1 — Base ✅

**Objetivo.** Un proyecto que compila, con el toolchain de generación de código probado y
documentación que corresponde a la realidad.

**Entregado.** `pubspec.yaml` con el stack de la sección 2 del spec y versiones verificadas en
pub.dev · `analysis_options.yaml` estricto con `riverpod_lint` · estructura feature-first de la
sección 5 · [`lib/app/router.dart`](lib/app/router.dart) con las seis rutas y pantalla de error
propia · [`lib/core/config/freshness.dart`](lib/core/config/freshness.dart) con los umbrales de
frescura · Barlow empaquetada en `assets/fonts/` · `applicationId` `mx.yovoygo.app` · README
reescrito.

**Verificado.** `dart analyze` en cero, 11 tests en verde, `flutter build apk --debug` con
`package: name='mx.yovoygo.app'` y `application-label: 'Yo Voy Go'`.

**Pendiente heredado.** Corre en emulador (Pixel 8, API 36) desde el 20 de septiembre de 2026.
Falta hardware real: un emulador no dice nada sobre fps ni sobre legibilidad con sol en la cara.

---

## Fase 2 — Modelos GTFS ✅

**Objetivo.** Las entidades de datos, calcadas de GTFS, para que el día que llegue el feed oficial
la app no se refactorice.

**Entregado.** `lib/core/models/` con un archivo por entidad y
[`models.dart`](lib/core/models/models.dart) como único import · `converters/` con los cuatro
converters · `test/core/models/` con el round-trip de cada modelo.

**Tareas**

- [x] Estáticas: `Agency`, `TransitRoute`, `Trip`, `Stop`, `StopTime`, `Shape`, `Calendar`.
- [x] Tiempo real: `VehiclePosition`, `StopTimeUpdate`, `ServiceAlert` (con `ActivePeriod`).
- [x] Derivadas de presentación: `Arrival`, `Itinerary`, `Leg`.
- [x] Enums: `EtaConfidence`, `OccupancyStatus`, `Weekday`, `LegType`, más
      `WheelchairBoarding`, `AlertCause` y `AlertEffect`.
- [x] `snake_case` en el JSON y `camelCase` en Dart, mapeado con `@JsonKey`.
- [x] Converters propios: `LatLng` ↔ `{lat, lon}`, `Duration` en segundos, `DateTime` en epoch,
      fecha `YYYYMMDD` y las horas de GTFS, que admiten `25:30:00`.
- [x] `EtaConfidence` (origen del dato) y `DataFreshness` (edad del dato) siguen siendo ejes
      distintos. `Arrival` carga los dos y expone `showsNumericEta`, que es donde vive la regla.
- [x] Round-trip JSON por modelo, con los campos que faltan en la vida real: `bearing` nulo, `eta`
      nula, `color` ausente, `shape` sin puntos.

**Cierre.** `dart analyze` en cero y 59 tests en verde al terminar la fase.

**Tres decisiones que quedaron tomadas**

1. **La clase se llama `TransitRoute`, no `Route`.** `Route<T>` ya existe en `flutter/material.dart`
   y un modelo con ese nombre obligaría a escribir `hide Route` en cada archivo de UI. El JSON
   sigue siendo GTFS literal, que es lo que protege la regla de la sección 3 del spec.
2. **`build.yaml` con `explicit_to_json: true`.** Sin eso, `toJson()` de un itinerario devuelve los
   tramos como objetos Dart en vez de mapas, y el round-trip solo funciona si pasa por
   `jsonEncode`. Lo encontró el test del itinerario, no una revisión a ojo.
3. **Las horas de GTFS son `Duration`, no `DateTime`.** `25:30:00` es válido y significa la 1:30 de
   la madrugada del mismo día de servicio.

---

## (extra) Integración continua

**Objetivo.** Que romper el análisis o los tests se note antes de llegar a `main`.

**Entrega.** `.github/workflows/ci.yml`.

**Tareas**

- [ ] Workflow en push y pull request: `flutter pub get` → `dart run build_runner build` →
      `dart analyze` → `flutter test`.
- [ ] El paso de `build_runner` no es opcional: el código generado no está versionado, así que sin
      él la CI ni siquiera compila.
- [ ] Caché de pub para que no tarde una eternidad.
- [ ] Opcional: `flutter build apk --debug` como último paso.

**Cierre.** Un PR con un error de análisis a propósito sale en rojo.

---

## Fase 3 — Design system ✅

**Objetivo.** Señalética de transporte sobre Material 3. La línea de ruta es el objeto gráfico
protagonista y la expresividad se gasta solo en el tiempo real.

**Entregado.** `lib/design/tokens/` (color, tipografía, espaciado, motion, paleta de rutas y
contraste) · [`lib/design/theme.dart`](lib/design/theme.dart) · `lib/design/components/` con los
ocho componentes · galería en `/debug/gallery` · cuatro imágenes de referencia en
`test/design/goldens/`.

**Tareas**

- [x] Tokens de superficie, contorno y texto, más los semánticos de tiempo real, que **no**
      reutilizan el color de marca. Verificado por test en los dos temas.
- [x] Paleta de doce tonos para rutas sin `color`, asignada con un FNV-1a determinista desde el
      `routeId` —`String.hashCode` no sirve: cambia entre ejecuciones— y con contraste mínimo
      4.5:1 contra la superficie oscura.
- [x] Tipografía: los seis roles de la sección 6.3 sobre Barlow y Barlow Semi Condensed, con
      `FontFeature.tabularFigures()` en números de ruta y ETAs.
- [x] Temas claro y oscuro, oscuro por defecto. Sustituyen el `ThemeData` provisional de
      [`lib/app/app.dart`](lib/app/app.dart).
- [x] Escala de espaciado de 4 y radios con jerarquía (0 placas, 8 chips, 16 cards, 28 hoja). Sin
      sombras.
- [x] Los ocho componentes: `RouteBadge`, `EtaChip`, `FreshnessIndicator`, `StopTile`, `RouteLine`,
      `VehicleMarker`, `EmptyState`, `ErrorState`.
- [x] Galería en `/debug/gallery`, montada solo bajo `kDebugMode`, con interruptor de tema y de
      escala de texto hasta 200 %. Se llega desde el ícono de debug en la esquina del mapa.
- [x] Tests de widget: `EtaChip` en sus cuatro estados, `RouteBadge` eligiendo tinta por contraste,
      `VehicleMarker` sin `bearing`, y el motion anulado cuando el sistema pide reducir animaciones.

**Cierre.** `EtaChip` renderiza el estado desconocido igual de bien que el conocido y nunca muestra
minutos con el dato vencido. 111 tests en verde y `dart analyze` en cero.

**Tres cosas que encontraron los tests, no la vista**

1. **Ni el texto blanco ni el negro pasan 4.5:1 sobre media paleta si se elige por un umbral de
   luminancia.** Ahora [`Contrast.bestOn`](lib/design/tokens/contrast.dart) mide las dos tintas y se
   queda con la mejor.
2. **En tema claro, los tonos brillantes se disuelven contra el fondo.** En vez de apagar toda la
   paleta —y perder lo que distingue a cada ruta— la placa se pone un contorno de 1 px, y solo
   cuando hace falta.
3. **La placa se estiraba de lado a lado dentro de un `Wrap`.** Un `Container` con `alignment` crece
   hasta el ancho que le den. Lo delató la imagen de referencia de la paleta.

**Decisión cerrada, y no como se esperaba.** El color institucional se extrajo con cuentagotas el
20 de septiembre de 2026 y resultó ser **índigo `#3A3578`**, no verde: ver
[el repintado](#extra-el-color-institucional-y-la-dirección-visual). Los tokens de esta fase se
repintaron completos.

---

## Fase 4a — Dataset del simulador ✅

**Objetivo.** Datos que se parezcan a Aguascalientes, no a un laboratorio.

**Entregado.** No se parecen a Aguascalientes: **son** Aguascalientes. Apareció el GTFS estático
oficial del transporte concesionado —lo publica el Gobierno del Estado (CMOV) y lo distribuye el
[Hub de Datos de Transporte Público de Codeando México](https://hdtp.codeandomexico.org/datos/mex-ags-ags)
bajo CC BY-SA 4.0— y la fase dejó de ser cartografía para volverse un script de conversión.

`tool/gtfs_to_mock.py` (Python de biblioteca estándar, cero dependencias, determinista) ·
`tool/gtfs/mex-ags-ags.zip` con su [`SOURCE.md`](tool/gtfs/SOURCE.md) · `assets/mock/` con trece
archivos, declarado en el `pubspec.yaml` · [`lib/core/models/frequency.dart`](lib/core/models/frequency.dart)
· `test/core/models/mock_dataset_test.dart` con 24 verificaciones.

| | Pedía el spec | Entregado |
|---|---|---|
| Rutas | 6 | **48**, con su color real |
| Paradas | ~120 | **1 507** |
| Trazos | trazados a mano sobre OSM | **92** del operador, 41 252 puntos |
| Vehículos | 25 | **323**, repartidos por frecuencia |
| Alertas | 2 | 2 |
| Itinerarios | 4 pares | 4 pares |

Peso: 2.8 MB en disco, **423 KB comprimidos** dentro del APK.

**Tareas**

- [x] Las rutas con su trazo sobre calles reales. Vienen del operador, no de OpenStreetMap.
- [x] Las paradas con nombre, código y accesibilidad. El nombre es del feed (normalizado); el
      código y la accesibilidad están **simulados y declarados**, porque el feed no los publica.
- [x] Rutas **sin ningún vehículo activo**: `R_50B` y `R_52`, marcadas en `service.json`.
- [x] Dos alertas de servicio con su periodo: una vigente sin fin declarado y una ya vencida, para
      probar que la vencida no se pinta.
- [x] Cuatro pares origen-destino: directo, un transbordo, dos transbordos y **caso sin
      resultados**, armados sobre viajes y trazos reales.
- [x] Los vehículos repartidos entre las rutas con servicio: `ceil(vuelta ÷ intervalo)`, que es la
      flota que esa frecuencia exige.

**Cierre.** `dart analyze` en cero y **142 tests en verde** (111 + 24 del dataset + 4 de
`Frequency` + 3 de la tinta de GTFS). `flutter build apk --debug` empaqueta los trece archivos.

**Lo que hubo que decidir**

1. **El feed completo, no seis rutas.** El spec pedía seis porque trazarlas a mano costaba semanas.
   Con un script ese costo desaparece, y media ciudad en blanco no era una decisión de diseño sino
   una limitación heredada.
2. **Entra `Frequency` al modelo.** El feed no tiene horarios: tiene intervalos. Es una entidad
   GTFS de primera clase, así que entra por la misma regla de la sección 3 que protege a las demás.
   Sin ella no hay cómo repartir la flota ni dar "pasa cada 20 min" como respaldo.
3. **El script va en Python y no en Dart.** Hacerlo en Dart obligaba a meter `archive` y `csv` en
   `dev_dependencies`, y agregar paquetes fuera de la tabla de stack es el riesgo 3 de este
   documento. Es herramienta de build, no código de app.

**Dos cosas que encontró el test y no la vista**

1. **Un `stop_id` con un espacio adelante.** El feed trae `" P684"` en dos filas de
   `stop_times.txt`: dos viajes de la R-30 con una parada colgando. Ahora cada celda se recorta al
   leerla.
2. **El calendario venía vencido.** El feed declara vigencia `20230101`–`20251231`. Con esas fechas
   `Calendar.runsOn(hoy)` da `false` siempre y la app diría que no hay servicio nunca, sin error ni
   pantalla roja. La vigencia se abre al convertir, y un test lo vigila para el día que alguien
   reimporte el feed.

**Lo que trajo de regalo.** Los colores reales de las 48 rutas. Varios no son legibles con la tinta
que el mismo feed declara —la R-08 es `#C4CBA6` con texto `#F0F0F0`, 1.5:1—, así que
[`RoutePalette.inkFor`](lib/design/tokens/route_palette.dart) respeta la tinta del feed solo si pasa
4.5:1. El feed manda en identidad, no en legibilidad.

---

## (extra) El color institucional y la dirección visual ✅

**Objetivo.** Cerrar el `TODO` que la sección 6.2 del spec arrastraba desde la fase 1: extraer el
color institucional con cuentagotas de las unidades o de la app oficial, y **no inventarlo**.

**Lo que salió.** No era verde. Midiendo píxeles del splash y el ícono de la app oficial
(`com.mx.nrtec.agsstopbus`) y de la fotografía oficial de la Tarjeta Soluciones YoVoy, el color
dominante en las tres fuentes es **índigo `#3A3578`**. El `#00854A` que este proyecto usó durante
tres fases salió de una hoja en blanco.

**El daño colateral que encontró la medición.** Ese verde daba **3.95:1** contra la superficie
oscura: llevaba tres fases sin pasar el piso de 4.5:1 que el propio spec exige, y no había test que
lo vigilara. Ahora lo hay.

**Entregado.** Tokens repintados en los dos temas con el patrón de dos hex por tema que ya usaban
los semánticos (`brand` `#3A3578` claro / `#8179DC` oscuro) · superficies enfriadas hacia el índigo
· `cantera` con su regla de uso · Barlow Condensed como tercer ancho para el contador ·
`LitSurface` y `RouteStrip` · cinco imágenes de referencia regeneradas · [`DESIGN.md`](DESIGN.md) ·
enmiendas al spec en §2, §6.2, §6.3, §6.4, §6.6 y §10.

**Lo que se descartó.** Los acentos neón del wordmark oficial —cian, lima, magenta, amarillo—. Se
midieron y no se adoptan: acercarían la app a imitar la identidad oficial, que la sección 10
prohíbe, y el lima compite con los colores de estado.

---

## Fase 4b — `MockTransitRepository` y simulador ✅

**Objetivo.** Simular un sistema de transporte real **con sus fallas**. Un mock de datos perfectos
produce una UI que se rompe en producción.

**Entrega.** `lib/core/data/transit_repository.dart` (el contrato de la sección 4.1) ·
`lib/core/data/mock/` con la implementación y el simulador · `lib/core/data/remote/` con el
esqueleto · panel de control en `/debug/simulator`.

**Tareas**

- [x] Interfaz `TransitRepository` con los nueve métodos del contrato, tal cual.
- [x] `MockTransitRepository` leyendo los JSON de `assets/mock/`. Son 2.8 MB: el parseo va fuera
      del hilo de UI.
- [x] Flota según `service.json`: 323 vehículos repartidos por frecuencia, con `R_50B` y `R_52`
      sin servicio. El panel de debug puede recortar el número para perfilar.
- [x] Movimiento: cada vehículo interpolado sobre los puntos de su `shape` a 20–40 km/h, con
      paradas de 15–30 s en cada `Stop`.
- [x] Cadencia de reporte de **30 s**, no por frame: es la cadencia real y obliga a la UI a
      interpolar.
- [x] Ruido GPS de 5–20 m perpendicular al trazo.
- [x] Pérdida de señal: ~10 % de los vehículos desaparece de 1 a 3 minutos y reaparece adelantado.
- [x] `bearing` nulo en ~15 % de los reportes.
- [x] Latencia aleatoria de 200–1500 ms en todos los `Future`, y ~5 % de llamadas que lanzan
      excepción.
- [x] `planTrip` por proximidad contra los cuatro pares precocinados; lista vacía si el origen o el
      destino no cae cerca de ninguno.
- [x] `RemoteTransitRepository`: esqueleto con `UnimplementedError` en cada método y un
      `// TODO(api):` indicando qué endpoint GTFS-RT lo alimentaría. No se implementa; existe para
      que la forma del código ya contemple su llegada.
- [x] `transitRepositoryProvider` eligiendo implementación con
      `bool.fromEnvironment('USE_REMOTE_API')`.
- [x] Panel de debug con los parámetros del simulador ajustables en vivo.
- [x] Tests: con semilla fija el simulador es determinista, y cada falla se puede forzar desde el
      panel.

**Cierre.** `dart analyze` en cero y **183 tests en verde**. Ninguna capa superior sabe qué
implementación está activa: el único import de una concreta fuera de `core/data/` es el del panel
de debug, que existe precisamente para inspeccionarla.

**Cómo verlo.** `/debug/simulator`, desde el ícono de debug en la esquina del mapa: la flota
reportando en vivo, los que se quedaron sin señal, y los controles para subir la latencia, forzar
errores y apagar los GPS. Los botones **Perfecto** y **Hostil** son los dos extremos.

**Tres decisiones**

1. **La posición es una función pura del reloj.** `positionsAt(t)` calcula dónde va cada vehículo
   desde una época fija, en vez de acumular estado en un `Timer`. Así el simulador es determinista
   —un test puede afirmar una coordenada— y no se desincroniza cuando la app pasa a background.
2. **El trazo se convierte en línea de tiempo una vez por `shape`, no por vehículo.** Son 92 trazos
   para 323 vehículos: proyectar cada parada sobre la polilínea 323 veces habría sido tirar trabajo.
3. **La latencia y los errores tienen su propio generador**, aparte del de movimiento. Subir la
   tasa de error en el panel no teletransporta la flota.

**Lo que encontró el test, no la vista.** El panel de debug desbordaba 40 px a lo ancho de un
teléfono: la etiqueta "Vehículos que pierden señal" no cabía junto a su valor. Ahora la etiqueta
cede y el valor se queda entero.

---

## Fase 5 — Mapa ✅

**Objetivo.** La pantalla de inicio, con presupuesto de **60 fps con 40 vehículos visibles** en un
Android de gama media-baja, y nunca por debajo de 30.

**Entrega.** `lib/features/map/` completa, sustituyendo el placeholder. Más `lib/core/location/`,
`lib/core/lifecycle/`, `lib/core/clock/` y `lib/core/perf/`, que la pantalla necesitó y que las
siguientes fases van a reusar.

**Decisiones que se acordaron antes de empezar**

| Decisión | Elección |
|---|---|
| Fondo de mapa | **OpenFreeMap** (esquema OpenMapTiles), vectorial, sin llave ni límites, con `flutter_map_vector_tiles ^2.9.0` (BSD-3). El paquete trae caché en disco —50 MB, 14 días—, así que no hizo falta otro. Atribución visible: "© OpenMapTiles © OpenStreetMap" |
| Ubicación | **`geolocator ^14`** (MIT). Solo "mientras se usa"; nada en segundo plano |

**Tareas**

- [x] Tiles con tema oscuro personalizado: calles desaturadas, POIs ocultos, etiquetas al mínimo.
      Los dos estilos salen de los tokens con `tool/map_styles.py`, y un test falla si se separan
      de `colors.dart`.
- [x] Caché de tiles en disco: la del paquete, que además deja ver sin red lo ya visitado.
- [x] Capa de rutas: la red entera como grabado apagado al 30 %, y **la ruta elegida encendida**
      con su grosor por zoom y su halo.
- [x] Simplificación de shapes por zoom: la de `PolylineLayer`, que ya es Douglas-Peucker. Las
      polilíneas se reconstruyen por banda de zoom, no en cada cuadro del pellizco.
- [x] Interpolación de marcadores a lo largo de la ventana de 30 s con **un solo `Ticker`** para
      toda la flota, y un solo `CustomPainter`.
- [x] Clustering arriba de 30 marcadores visibles y filtrado por viewport antes de dibujar.
- [x] `RepaintBoundary` alrededor de la capa de marcadores.
- [x] Hoja inferior en tres posiciones (120 px / 45 % / 90 %) con `LitSurface`. **Sin
      `BackdropFilter`**, y un test que lo vigila.
- [x] Barra de búsqueda flotante con `SafeArea`, FAB de ubicación y chip de frescura global con el
      único pulso de la pantalla.
- [x] Tocar parada abre su detalle en la hoja; tocar vehículo abre `RouteStrip` con ruta, destino
      y próxima parada.
- [x] Pausar el stream de vehículos y el refresco de arribos en segundo plano, con test.
- [x] Medir fps en `--profile`. Números abajo; el de hardware real sigue pendiente.

**Features de `FEATURES.md` que entraron aquí:** "¿Ya me voy?" y "Búsqueda única".

**Cierre.** `dart analyze` en cero y **242 tests en verde** (59 nuevos), incluidos los del modo
hostil y el texto al 200 %. Tres imágenes de referencia nuevas en `test/features/map/goldens/`.
Visto en el emulador Pixel 8 API 36 con tiles reales, ubicación simulada y el permiso concedido.

**Cómo verlo.** Es la pantalla de inicio. Toca un camión: su ruta se enciende y abajo sale la
tira. Escribe `20` en la búsqueda. En debug, el ícono de la esquina lleva a la galería y al
simulador; en el simulador, **Hostil** apaga la tira de los camiones que pierden señal.

**Rendimiento medido** con `--dart-define=FRAME_STATS=true` en profile, en el emulador:

| Momento | fps | build p90 | raster p90 | peor cuadro |
|---|---|---|---|---|
| En reposo, con la flota animándose | 59 | 2.4 ms | 17.4 ms | 42 ms |
| Arrastrando el mapa | 43–55 | 10.9–17.5 ms | 17.1–17.4 ms | 72 ms |

**El número del emulador no vale como número de gama media-baja**: su GPU es emulada. Lo que sí es
señal es el **build p90 de 17.5 ms al arrastrar**, que es trabajo del hilo de UI y se va a notar en
un teléfono lento. Sospechosos, en orden: el recorte y reproyección de las 92 polilíneas en cada
cuadro, la colisión de etiquetas del fondo vectorial y la reconstrucción de las capas cuando cambia
la cámara. Se mide primero en hardware y se optimiza con el perfilador en la mano, no a ojo.

**Cuatro decisiones**

1. **Un método más en el contrato: `getNetwork()`.** El mapa necesitaba los 92 trazos de golpe y
   saber qué paradas recorre cada viaje. Pedirlos uno por uno habría multiplicado la latencia y las
   fallas; en GTFS la parte estática es un solo zip, así que pedirla entera es lo realista. Quedó
   anotado en la sección 4.1 del spec.
2. **Un camión que pierde señal no desaparece del mapa.** Se queda en su último lugar, se apaga y
   a los 3 minutos se vuelve gris y sin flecha. Solo se olvida a los 10 minutos. Es la regla de la
   sección 9: el dato viejo se marca, no se borra.
3. **Los toques no usan un widget por camión.** La capa anota en cada cuadro dónde dibujó cada
   cosa, y el `onTap` del mapa pregunta ahí. El mapa conserva sus gestos y no hay 40 detectores
   peleando por ellos.
4. **El reloj es un provider.** Todo lo que calcula una edad o un "sal en 6 min" pregunta a
   `clockProvider`. Así las imágenes de referencia del mapa salen iguales cada vez.

**Lo que encontraron los tests y el emulador, no la vista**

- `StopTile` se desbordaba **38–52 px** en un teléfono de 412 px en cuanto llevaba distancia: el
  código, la distancia y el ícono no cabían en fila. La galería nunca lo mostró porque ahí la
  distancia era corta.
- El manifest principal **no tenía permiso de `INTERNET`**: solo lo traían los de debug y profile.
  El build de release se habría quedado sin mapa.
- Con la hoja al 90 %, **la barra de búsqueda le tapaba el borde** en un Pixel 8. Ahora la hoja se
  detiene justo debajo.
- "¿Ya me voy?" decía "Vas tarde" por el primer camión de la lista aunque el segundo sí se
  alcanzaba. Ahora elige el primero que se alcanza a pie.

**Pendiente.** Medir en un Android real de gama media-baja con `FRAME_STATS`, y optimizar el build
al arrastrar si pasa de 16 ms. Las etiquetas del fondo usan la fuente del sistema: el paquete no
acepta otra familia.

---

## (extra) Identidad visual

**Objetivo.** Que la app tenga cara propia y no se parezca a la oficial.

**Tareas**

- [ ] Ícono adaptativo de Android (foreground, background, monocromo) e ícono de iOS.
- [ ] Splash con la marca.
- [ ] Revisión contra la sección 10 del spec: no imitar el ícono ni la identidad de la app oficial.

---

## Fase 6 — Parada y ruta ✅

**Objetivo.** Las dos pantallas que responden "qué rutas pasan por aquí" y "dónde viene mi camión".

**Entrega.** `lib/features/stop/` y `lib/features/route/`, sustituyendo sus placeholders. Más
`lib/features/favorites/data/` y `application/`, porque el botón de favorito necesitaba dónde
guardar, y `lib/core/transit/`, a donde se mudaron los providers en vivo que ya comparten tres
pantallas.

**Decisiones que se acordaron antes de empezar:**

- Los favoritos se guardan desde ya con **`shared_preferences ^2.5`** (oficial de Flutter, BSD-3),
  detrás de una interfaz `FavoritesStore`. Una lista de ids no pide una base de datos. Con esto
  queda resuelta la decisión de persistencia que el spec dejaba para la fase 8.
- Para que el modo paradero no deje apagar la pantalla, **`wakelock_plus ^1.8`** (Flutter
  Community, BSD-3), detrás de una interfaz `ScreenAwake`.

**Tareas**

- [x] Detalle de parada, como en la sección 8.2 del spec: nombre y código, arribos ordenados por
      ETA, cada fila con `RouteBadge`, destino y `EtaChip`; botón de favorito; pull-to-refresh;
      alertas de servicio activas arriba.
- [x] Detalle de ruta, como en la sección 8.3: trazo completo arriba, paradas en secuencia abajo,
      posición de los vehículos activos entre paradas, selector de sentido. Si la ruta no tiene
      vehículos, decirlo explícitamente en vez de mostrar una lista vacía.
- [x] Los cuatro estados en ambas pantallas, con skeleton en vez de spinner centrado.
- [x] `Semantics`: un ETA se anuncia completo, "ruta 20, llega en 4 minutos, dato en vivo".
- [x] Tests de los providers de `application/` con repositorio falso inyectado por `override`.

**Las cinco features de `FEATURES.md`**, en una segunda tanda. La primera salió solo de la lista de
tareas de arriba, que no las nombra.

- [x] **Modo paradero** (`/stop/:id/board`): una parada, el número enorme, la tira de acercamiento
      y los dos siguientes en una línea. Contraste al máximo, pantalla encendida, se actualiza sola
      y un toque sale. Se entra desde el ícono de pantalla completa del detalle de parada.
- [x] **Frecuencia como respaldo.** Sin dato en vivo, el chip dice "cada 20 min · según horario"
      en vez de un minuto que no se puede prometer. `Arrival` ganó el campo `headway`.
- [x] **Ocupación.** El simulador la reporta y la UI la pinta con una, dos o tres figuras más la
      palabra: "va vacío", "va llenándose", "va lleno".
- [x] **Accesibilidad como filtro.** "Solo accesibles" en el mapa, guardado en el teléfono, y la
      marca ♿ en la tira de la ruta. El interruptor del planificador entra con la fase 7.
- [x] **Mostrar confiabilidad.** `ReliabilityNote` y el hueco donde se conecta el historial.
      Hoy el historial está vacío y la app calla; el cálculo es de la fase 8.

**Cierre.** Ningún widget llama al repositorio: todo pasa por un provider de `application/`.
`dart analyze` en cero y **332 tests en verde** (90 nuevos en la fase), incluidos el modo hostil y
el texto al 200 % en las tres pantallas. Imágenes de referencia en `test/features/stop/goldens/`
(parada y modo paradero, en los dos temas) y `test/features/route/goldens/`. Visto en el emulador
Pixel 8:

- mapa → parada → favorito, que sigue marcado después de matar la app → ruta
- "Solo accesibles", que sigue activo después de reinstalar
- modo paradero con la pantalla configurada para apagarse a los 15 s: a los 28 s seguía
  encendida, con el wakelock a nombre de la app

**Cómo verlo.** En el mapa, toca una parada cercana y luego su tarjeta: se abre la parada. El
ícono de pantalla completa abre el modo paradero. Toca un arribo: se abre su ruta. Desde un camión
o una ruta buscada, "Ver ruta".

**Lo que se decidió en el camino**

1. **La ruta es la tira, puesta de pie.** La lista de paradas no lleva viñetas: es `RouteStrip` en
   vertical, en el color de la ruta. Los camiones son los mismos bloques, dibujados **entre** la
   parada por la que pasaron y la siguiente. Con el dato vencido se apagan igual que en la tira.
2. **El sentido se nombra por su destino**, "Hacia Margaritas", no "ida" y "vuelta".
3. **Las alertas de una parada son también las de sus rutas.** El desvío de la R03 no nombra
   Héroes de Chapultepec, pero a quien espera la R03 ahí le importa.
4. **"No existe" no se reintenta.** Riverpod 3 reintenta los providers que fallan; una parada que
   no existe se quedaba cargando diez veces. `StopNotFound` y `RouteNotFound` salen de la regla.
5. **Los providers en vivo se mudaron a `lib/core/transit/`.** El mapa los sigue importando desde
   `map_providers.dart`, que los reexporta.
6. **El protagonista del modo paradero es el primer camión en vivo**, no el primero de la lista: un
   horario ordena como "10 min" (media frecuencia), pero no es una promesa.
7. **"Solo accesibles" deja fuera las paradas sin verificar.** Quien necesita una rampa no puede
   apostar a que haya una. El tooltip lo dice.
8. **El modo paradero sigue el tema del sistema**, con fondo y texto puros. De noche no se deslumbra
   a nadie con blanco.

**Lo que encontraron el emulador y los goldens**

- La misma ruta salía de **dos colores**: en la hoja del mapa, `StopTile` pintaba la placa con el
  color derivado del id, y la pantalla de parada con el oficial del GTFS. `StopTile` ahora recibe
  la ruta y usa el oficial.
- En la hoja del mapa, "Ver parada" quedaba debajo de doce arribos. Ahora la tarjeta entera abre la
  parada.
- El selector de sentido salía en el turquesa de fábrica de Material. Va en el índigo de marca.
- La estrella de favorito iba en índigo; `colors.dart` reserva **cantera** para lo que el usuario
  decidió. Corregido también en `StopTile`.
- **El simulador no era determinista entre corridas.** `Object.hash` se siembra al azar en cada
  proceso; no se notaba porque los goldens corren sin ruido de GPS. La ocupación lo destapó: el
  golden de la parada cambiaba en cada corrida. Ahora las semillas salen de un FNV-1a propio.
- A las 8:00 casi todos los camiones salían "va lleno" y la lista era una pared roja. En hora pico
  va lleno uno de cada cuatro.
- En un renglón angosto las tres figuras de ocupación desbordaban 9 px. Ahora son un solo texto
  que envuelve.
- Con la hoja del mapa arriba, el chip "Solo accesibles" quedaba encima de "Sal en…". Se esconde
  pasando la mitad, como el botón de ubicación.
- Con el camión "llegando", el modo paradero no dibujaba la tira: lo trataba como ya pasado.
- El ícono de la nota de confiabilidad iba en cantera, en la misma fila que el `EtaChip`; la regla
  de `DESIGN.md` lo prohíbe.

---

## Fase 7 — Planificador ✅

**Objetivo.** Responder "cómo llego de A a B" con itinerarios simulados, y responder bien también
cuando no hay respuesta.

**Entrega.** `lib/features/planner/` completa: `application/` con la petición, el orden, la salida
útil, las horas y el modo viaje, y `presentation/` con el planificador, el buscador de lugares, el
detalle y el modo viaje.

**Decisiones que se acordaron antes de empezar:**

- **El modo viaje sigue al camión en el que vas, no al GPS.** Con "Ya me subí" se fija el vehículo
  de esa ruta que está en la parada o llegando, y el conteo sale de su reporte. El GPS es lo que
  más batería gasta, y en el emulador el usuario no se mueve.
- **La pantalla se queda encendida durante el viaje**, con el `ScreenAwake` de la fase 6. Con la
  app en segundo plano todo se detiene (§7), así que un aviso de "bájate" con la pantalla apagada
  no llegaría nunca. Se suelta al terminar y al pasar a segundo plano.
- **`itineraries.json` gana alternativas**, generadas con `tool/gtfs_to_mock.py`. Con una sola
  opción por par el orden "simplicidad antes que minutos" no se vería nunca.

**Tareas**

- [x] Formulario de origen y destino con "mi ubicación" y búsqueda, más selector de hora de salida.
- [x] Lista de resultados: duración total, número de transbordos, placas de las rutas en secuencia
      y distancia a pie.
- [x] Detalle del itinerario: timeline vertical con tramos de caminata y de camión, y mapa con la
      geometría completa.
- [x] Estado "no encontré ruta" **con salida útil**: las rutas que pasan a menos de 600 m del
      origen, que abren la ruta, y hasta dónde te acerca un solo camión, que abre esa parada.
- [x] **Modo viaje** (`FEATURES.md`, feature 5): la tira con lo que falta, "faltan 3 paradas" en
      grande y un aviso a las dos paradas y a la una, con vibración y anuncio al lector de pantalla,
      una sola vez por tramo.
- [x] **El interruptor "Solo accesibles" en el planificador** (feature 8). Es el mismo del mapa.

**Nota de alcance.** No hay motor de ruteo real en la v1. La UI se construye completa contra los
itinerarios precocinados de la fase 4a.

**Cierre.** `dart analyze` en cero y **382 tests en verde** (50 nuevos en la fase), con modo hostil
y texto al 200 % en el planificador, el detalle y el modo viaje. Imágenes de referencia en
`test/features/planner/goldens/`: resultados en los dos temas, "no encontré ruta", el detalle y el
modo viaje a dos paradas. Visto en el emulador Pixel 8: simulador → "Con dos transbordos" → el
filtro de accesibilidad las esconde y lo dice → "Mostrarlas de todos modos" → el detalle, con el
mapa de fondo real → "Empezar viaje", con el wakelock a nombre de la app.

**Cómo verlo.** En el mapa, el chip "Cómo llego" abre el planificador desde tu ubicación, y en una
parada, el ícono de direcciones lo abre con esa parada como destino. En debug, el panel del
simulador trae **"Viajes de prueba"**: los cuatro pares precocinados, a un toque. Fuera de ellos,
la respuesta correcta es "no encontré ruta".

**Lo que se decidió en el camino**

1. **La petición vive en la URL**: `/planner?from=here&to=P606&at=8:30`. El detalle y el modo viaje
   llevan la misma query, así que se rearman solos si se abren por enlace. Cambiar un campo
   reemplaza la página, y "volver" regresa a donde se estaba antes de planear.
2. **El orden** cuesta cada transbordo en 10 min y cada minuto a pie más allá de 500 m en 1.5 min
   extra (`ranking.dart`). Un transbordo solo gana si ahorra de verdad.
3. **Las horas no cuentan la espera** y la pantalla lo dice: los itinerarios no traen horarios. Si
   se sale ahora, la primera tarjeta y la primera subida traen el `EtaChip` en vivo de ese camión.
4. **Un destino se resuelve a la parada donde termina el viaje.** "Hacia Las Palmas" es un lugar
   al que se llega bajando donde el camión termina.
5. **"Mi ubicación" sin GPS no se sustituye en silencio** por el centro de la ciudad: la pantalla
   dice por qué y ofrece elegir una parada.
6. **Con el filtro activo, una opción que suba o baje en una parada sin verificar se esconde**, y
   se dice cuántas. "Mostrarlas de todos modos" no cambia el interruptor guardado. Con el dataset
   de hoy **ninguna opción de ningún par pasa el filtro**: es el estado que más se va a ver, y
   está resuelto como tal.
7. **"Ya me subí" no se habilita sin un camión cerca.** Seguir a un camión inventado sería peor que
   no seguir a ninguno. Con la señal perdida, el conteo se queda en el último reporte y lo dice.
8. **La paleta de máximo contraste** del modo paradero se mudó a `design/tokens/max_contrast.dart`:
   la usan el modo paradero y el modo viaje.
9. **`RouteSequence`**, las placas del itinerario en orden, pasó a `design/components` y a la
   galería. La tarjeta y la línea de tiempo leen providers y se quedan en la feature: la galería
   no importa `features/`.

**Lo que encontraron las pruebas y el emulador**

- **Las alternativas desnudaron a los pares originales.** En el par "directo", la R33 llega en 18
  min contra los 27 de la R09 precocinada; en "dos transbordos", la R25 → R27 con un transbordo
  gana por 14 minutos. El orden lo muestra.
- **El modo viaje volvía al paso 1 solo.** `rideView` escuchaba al controlador del viaje después
  de un `await`; mientras se recalculaba, el controlador (`autoDispose`) se quedaba sin quien lo
  escuchara y se desechaba. Todo lo que se escucha va ahora antes del primer `await`, como en
  `stopBoard`.
- "→" no existe en Barlow y salía un cuadro vacío en "8:00 → 8:33". Ahora es una raya.
- Con texto al 200 %, un botón "Cómo llego" junto a la búsqueda la desbordaba 6 px. Pasó a ser un
  chip con texto junto a "Solo accesibles", que además se entiende mejor que un ícono solo.
- A bordo, con texto al 200 %, el contenido no cabía y los `Spacer` desbordaban. Las cuatro vistas
  del modo viaje reparten el espacio cuando sobra y se desplazan cuando no alcanza.
- **Una prueba del mapa es inestable bajo carga.** "Tocar un camión abre la tira" falló una vez en
  la suite completa y pasó en las demás corridas: la posición interpolada depende del reloj real.
  Es previa a esta fase; queda anotada para la fase 9.

---

## Fase 8 — Favoritos y ajustes ✅

**Objetivo.** Que la app recuerde lo que al usuario le importa y se pueda configurar.

**Entrega.** `lib/features/favorites/` y `lib/features/settings/` completas, más `lib/core/history/`,
que es donde vive lo que este teléfono ha visto, y `lib/core/cache/`, que mide y borra los tiles.

**Decisiones que se acordaron antes de empezar:**

- **"Lo prometido" es lo que esta app dijo.** Una observación es la diferencia entre el ETA que la
  app mostró y el momento en que el camión pasó de verdad. Es literalmente lo que reclama la
  feature 4 —ninguna app te dice si cumplió— y no necesita tocar la capa de datos: se observa con
  lo que la pantalla ya está pidiendo.
- **Lo aprendido vive en la hoja del mapa**, arriba de "Paradas cercanas", como dice `FEATURES.md`:
  no es un widget aparte, es el orden de la lista.
- **"Tamaño de texto" es una escala propia de la app**, multiplicada por la del sistema y topada en
  200 %: sirve a quien no quiere agrandar todo el teléfono, y el tope es el piso de la sección 11.
- **`path_provider` sube a dependencia directa** —ya venía como transitiva del mapa— para que
  "limpiar caché" borre de verdad y diga cuántos MB liberó.

**Tareas**

- [x] Persistencia local de paradas y rutas favoritas.
- [x] Los favoritos de parada muestran ETA en vivo directamente en la lista.
- [x] Ajustes: tema claro/oscuro/sistema, reducir animaciones, tamaño de texto, limpiar caché.
- [x] Pantalla "Acerca de" con el aviso que exige la sección 10 del spec: app independiente, sin
      afiliación con CMOV ni con el operador del sistema.
- [x] Panel de control del simulador accesible solo en builds de debug, ahora desde Ajustes.
- [x] **Confiabilidad observada, la parte que faltaba** (`FEATURES.md`, feature 4): el cálculo.
      `ReliabilityCopy` existe desde la fase 6 y nunca se había visto en pantalla.
- [x] **Mis rutas aprendidas** (feature 2): la hoja encabeza con lo que sueles tomar a esa hora.

**Decisión ya tomada en la fase 6:** `shared_preferences`, porque lo que se guarda son listas de
ids. **Se revisó aquí y se sostiene**: una observación es una línea corta, el historial está topado
en 500 arribos y 300 usos, y la única pregunta que se hace —"todo lo de esta ruta en esta parada"—
se responde leyendo la lista completa. Una base de datos para eso sería un paquete a cambio de nada.

**Cierre.** `dart analyze` en cero y **438 tests en verde** (56 nuevos en la fase), con texto al
200 % en favoritos, ajustes y "Acerca de". Imágenes de referencia nuevas en
`test/features/settings/goldens/`. Se regeneraron las del mapa y la ruta: el menú ⋮ y la estrella
de ruta son nuevos. `PhasePlaceholder` se borró: ya no quedaba ninguna pantalla por construir.

**Cómo verlo.** El menú ⋮ de la barra del mapa lleva a Favoritos y a Ajustes. Para ver la
confiabilidad sin esperar media hora frente a una parada, el panel del simulador trae **"Sembrar
historial"**, solo en debug: llena el historial y la hoja del mapa, y se borra desde Ajustes con el
mismo botón que lo de verdad.

**Lo que se decidió en el camino**

1. **La promesa no se reescribe.** Se hace una vez por camión y parada, y solo si el camión viene a
   más de 2 minutos: prometer "30 segundos" y acertar no demuestra puntualidad. Si se actualizara
   con cada refresco, la promesa siempre se cumpliría y la nota sería un adorno.
2. **Sin señal no se inventa un retraso.** Una promesa cuyo camión lleva 3 minutos sin reportar se
   tira sin anotar nada. Es el mismo criterio del ETA numérico: un dato viejo no fecha nada.
3. **Solo se juzga con `current_stop_sequence`.** La parada más cercana en línea recta alcanza para
   dibujar un camión en el mapa, no para decidir que ya pasó y guardar una observación.
4. **La franja horaria se guarda pero no parte el cálculo** de la confiabilidad: con cinco
   observaciones mínimas, partir por franja dejaría la nota callada para siempre. La franja sí pesa
   en lo aprendido, que es donde la hora importa.
5. **Lo aprendido decae a la mitad cada dos semanas** y pide un par de usos recientes en la misma
   franja para aparecer. Con menos, adivina en voz alta.
6. **"Fijar" no es un concepto nuevo**: es la estrella. Una sugerencia se fija volviéndola favorita
   y se calla con "No me la muestres". Los favoritos manuales van arriba y no se repiten abajo.
7. **Una sola entrada nueva en el mapa.** El menú de debug se volvió el menú de la app, con las
   herramientas dentro de `kDebugMode`: dos botones más —estrella y engrane— no caben con el texto
   del sistema al 200 %, que es donde esa barra ya se desbordó una vez.
8. **Borrar el historial no borra los favoritos**, y el diálogo lo dice: una cosa la eligió el
   usuario y la otra la dedujo la app.

**Lo que encontraron las pruebas y el emulador**

- **Los chips de Material se pintan de verde.** `ChoiceChip` trae su propio color de selección
  (`secondaryContainer`) y la marca es índigo: los de ajustes llevan la paleta de la app, como el
  chip de "Solo accesibles".
- **Una lista perezosa no construye lo que no se ve**, y los tests de "Acerca de" y de la hoja lo
  descubrieron: hay que desplazar antes de buscar el texto de hasta abajo.
- El panel del simulador tenía una prueba que toca un slider por su texto; el bloque nuevo lo había
  empujado fuera de la pantalla. La siembra de historial se fue al final del panel.
- **"Limpiar caché" borraba una carpeta vacía, y solo se vio en el emulador.** La capa del mapa abre
  su caché al montarse, y la ruta venía de un provider asíncrono que todavía no había respondido: se
  quedaba con la carpeta del paquete para siempre. Ahora se le pasa la **función** que resuelve la
  carpeta, que es justo lo que el paquete pide, y el `StyleReader` usa la misma. Verificado en el
  emulador: la carpeta de la app se llena y el botón libera lo que dice.
- **La misma parada salía dos veces en la hoja**, arriba como favorita y otra vez en "Paradas
  cercanas". Lo de arriba se cae de la lista genérica, y si no queda ninguna, la sección no se pinta
  en vez de decir "no hay paradas a 600 m", que sería mentira.

---

## Fase 9 — Pulido

**Objetivo.** Que lo construido aguante el mundo real y a un usuario con lentes, con sol en la
cara y con un teléfono de hace cuatro años.

**Tareas**

- [ ] Auditoría de accesibilidad pantalla por pantalla: contraste mínimo 4.5:1 en texto y 3:1 en
      gráficos, toque mínimo de 48×48 dp, `Semantics` en todo control, texto del sistema al 200 %
      sin romper layouts, reducción de movimiento respetada.
- [ ] Verificar que el color nunca sea el único portador de significado: la frescura lleva texto e
      ícono además de color. Hay daltonismo, y hay sol directo.
- [ ] Perfilado de rendimiento en gama media-baja: fps del mapa, jank y memoria.
- [ ] Los cuatro estados revisados pantalla por pantalla con el simulador en su configuración más
      hostil.
- [ ] Repaso de copy: verbos activos, sentence case, sin disculpas. "Sin señal de esta ruta", no
      "Lo sentimos, no fue posible obtener la información en este momento".

---

## (extra) Build de release

**Tareas**

- [ ] Keystore de firma y configuración de release en Gradle, sustituyendo la firma de debug que
      dejó el template.
- [ ] `flutter build apk --release` y `--analyze-size` para revisar el peso.
- [ ] Verificar en el artefacto final el `applicationId` `mx.yovoygo.app` y el nombre visible
      "Yo Voy Go", ambos ya configurados en la fase 1.
- [ ] Probar en un dispositivo real: sigue siendo el pendiente heredado de la fase 1.

---

## Features propuestas

Ampliaciones sobre el spec, catalogadas y justificadas en [`FEATURES.md`](FEATURES.md). Todas son
locales: ninguna necesita servidor. Dónde entra cada una:

| Fase | Features que se suman |
|---|---|
| 5 | Búsqueda única · ¿Ya me voy? |
| 6 ✅ | Modo paradero · Frecuencia como respaldo · Ocupación · Accesibilidad como filtro · Mostrar confiabilidad |
| 7 ✅ | Modo viaje · el interruptor de accesibilidad del planificador |
| 8 ✅ | Mis rutas aprendidas · Calcular confiabilidad |
| 9 | Offline con fecha |

No cambian el orden de las fases ni sus criterios de cierre: se construyen dentro de la pantalla
que les toca.

---

## Decisiones abiertas

| Decisión | Se vuelve bloqueante en | Nota |
|---|---|---|
| ~~Verde institucional real~~ | ~~Fase 3~~ | **Resuelta**: no era verde. Índigo `#3A3578`, extraído de la app oficial y de la Tarjeta Soluciones YoVoy el 20 de septiembre de 2026. Ver [`DESIGN.md`](DESIGN.md) |
| ~~Proveedor de tiles, caché en disco y atribución~~ | ~~Fase 5~~ | **Resuelta**: OpenFreeMap con `flutter_map_vector_tiles`, que trae su propia caché en disco. Atribución visible sobre la hoja |
| ~~Paquete de ubicación y permisos~~ | ~~Fase 5~~ | **Resuelta**: `geolocator`, solo "mientras se usa", con los textos en es_MX en el manifest y el `Info.plist` |
| ~~`shared_preferences` o `drift`~~ | ~~Fase 8~~ | **Resuelta** en la fase 6: `shared_preferences`, porque lo que se guarda son listas de ids |
| ~~Mantener la pantalla encendida~~ | ~~Fase 6~~ | **Resuelta**: `wakelock_plus`, solo en el modo paradero y soltado en segundo plano |
| ~~Fuente del trazado de las rutas~~ | ~~Fase 4a~~ | **Resuelta**: el GTFS oficial de CMOV, vía el Hub de Codeando México, CC BY-SA 4.0. Ver [`tool/gtfs/SOURCE.md`](tool/gtfs/SOURCE.md) |

---

## Riesgos del proyecto

1. ~~**Trazar seis rutas a mano** (fase 4a).~~ **Se cayó.** Apareció el GTFS oficial y el trazado
   dejó de ser trabajo manual. A cambio entra un riesgo nuevo y más chico: el dataset pasó de 6
   rutas a 48, así que el presupuesto de rendimiento de la fase 5 se prueba contra la ciudad
   completa desde el primer día. Es mejor así.
2. **El presupuesto de 60 fps** se gana o se pierde en la fase 5. Interpolación con un solo
   `Ticker`, clustering y filtrado por viewport no son optimizaciones tardías: son el diseño. **Ya
   están**, y en el emulador el reposo va a 59 fps; al arrastrar baja a 43–55 con un build p90 de
   17.5 ms. Sigue abierto hasta medirlo en un teléfono real.
3. **Agregar paquetes fuera de la tabla de stack** sin discutirlo. Todos los que se sumaron se
   acordaron antes: `flutter_map_vector_tiles` y `geolocator` en la fase 5, `shared_preferences` y
   `wakelock_plus` en la fase 6.
