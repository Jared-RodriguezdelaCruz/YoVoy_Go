# Features propuestas

Ampliación del [spec](YOVOY_GO_SPEC.md), no parte de él. El spec define las seis pantallas y el
contrato de datos; este documento propone **qué hace la app por el usuario dentro de esas
pantallas** y en qué fase del [roadmap](ROADMAP.md) entra cada cosa.

Regla que se respeta en todo: **nada de esto necesita servidor.** El historial y lo aprendido viven
en el teléfono, sin cuenta y sin nube. Cuando una idea sí requiere backend, aparece al final, marcada
como fuera de la v1.

---

## Por qué estas y no otras

Revisé las apps de transporte europeas más usadas. Lo útil no fue copiar lo que hacen bien, sino
leer de qué se quejan sus usuarios: cada queja documentada es, textualmente, la tesis de este
proyecto.

| Queja documentada | Respuesta de Yo Voy Go |
|---|---|
| Moovit: el contador llega a cero y se reinicia en 8 minutos, siempre | Pasados 180 s no hay número, hay estado. Nunca un contador que miente |
| Google Maps muestra el horario como si fuera posición real del vehículo | `EtaConfidence` separa dato en vivo de horario programado, y la diferencia se ve |
| Transit: el modo viaje consume 20 % de batería en 40 minutos | El modo viaje no usa GPS: sigue al camión en el feed que ya está abierto, y se apaga en background |
| Citymapper propone cuatro transbordos cuando existía un camión directo | El planificador ordena por simplicidad antes que por minutos: un transbordo cuesta 10 min |
| Moovit y Citymapper quedan inservibles sin señal | Respaldo offline con su fecha: "horario guardado hace 2 h" |

Y dos cosas que sí vale la pena copiar: el indicador de ocupación de NS (una, dos o tres figuras) y
el tratamiento de accesibilidad de SBB, que la trata como feature de producto y no como nota al pie.

