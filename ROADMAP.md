# Roadmap — Yo Voy Go

Plan de construcción de la v1. El **qué** y el **por qué** viven en
[`YOVOY_GO_SPEC.md`](YOVOY_GO_SPEC.md); aquí está el **en qué orden** y el **cuándo se da por
terminado**. Las features propuestas encima del spec, con su justificación, están en
[`FEATURES.md`](FEATURES.md).

**Estado:** fases 1, 2 y 3 cerradas. Siguiente: fase 4a (dataset del simulador).

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
| 4a | Dataset del simulador | 2 | ⏳ siguiente |
| 4b | `MockTransitRepository` y simulador | 2, 4a | ⏳ |
| 5 | Mapa | 3, 4b | ⏳ |
| 6 | Parada y ruta | 5 | ⏳ |
| 7 | Planificador | 6 | ⏳ |
| 8 | Favoritos y ajustes | 6 | ⏳ |
| 9 | Pulido: accesibilidad, rendimiento, los cuatro estados | 7, 8 | ⏳ |
| — | **(extra)** Build de release firmado | 9 | ⏳ |

Las fases 3 y 4 pueden avanzar en paralelo: ambas solo necesitan los modelos de la fase 2.
La 4a (trazar las rutas) es la tarea más larga del proyecto; conviene empezarla antes de
necesitarla.

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

**Pendiente heredado.** Correr la app en un dispositivo Android real: no había ninguno conectado.

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
      reutilizan el verde de marca. Verificado por test en los dos temas.
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
      escala de texto hasta 200 %. Se llega con un botón desde el placeholder del mapa.
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

**Decisión pendiente.** El verde institucional real. Hoy `#00854A` es un placeholder y el spec pide
extraerlo con cuentagotas de las unidades o la app oficial, no inventarlo.

---

## Fase 4a — Dataset del simulador

**Objetivo.** Datos que se parezcan a Aguascalientes, no a un laboratorio.

**Entrega.** `assets/mock/` con `routes.json`, `stops.json`, `shapes.json`, `trips.json`,
`stop_times.json`, `calendar.json`, `alerts.json` e `itineraries.json`, y la declaración de
`assets/mock/` en el `pubspec.yaml` —hoy está deliberadamente sin declarar, porque un directorio
de assets vacío rompe el build.

**Tareas**

- [ ] Seis rutas con su trazo sobre calles reales, tomado de OpenStreetMap.
- [ ] ~120 paradas con nombre, código y accesibilidad.
- [ ] Al menos una ruta **sin ningún vehículo activo**: la pantalla que dice "esta ruta no tiene
      servicio ahora" es tan importante como la que muestra camiones.
- [ ] Dos alertas de servicio con su periodo de actividad.
- [ ] Cuatro pares origen-destino en `itineraries.json`: viaje directo, con un transbordo, con dos
      transbordos y **caso sin resultados**.
- [ ] Veinticinco vehículos repartidos entre las rutas con servicio.

**Cierre.** Los trazos se ven sobre calles, no cortando manzanas, y el dataset carga sin errores de
parseo contra los modelos de la fase 2.

**Riesgo.** Es la tarea más lenta de todo el proyecto y no tiene atajo técnico. Conviene trazar con
una herramienta de mapas y exportar, en vez de escribir coordenadas a mano.

---

## Fase 4b — `MockTransitRepository` y simulador

**Objetivo.** Simular un sistema de transporte real **con sus fallas**. Un mock de datos perfectos
produce una UI que se rompe en producción.

**Entrega.** `lib/core/data/transit_repository.dart` (el contrato de la sección 4.1) ·
`lib/core/data/mock/` con la implementación y el simulador · `lib/core/data/remote/` con el
esqueleto · panel de control en `/debug/simulator`.

**Tareas**

- [ ] Interfaz `TransitRepository` con los nueve métodos del contrato, tal cual.
- [ ] `MockTransitRepository` leyendo los JSON de `assets/mock/`.
- [ ] Movimiento: cada vehículo interpolado sobre los puntos de su `shape` a 20–40 km/h, con
      paradas de 15–30 s en cada `Stop`.
- [ ] Cadencia de reporte de **30 s**, no por frame: es la cadencia real y obliga a la UI a
      interpolar.
