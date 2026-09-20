# Yo Voy Go

Cliente de transporte público para la zona metropolitana de Aguascalientes.
Flutter, Android e iOS, sin backend propio todavía.

Responde tres preguntas, en este orden de importancia:

1. ¿Dónde viene mi camión y en cuánto llega?
2. ¿Qué rutas pasan por esta parada?
3. ¿Cómo llego de A a B?

**El objetivo no es verse mejor, es comportarse mejor cuando los datos son malos** — que es
siempre. La especificación completa vive en [`YOVOY_GO_SPEC.md`](YOVOY_GO_SPEC.md); este archivo
solo explica cómo trabajar en el repo.

> Aplicación independiente. Sin afiliación con CMOV ni con el operador del sistema de transporte.
> No integra la Tarjeta YoVoy: saldo, recargas y movimientos están fuera de alcance por completo.

---

## Estado

Datos simulados de punta a punta (`MockTransitRepository`). Cero integraciones con APIs externas.

**Fases 1, 2 y 3 cerradas**: base y router, modelos GTFS, y el design system con sus ocho
componentes. Siguiente: fase 4a, el dataset del simulador.

La app ya se ve: en builds de debug, el botón del mapa abre `/debug/gallery`, la galería con cada
componente en todos sus estados, con interruptor de tema y escala de texto hasta 200 %. Sin
dispositivo a la mano, las mismas piezas están fotografiadas en `test/design/goldens/`.

El plan completo —las nueve fases con sus entregables, tareas y criterios de cierre, más las
decisiones que siguen abiertas— vive en [`ROADMAP.md`](ROADMAP.md). Una fase por PR, y no se
empieza la siguiente sin cerrar la anterior.

---

## Principios

### El tiempo real es honesto o no es

La app nunca muestra un ETA numérico calculado desde una posición vieja. Los umbrales viven en
[`lib/core/config/freshness.dart`](lib/core/config/freshness.dart):

| Edad del dato | Estado | Presentación |
|---|---|---|
| < 60 s | `live` | Valor + indicador de pulso |
| 60–180 s | `stale` | Valor + "hace X min" |
| > 180 s | `unknown` | Sin ETA numérico: horario programado o "sin señal" |

Un número inventado es peor que un "no sé".

### Diseñada contra datos imperfectos

El simulador reproduce lo que pasa en producción: latencia de 200–1500 ms, ~5 % de llamadas con
excepción, ruido GPS, vehículos que desaparecen minutos, `bearing` ausente, rutas sin servicio.
Si la UI solo se ve bien con datos perfectos, está mal.

Toda pantalla que consuma datos implementa **cuatro** estados: cargando (skeleton, no spinner),
vacío, error y **dato viejo** — este último muestra el contenido con advertencia de frescura, nunca
vacía la pantalla.

### Preparada para GTFS

Los modelos son GTFS y GTFS-Realtime calcados. El día que exista el feed oficial, la app no se
refactoriza: se cambia la implementación del repositorio.

---

## Requisitos

- Flutter 3.47.5 stable o superior (Dart 3.13.4+)
- Android Studio / Xcode según la plataforma objetivo

## Puesta en marcha

```bash
flutter pub get
dart run build_runner build      # genera *.g.dart y *.freezed.dart
flutter run
```

El código generado **no está versionado**: después de clonar o de cambiar de rama hay que correr
`build_runner`. Durante el desarrollo conviene `dart run build_runner watch`.

## Calidad

Antes de integrar cambios:

```bash
dart analyze     # incluye las reglas de riverpod_lint
flutter test
```

Las imágenes de referencia de `test/design/goldens/` son parte de `flutter test`. Si cambia un
componente a propósito, se regeneran:

```bash
flutter test --update-goldens
```

Son una foto, no una aserción de comportamiento: si alguna sale en rojo por un cambio de versión de
Flutter o de máquina, se regeneran y se revisan a ojo.

`dart analyze` debe salir en cero. Nota: `flutter analyze` **no** ejecuta `riverpod_lint` — ese
plugin usa el sistema nuevo del analizador (`analysis_server_plugin`, declarado en
`analysis_options.yaml`), que solo corre bajo `dart analyze`. Usa `dart analyze` como compuerta.

---

## Stack

| Área | Paquete | Versión |
|---|---|---|
| Estado | `flutter_riverpod` + `riverpod_annotation` | 3.4.3 / 4.0.7 |
| Codegen | `riverpod_generator`, `freezed`, `json_serializable`, `build_runner` | 4.0.9 / 4.0.2 / 6.14.1 / 2.16.1 |
| Modelos | `freezed_annotation` + `json_annotation` | 3.1.0 / 4.12.0 |
| Navegación | `go_router` | 18.0.1 |
| Mapa | `flutter_map` | 8.3.2 |
| Geometría | `latlong2` | 0.10.1 |
| Formato | `intl` + `flutter_localizations` (`es_MX`) | 0.20.3 / SDK |
| Lint | `flutter_lints` + `riverpod_lint` | 6.0.0 / 3.1.9 |
| Tests | `flutter_test` + `mocktail` | SDK / 1.0.5 |