Fuentes: [comparativa Transit / Citymapper / Moovit (2026)](https://unstar.app/blog/transit-citymapper-moovit-google-maps-trainline-public-transit-apps-ranked-2026)
· [Citymapper](https://citymapper.com/?lang=en)
· [indicador de ocupación de NS](https://www.ns.nl/en/travel-information/ns-app/crowd-indicator.html)
· [SBB Inclusive](https://www.sbb.ch/en/travel-information/apps/sbb-inclusive.html)
· [cómo Transit distingue dato en vivo de horario](https://resources.transitapp.com/article/462-trip-updates#display)

---

## 1. ¿Ya me voy?

**El problema.** Nadie quiere saber a qué hora llega el camión. Quiere saber si ya tiene que salir
de su casa. Hoy eso obliga a hacer una resta mental entre el ETA y lo que uno tarda caminando.

**Qué se ve.** Una sola línea grande en la tarjeta de inicio: **"Sal en 6 min"**. Debajo, en
pequeño, de dónde sale el cálculo: "7 min a pie a Bonanza · Ruta 20 llega en 13 min".

**Estados**

| Situación | Qué dice |
|---|---|
| Alcanzas con margen | Sal en 6 min |
| Justo | Sal ya |
| Ya no alcanzas | Vas tarde. El siguiente, en 14 min |
| Dato viejo o sin dato | Sal 7:04 para el horario programado — sin cuenta regresiva |

**Necesita.** Ubicación del usuario, parada objetivo, ETA con su confianza. La velocidad a pie se
asume en 4.5 km/h y el margen de holgura es configurable en ajustes.

**Fase 5 — construida** en `lib/features/map/application/leave_now.dart`. Elige el primer
camión que se alcanza caminando, no el primero de la lista, y camina con un 30 % de rodeo sobre la
línea recta. Con solo horario da una hora de reloj ("Sal 7:12 para el horario"), nunca una cuenta
regresiva. Se apoya en `Freshness.classify`
([`lib/core/config/freshness.dart`](lib/core/config/freshness.dart)): si la clasificación es
`unknown`, esta tarjeta **no** calcula cuenta regresiva. Esa es la regla que la hace confiable.

---

## 2. Mis rutas, aprendidas

**El problema.** Los favoritos manuales los mantiene el usuario, y por eso casi nadie los mantiene.
Pero el patrón existe: la misma ruta, la misma parada, la misma hora, cinco días a la semana.

**Qué se ve.** A las 7:00 de un martes, hasta arriba de la hoja aparece lo que sueles tomar a esa
hora, con la etiqueta "a esta hora sueles tomar". No es un widget aparte: es el orden de la lista.

**Cómo aprende.** Cada vez que el usuario abre el detalle de una parada, activa el modo paradero o
inicia un viaje, se guarda una observación: parada, ruta, día de la semana y franja horaria. El
orden se calcula con frecuencia, cercanía en el tiempo y distancia, con decaimiento para que lo
viejo pese menos.

**Control del usuario.** Lo aprendido se puede fijar u ocultar con un toque, los favoritos manuales
siempre ganan, y en ajustes hay un botón para borrar el historial. Nada sale del teléfono.

**Necesita.** Almacenamiento local con una tabla de observaciones y una función de puntaje en
`lib/core/`.

**Fase 8**, junto con la decisión de persistencia local que el spec dejó abierta.

---

## 3. Modo paradero

**El problema.** Ya estás parado esperando, con el sol de frente y el teléfono en una mano. Una
lista con tipografía de 14 px no sirve ahí.

**Qué se ve.** Una parada, un número enorme, la tira de la ruta y nada más. Fondo al máximo
contraste, pantalla que no se apaga, actualización automática. Un toque desde el detalle de parada
para entrar, un toque para salir.

**Por qué existe.** El spec define un rol tipográfico de 48 px en peso 700 semi condensada para el
número de minutos. Esta es la pantalla donde ese rol tiene sentido.

**Necesita.** Nada nuevo: los mismos arribos del detalle de parada.

**Fase 6 — construida** en `lib/features/stop/presentation/stop_board_screen.dart`, en
`/stop/:id/board`. El protagonista es el primer camión **en vivo**; debajo va la tira desde donde
viene hasta esta parada, a lo más cinco paradas. La pantalla no se apaga (`wakelock_plus`) y se
suelta sola al pasar a segundo plano.

---

## 4. Confiabilidad observada

**El problema.** Todas las apps prometen. Ninguna te dice si esa promesa se cumplió las últimas
veces.

**Qué se ve.** Bajo el nombre de la ruta: **"suele llegar 3 min tarde · según 14 observaciones
tuyas"**. Si la varianza es alta, lo admite en vez de promediar: "irregular, entre 2 y 11 min". Con
menos de un mínimo de observaciones, no dice nada — el silencio es preferible a un dato débil
presentado como fuerte.

**Cómo lo calcula.** El teléfono guarda, por ruta, parada y franja horaria, la diferencia entre lo
que se prometió y la hora en que el vehículo pasó de verdad. Es el mismo historial de la feature 2.

**Por qué importa.** Es lo que una app oficial nunca va a publicar sobre sí misma, y es coherente
con el principio del proyecto: no verse mejor, comportarse mejor.

**Fase 8** para el cálculo, **fase 6** para mostrarlo. **La parte de la fase 6 está construida**:
`ReliabilityNote` y `ReliabilityCopy` en `lib/core/transit/reliability.dart`, que calla con menos de
cinco observaciones. Hoy el historial está vacío y la nota no aparece; la fase 8 lo llena.

---

## 5. Modo viaje

**El problema.** Vas a bordo en una ruta que no conoces y no sabes cuándo bajarte. La alternativa
actual es mirar por la ventana con el mapa abierto, quemando batería.

**Qué se ve.** La tira con las paradas que faltan, el número grande convertido en "faltan 3
paradas", y un aviso cuando toca prepararse para bajar.

**La batería es parte del diseño.** A Transit le critican 20 % de batería en 40 minutos. Aquí la
cadencia de actualización depende de la distancia al destino: cada 60 s cuando faltan muchas
paradas, cada 15 s cuando faltan dos. Al pasar a background, todo se apaga, como ya exige la
sección 7 del spec.

**Necesita.** Ubicación en primer plano y el seguimiento del vehículo.

**Fase 7 — construida** en `lib/features/planner/presentation/ride_screen.dart`, con su lógica en
`application/ride_session.dart`. Se entra desde el detalle de un itinerario con "Empezar viaje".
Dos cosas cambiaron respecto de esta propuesta al construirla:

- **No usa GPS.** Con "Ya me subí" se fija el camión de esa ruta que está en la parada o llegando,
  y el conteo sale de su reporte en el feed, que ya estaba abierto para el mapa. Se ahorra lo que
  más batería gasta, y el modo funciona con el simulador. "Ya me subí" no se habilita si no hay
  un camión cerca: seguir a uno inventado sería peor.
- **La cadencia de 60 s y 15 s no aplica.** El feed reporta cada 30 s y no se puede pedir más
  rápido; sin GPS, no hay nada más que sondear. A cambio, **la pantalla se queda encendida**
  mientras dure el viaje: con la app en segundo plano todo se detiene, y un aviso que no llega
  con la pantalla apagada es peor que no tener aviso.

A las dos paradas dice "Prepárate: bajas en 2 paradas" y vibra; a la una, "Bájate en la
siguiente". Cada aviso suena una sola vez por tramo y se anuncia al lector de pantalla. Con la
señal perdida, el conteo se queda en el último reporte y lo dice.

---

## 6. Frecuencia como respaldo

**El problema.** Cuando no hay dato en vivo, "sin señal" es honesto pero inútil.

**Qué se ve.** **"cada 10–15 min · según horario"** en lugar del número de minutos. No promete un
minuto exacto, que es justo lo que no se puede prometer, pero responde la pregunta real: ¿me toca
esperar dos minutos o veinte?

**Por qué.** Convierte el cuarto estado obligatorio del spec —dato viejo— en información en vez de
en una disculpa.

**El dato ya está.** El feed oficial no publica horarios, publica intervalos, y la fase 4a los
bajó a `assets/mock/frequencies.json` con su modelo `Frequency`. El respaldo se arma con el
intervalo real de la ruta, no con un promedio inventado.

**Fase 6 — construida.** `Arrival` trae `headway`, y `EtaChip` dice "cada 20 min · según horario"
cuando no hay número en vivo. Se redondea a 5 minutos; si el intervalo cae lejos de un múltiplo, da
el rango ("cada 15–20 min"). Una grieta del feed: las 184 frecuencias traen `headway_secs = 1199`,
así que hoy toda la red dice "cada 20 min".

---

## 7. Ocupación

**El problema.** Un camión que viene lleno y no se detiene es peor que un camión que viene tarde.

**Qué se ve.** Una, dos o tres figuras humanas junto al ETA, más la palabra: "va vacío", "va
llenándose", "va lleno". El color acompaña pero nunca carga el significado solo: hay daltonismo, y
hay sol directo.

**Necesita.** `occupancyStatus`, que ya está en el modelo de tiempo real del spec.

**Fase 6 — construida** en `lib/design/components/occupancy_indicator.dart`. El simulador la
reporta con más carga en horas pico y la omite en un 25 % de los reportes, como los feeds reales.
Solo "va lleno" cambia de color.

---

## 8. Accesibilidad como filtro

**El problema.** La accesibilidad suele quedar como un ícono decorativo en la ficha de una parada,
cuando para algunos usuarios es lo primero que necesitan filtrar.

**Qué se ve.** Un interruptor de "solo paradas accesibles" en el mapa y en el planificador, y una
marca en la tira sobre las paradas que lo son.

**Necesita.** `wheelchairBoarding`, que ya está en el modelo de `Stop`.

**Fase 6 — construida** en el mapa y en la tira de la ruta
(`lib/features/map/application/accessibility_filter.dart`). El interruptor se guarda en el
teléfono. Las paradas sin verificar también quedan fuera: quien necesita una rampa no puede apostar
a que haya una. **Fase 7 — construido también en el planificador**: es el mismo interruptor.
Esconde las opciones que suben o bajan en una parada sin verificar y dice cuántas; "Mostrarlas de
todos modos" las enseña esa vez sin apagar el filtro. Con el dataset de hoy ninguna opción de los
pares precocinados pasa, así que ese es el estado que más se va a ver.

---

## 9. Búsqueda única

**El problema.** Casi todas las apps obligan a elegir pestaña —ruta, parada o destino— antes de
saber qué estás buscando.

**Qué se ve.** Un solo campo. Escribes `20` y salen rutas; escribes `Bonanza` y salen paradas;
escribes `Plaza` y salen destinos. Los resultados vienen agrupados por tipo, con el grupo más
probable arriba.

**Fase 5 — construida** en `lib/features/map/application/search_index.dart`. "20" encuentra la
R20N y la R20S, y "1" la R01, porque así se dicen las rutas en voz alta. Sin acentos ni
mayúsculas. Con el dataset real, "Plaza" da paradas primero y "Chicahuales" da un destino.

---

## 10. Offline con fecha

**El problema.** Sin señal, la mayoría de las apps muestran una pantalla vacía o un error genérico.

**Qué se ve.** El contenido que había, más una franja: **"Sin conexión. Horario guardado hace
2 h."** El usuario decide si le sirve.

**Fase 9**, junto con la revisión de los cuatro estados.

---

## Fuera de la v1

Necesitan servidor, y por eso quedan explícitamente fuera. Se anotan para que la arquitectura no
les cierre la puerta:

- **Reportes de la comunidad** — "no pasó", "venía lleno". Requiere backend y moderación.
- **Compartir mi llegada** — mandarle a alguien un enlace con tu ETA en vivo.
- **Avísame cuando esté por llegar** — notificaciones cuando la app está cerrada.
- **Feed GTFS oficial** — cuando exista, sustituye al simulador sin refactorizar la app: para eso
  los modelos son GTFS desde el primer día.

---

## Resumen por fase

| Feature | Fase | Depende de |
|---|---|---|
| Búsqueda única | 5 ✅ | Dataset |
| ¿Ya me voy? | 5 ✅ | Ubicación |
| Modo paradero | 6 ✅ | Detalle de parada |
| Frecuencia como respaldo | 6 ✅ | `Frequency` del dataset |
| Ocupación | 6 ✅ | `occupancyStatus` |
| Accesibilidad como filtro | 6 ✅ · 7 ✅ en el planificador | `wheelchairBoarding` (simulado, ver `assets/mock/DATASET.md`) |
| Confiabilidad observada (mostrar) | 6 ✅ | Historial local |
| Modo viaje | 7 ✅ | Seguimiento de vehículo |
| Mis rutas aprendidas | 8 | Persistencia local |
| Confiabilidad observada (calcular) | 8 | Persistencia local |
| Offline con fecha | 9 | Caché |