- [ ] Ruido GPS de 5–20 m perpendicular al trazo.
- [ ] Pérdida de señal: ~10 % de los vehículos desaparece de 1 a 3 minutos y reaparece adelantado.
- [ ] `bearing` nulo en ~15 % de los reportes.
- [ ] Latencia aleatoria de 200–1500 ms en todos los `Future`, y ~5 % de llamadas que lanzan
      excepción.
- [ ] `planTrip` por proximidad contra los cuatro pares precocinados; lista vacía si el origen o el
      destino no cae cerca de ninguno.
- [ ] `RemoteTransitRepository`: esqueleto con `UnimplementedError` en cada método y un
      `// TODO(api):` indicando qué endpoint GTFS-RT lo alimentaría. No se implementa; existe para
      que la forma del código ya contemple su llegada.
- [ ] `transitRepositoryProvider` eligiendo implementación con
      `bool.fromEnvironment('USE_REMOTE_API')`.
- [ ] Panel de debug con los parámetros del simulador ajustables en vivo.
- [ ] Tests: con semilla fija el simulador es determinista, y cada falla se puede forzar desde el
      panel.

**Cierre.** Ninguna capa superior sabe qué implementación está activa y ningún widget importa una
concreta.

---

## Fase 5 — Mapa

**Objetivo.** La pantalla de inicio, con presupuesto de **60 fps con 40 vehículos visibles** en un
Android de gama media-baja, y nunca por debajo de 30.

**Entrega.** `lib/features/map/` completa, sustituyendo el placeholder de
[`lib/features/map/presentation/map_screen.dart`](lib/features/map/presentation/map_screen.dart).

**Tareas**

- [ ] Tiles con tema oscuro personalizado: calles desaturadas, POIs ocultos, etiquetas al mínimo.
      El mapa es fondo; las rutas son el contenido.
- [ ] Caché de tiles en disco: el usuario está en la calle con datos limitados.
- [ ] Capa de rutas con `RouteLine`: trazo grueso, saturado, con halo, ancho según el zoom.
- [ ] Simplificación de shapes con Douglas-Peucker según el zoom.
- [ ] Interpolación de marcadores a lo largo de la ventana de 30 s con **un solo `Ticker`
      compartido** para todos, no un `AnimationController` por vehículo.
- [ ] Clustering arriba de 30 marcadores visibles y filtrado por viewport antes de construirlos.
- [ ] `RepaintBoundary` alrededor de la capa de marcadores.
- [ ] Hoja inferior arrastrable en tres posiciones (120 px / 45 % / 90 %) con superficie sólida.
      **Prohibido `BackdropFilter` sobre el mapa**: cada instancia fuerza un `saveLayer` por frame.
- [ ] Barra de búsqueda flotante con `SafeArea`, FAB de ubicación y chip de frescura global,
      con un solo pulso por pantalla.
- [ ] Tocar parada abre su detalle en la hoja; tocar vehículo abre callout con ruta, destino y
      próxima parada.
- [ ] Pausar todo polling cuando la app pasa a background (`AppLifecycleState`).
- [ ] Medir fps con 40 vehículos en `--profile` y dejar el número anotado en el PR.

**Decisiones pendientes, ambas fuera de la tabla de stack de la sección 2 del spec.** Proveedor de
tiles y su atribución —además del paquete de caché en disco—, y el paquete de ubicación para el FAB
de "mi ubicación". Ninguno se agrega sin acordarlo.

**Riesgo.** El presupuesto de rendimiento se gana o se pierde aquí. Arreglarlo en la fase 9 es
mucho más caro que hacerlo bien ahora.

---

## (extra) Identidad visual

**Objetivo.** Que la app tenga cara propia y no se parezca a la oficial.

**Tareas**

- [ ] Ícono adaptativo de Android (foreground, background, monocromo) e ícono de iOS.
- [ ] Splash con la marca.
- [ ] Revisión contra la sección 10 del spec: no imitar el ícono ni la identidad de la app oficial.

---

## Fase 6 — Parada y ruta

**Objetivo.** Las dos pantallas que responden "qué rutas pasan por aquí" y "dónde viene mi camión".

**Entrega.** `lib/features/stop/` y `lib/features/route/`, sustituyendo sus placeholders.

**Tareas**

- [ ] Detalle de parada, como en la sección 8.2 del spec: nombre y código, arribos ordenados por
      ETA, cada fila con `RouteBadge`, destino y `EtaChip`; botón de favorito; pull-to-refresh;
      alertas de servicio activas arriba.