No se agregan paquetes fuera de esta tabla sin discutirlo antes, como pide la
sección 2 del spec.

`build.yaml` fija `explicit_to_json: true` para `json_serializable`: sin eso, los modelos anidados
—los tramos de un itinerario— no se serializan a mapas y el round-trip solo funciona si pasa por
`jsonEncode`.

### Riverpod: solo la API generada

Se usa exclusivamente `@riverpod` sobre funciones o clases `Notifier`/`AsyncNotifier`, con
`riverpod_generator`. Está **prohibido**, aunque compile:

- `StateNotifier` / `StateNotifierProvider`
- `ChangeNotifierProvider`
- declarar providers a mano en vez de generarlos

Además: todo lo async expone `AsyncValue` (nada de `isLoading` booleano manual), todo provider con
polling o stream conserva `autoDispose`, se parametriza con `family` y nunca con estado global
mutable, `ref.watch` en `build` y `ref.read` en callbacks.

---

## Arquitectura

Feature-first, tres capas por feature, dependencias solo hacia adentro.

```text
lib/
  main.dart                    ProviderScope + YoVoyGoApp, sin lógica
  app/
    app.dart                   MaterialApp.router, locale es_MX, tema
    router.dart                go_router como provider keepAlive
    routes.dart                nombres y paths, sin strings sueltos
    phase_placeholder.dart     andamio temporal de las pantallas por construir
  core/
    config/freshness.dart      umbrales de frescura
    models/                    modelos GTFS + converters, con models.dart de barril
    data/                      TransitRepository + mock/ + remote/ (fase 4)
    utils/
  design/
    theme.dart                 temas claro y oscuro sobre Material 3
    tokens/                    color, tipografía, espaciado, motion, paleta de rutas, contraste
    components/                los ocho componentes compartidos
    gallery/                   galería de debug, montada solo bajo kDebugMode
  features/
    map/ stop/ route/ planner/ favorites/ settings/
      application/             providers, casos de uso, modelos de vista
      presentation/            widgets, sin lógica ni acceso a repos
      data/                    solo si la feature tiene fuentes propias
assets/
  fonts/                       Barlow y Barlow Semi Condensed (OFL)
  mock/                        dataset del simulador (fase 4)
test/                          espeja la estructura de lib/
```

Reglas que se revisan en cada PR:

- Un widget que llama `ref.read(transitRepositoryProvider)` directamente es un bug de arquitectura:
  siempre a través de un provider de `application/`.
- Cero referencias a implementaciones concretas de repositorio fuera de `core/data/`.
- Los tests de providers inyectan repos falsos con `ProviderContainer` + `overrides`.

### Rutas

| Path | Nombre | Pantalla |
|---|---|---|
| `/` | `map` | Mapa (inicio) |
| `/stop/:stopId` | `stop` | Detalle de parada |
| `/route/:routeId` | `route` | Detalle de ruta |
| `/planner` | `planner` | Planificador |
| `/favorites` | `favorites` | Favoritos |
| `/settings` | `settings` | Ajustes |
| `/debug/gallery` | `gallery` | Galería del design system (solo en debug) |

---

## Capa de datos

Una sola interfaz, `TransitRepository`, con dos implementaciones. Ninguna capa superior sabe cuál
está activa; la selección es por flag de compilación:

```bash
flutter run --dart-define=USE_REMOTE_API=true   # reservado, aún sin implementar
```

- `MockTransitRepository` — lee `assets/mock/` y simula el sistema con sus fallas. Es el default.
- `RemoteTransitRepository` — esqueleto con `UnimplementedError` y `// TODO(api):` por método,
  indicando qué endpoint GTFS-RT lo alimentaría. Existe para que la forma del código ya contemple
  su llegada.

---

## Accesibilidad

Piso no negociable, verificado por pantalla en la fase 9:

- Contraste ≥ 4.5:1 en texto y ≥ 3:1 en gráficos, en tema claro y oscuro.
- Área de toque ≥ 48×48 dp.
- `Semantics` en todo control; los ETAs se anuncian completos ("ruta 20, llega en 4 minutos, dato
  en vivo").
- Texto del sistema hasta 200 % sin romper layouts.
- Reducción de movimiento respetada.
- El color nunca es el único portador de significado: la frescura lleva texto e ícono además de color.

---

## Licencias

Barlow y Barlow Semi Condensed se distribuyen bajo SIL Open Font License 1.1
([`assets/fonts/OFL.txt`](assets/fonts/OFL.txt)).

Identificador de aplicación: `mx.yovoygo.app` (Android e iOS).
