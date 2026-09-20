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

Simulación de punta a punta (`MockTransitRepository`) sobre **datos reales**. Cero integraciones con
APIs externas: el GTFS oficial está empaquetado, no se descarga.

**Fases 1, 2, 3 y 4a cerradas**: base y router, modelos GTFS, el design system con sus ocho
componentes, y el dataset —48 rutas y 1 507 paradas de Aguascalientes. Siguiente: fase 4b, el
repositorio mock y el simulador.

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

Los modelos son GTFS y GTFS-Realtime calcados. El feed oficial ya llegó y el mapeo no cambió: eso
era exactamente lo que la regla protegía. Lo que falta para producción es tiempo real, y entra por
la implementación del repositorio, no por los modelos.

---

## Requisitos

- Flutter 3.47.5 stable o superior (Dart 3.13.4+)
- Android Studio (Windows, macOS o Linux) — ver [Correr en emulador](#correr-en-emulador)
- Xcode, y por lo tanto macOS, si el objetivo es iOS: no hay forma de compilarlo desde Windows

## Puesta en marcha

```bash
flutter pub get
dart run build_runner build      # genera *.g.dart y *.freezed.dart
flutter run
```

El código generado **no está versionado**: después de clonar o de cambiar de rama hay que correr
`build_runner`. Durante el desarrollo conviene `dart run build_runner watch`.

---

## Correr en emulador

### Android

La cadena de Android la resuelve Android Studio, pero el SDK viene **sin ninguna imagen de
sistema**: hay que bajar una y crear un AVD antes de que `flutter run` tenga dónde instalar.

```powershell
$sdk = "$env:LOCALAPPDATA\Android\Sdk"

# 1. Imagen de sistema (~1.5 GB). google_apis, no _playstore: la app no usa
#    Play Services ni mapas nativos, y sin Play Store adb queda con root.
& "$sdk\cmdline-tools\latest\bin\android.exe" sdk install "system-images/android-36/google_apis/x86_64"

# 2. Perfil del dispositivo
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
& "$sdk\cmdline-tools\latest\bin\avdmanager.bat" create avd `
    -n Pixel8_API36 -k "system-images;android-36;google_apis;x86_64" -d pixel_8

# 3. Arrancar
flutter emulators --launch Pixel8_API36
flutter run -d emulator-5554
```

Dos trampas de la cadena de herramientas, por si algo falla:

- **Los separadores no coinciden.** `android sdk install` (CLI nuevo) usa `/`; `avdmanager`
  (herramienta vieja, todavía vigente) usa `;`. Es el mismo paquete escrito de dos formas.
- **`android.exe` devuelve exit code 9 aunque haya funcionado.** Verificá por la salida, no por
  el código de salida. `sdkmanager` quedó deprecado y ahora es un alias del CLI nuevo.

Para que el emulador no vaya a los tumbos, en
`%USERPROFILE%\.android\avd\Pixel8_API36.avd\config.ini`: `hw.ramSize=4096`, `vm.heapSize=512`,
`hw.gpu.enabled=yes`, `hw.gpu.mode=auto`.

El primer build baja Gradle 9.3.1 y AGP 9.1.0 enteros: tarda varios minutos y no está colgado. En
CPU AMD el emulador necesita **Windows Hypervisor Platform** activo (HAXM es solo Intel); se
verifica con `(Get-CimInstance Win32_ComputerSystem).HypervisorPresent`.

### iOS

**No se puede compilar iOS desde Windows ni desde Linux.** El simulador es un componente de Xcode
y Xcode solo existe en macOS; no hay emulador de terceros que lo sustituya. En una Mac, con Xcode
y CocoaPods instalados, alcanza con `flutter run -d <simulador>`.

Lo que conviene saber antes de sentarse en una Mac:

- `ios/Podfile` **no está en el repo**: lo genera la herramienta de Flutter en el primer build.
  Tampoco están `Pods/` ni `Flutter/Generated.xcconfig`, por la misma razón.
- Deployment target **iOS 15.0**, bundle id `mx.yovoygo.app`.
- `DEVELOPMENT_TEAM` está vacío y para el simulador da igual: no exige firma. Recién hace falta
  una cuenta de desarrollador para dispositivo físico o TestFlight.

Sin Mac a mano hay dos salidas, cuando llegue el momento: un runner `macos-latest` en GitHub
Actions que compile el target iOS y corra `flutter test` (verifica que iOS no se rompió, pero no
se toca la UI), o subir el `.app` del simulador a Appetize.io y manejarlo desde el navegador.

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
  mock/                        dataset del simulador, generado (CC BY-SA 4.0)
test/                          espeja la estructura de lib/
tool/
  gtfs_to_mock.py              convierte el GTFS oficial en assets/mock/
  gtfs/mex-ags-ags.zip         el feed, versionado para reproducir sin red
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

## Datos

El dataset del simulador **no es inventado**: sale del GTFS estático oficial del transporte público
concesionado de Aguascalientes, que publica el Gobierno del Estado (CMOV) y distribuye el
[Hub de Datos de Transporte Público de Codeando México](https://hdtp.codeandomexico.org/datos/mex-ags-ags)
bajo CC BY-SA 4.0.

| | |
|---|---|
| Rutas | 48, con su color real |
| Paradas | 1 507 |
| Trazos | 92 (ida y vuelta), 41 252 puntos sobre calles |
| Servicio | por frecuencia: un intervalo por ruta, no horarios |
| Peso | 2.8 MB en disco, **423 KB comprimidos** dentro del APK |

Los JSON de [`assets/mock/`](assets/mock/) los genera un script y no se editan a mano:

```bash
python tool/gtfs_to_mock.py                          # sin dependencias
flutter test test/core/models/mock_dataset_test.dart # 24 verificaciones
```

Es determinista: dos corridas seguidas producen el mismo byte. Qué campo viene del feed, cuál se
derivó y cuál está simulado —código de parada, accesibilidad, alertas, itinerarios— está anotado
uno por uno en [`assets/mock/DATASET.md`](assets/mock/DATASET.md).

El test del dataset no es decorativo: caza lo que el feed trae roto. Ya encontró dos cosas —un
`stop_id` con un espacio adelante que dejaba una parada colgando en dos viajes de la R-30, y una
vigencia de calendario vencida en 2025 que habría hecho que la app dijera que no hay servicio
nunca.

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

Los datos de transporte de [`assets/mock/`](assets/mock/) son obra derivada del GTFS del Gobierno
del Estado de Aguascalientes (CMOV), distribuido por el Hub de Datos de Transporte Público de
Codeando México, bajo **CC BY-SA 4.0**. La atribución completa está en
[`assets/mock/LICENSE.txt`](assets/mock/LICENSE.txt) y aparece en la pantalla "Acerca de".
CompartirIgual alcanza a los datos, no al código.

Atribuir una fuente no es afiliarse a ella: el aviso de app independiente sigue en pie.

Identificador de aplicación: `mx.yovoygo.app` (Android e iOS).