- [ ] Detalle de ruta, como en la sección 8.3: trazo completo arriba, paradas en secuencia abajo,
      posición de los vehículos activos entre paradas, selector de sentido. Si la ruta no tiene
      vehículos, decirlo explícitamente en vez de mostrar una lista vacía.
- [ ] Los cuatro estados en ambas pantallas, con skeleton en vez de spinner centrado.
- [ ] `Semantics`: un ETA se anuncia completo, "ruta 20, llega en 4 minutos, dato en vivo".
- [ ] Tests de los providers de `application/` con repositorio falso inyectado por `override`.

**Cierre.** Ningún widget llama al repositorio directamente; todo pasa por un provider de
`application/`.

---

## Fase 7 — Planificador

**Objetivo.** Responder "cómo llego de A a B" con itinerarios simulados, y responder bien también
cuando no hay respuesta.

**Entrega.** `lib/features/planner/` completa.

**Tareas**

- [ ] Formulario de origen y destino con "mi ubicación" y búsqueda, más selector de hora de salida.
- [ ] Lista de resultados: duración total, número de transbordos, placas de las rutas en secuencia
      y distancia a pie.
- [ ] Detalle del itinerario: timeline vertical con tramos de caminata y de camión, y mapa con la
      geometría completa.
- [ ] Estado "no encontré ruta" **con salida útil**: sugerir un destino cercano o mostrar las rutas
      que sí pasan cerca del origen. Un callejón sin salida no es un estado terminado.

**Nota de alcance.** No hay motor de ruteo real en la v1. La UI se construye completa contra los
itinerarios precocinados de la fase 4a.

---

## Fase 8 — Favoritos y ajustes

**Objetivo.** Que la app recuerde lo que al usuario le importa y se pueda configurar.

**Entrega.** `lib/features/favorites/` con su capa `data/` propia, y `lib/features/settings/`.

**Tareas**

- [ ] Persistencia local de paradas y rutas favoritas.
- [ ] Los favoritos de parada muestran ETA en vivo directamente en la lista.
- [ ] Ajustes: tema claro/oscuro/sistema, reducir animaciones, tamaño de texto, limpiar caché.
- [ ] Pantalla "Acerca de" con el aviso que exige la sección 10 del spec: app independiente, sin
      afiliación con CMOV ni con el operador del sistema.
- [ ] Panel de control del simulador accesible solo en builds de debug.

**Decisión pendiente.** `shared_preferences` o `drift` para la persistencia. El spec pide elegir
**y justificar** la elección; ninguno de los dos está en la tabla de stack.

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
| 6 | Modo paradero · Frecuencia como respaldo · Ocupación · Accesibilidad como filtro · Mostrar confiabilidad |
| 7 | Modo viaje |
| 8 | Mis rutas aprendidas · Calcular confiabilidad |
| 9 | Offline con fecha |

No cambian el orden de las fases ni sus criterios de cierre: se construyen dentro de la pantalla
que les toca.

---

## Decisiones abiertas

| Decisión | Se vuelve bloqueante en | Nota |
|---|---|---|
| Verde institucional real | Fase 3 | `#00854A` es placeholder; el spec pide extraerlo con cuentagotas, no inventarlo |
| Proveedor de tiles, caché en disco y atribución | Fase 5 | Fuera de la tabla de stack de la sección 2 |
| Paquete de ubicación y permisos | Fase 5 | Fuera de la tabla de stack; además necesita textos de permiso en es_MX en el manifest y el `Info.plist` |
| `shared_preferences` o `drift` | Fase 8 | El spec pide elegir y justificar |
| Fuente del trazado de las rutas | Fase 4a | OpenStreetMap a mano, salvo que aparezca el feed GTFS oficial |

---

## Riesgos del proyecto

1. **Trazar seis rutas a mano** (fase 4a) es la tarea más larga y la que menos se parece a
   programar. Si se deja para el final, bloquea las fases 5 a 7 completas.
2. **El presupuesto de 60 fps** se gana o se pierde en la fase 5. Interpolación con un solo
   `Ticker`, clustering y filtrado por viewport no son optimizaciones tardías: son el diseño.
3. **Agregar paquetes fuera de la tabla de stack** sin discutirlo. Tres decisiones ya lo requieren
   y cada una se acuerda antes de instalarse.
