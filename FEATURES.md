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
| Transit: el modo viaje consume 20 % de batería en 40 minutos | Polling que se ajusta a la cercanía y se apaga en background |
| Citymapper propone cuatro transbordos cuando existía un camión directo | El planificador ordena por simplicidad antes que por minutos |
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

**Fase 5.** Se apoya en `Freshness.classify`
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

**Fase 6.**

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

**Fase 8** para el cálculo, **fase 6** para mostrarlo.

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

**Fase 7.**

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

**Fase 6.**

---

## 7. Ocupación

**El problema.** Un camión que viene lleno y no se detiene es peor que un camión que viene tarde.

**Qué se ve.** Una, dos o tres figuras humanas junto al ETA, más la palabra: "va vacío", "va
llenándose", "va lleno". El color acompaña pero nunca carga el significado solo: hay daltonismo, y
hay sol directo.

**Necesita.** `occupancyStatus`, que ya está en el modelo de tiempo real del spec.

**Fase 6.**

---

## 8. Accesibilidad como filtro

**El problema.** La accesibilidad suele quedar como un ícono decorativo en la ficha de una parada,
cuando para algunos usuarios es lo primero que necesitan filtrar.

**Qué se ve.** Un interruptor de "solo paradas accesibles" en el mapa y en el planificador, y una
marca en la tira sobre las paradas que lo son.

**Necesita.** `wheelchairBoarding`, que ya está en el modelo de `Stop`.

**Fase 6.**

---

## 9. Búsqueda única

**El problema.** Casi todas las apps obligan a elegir pestaña —ruta, parada o destino— antes de
saber qué estás buscando.

**Qué se ve.** Un solo campo. Escribes `20` y salen rutas; escribes `Bonanza` y salen paradas;
escribes `Plaza` y salen destinos. Los resultados vienen agrupados por tipo, con el grupo más
probable arriba.

**Fase 5.**

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
| Búsqueda única | 5 | Dataset |
| ¿Ya me voy? | 5 | Ubicación |
| Modo paradero | 6 | Detalle de parada |
| Frecuencia como respaldo | 6 | `Frequency` del dataset ✅ |
| Ocupación | 6 | `occupancyStatus` |
| Accesibilidad como filtro | 6 | `wheelchairBoarding` (simulado, ver `assets/mock/DATASET.md`) |
| Confiabilidad observada (mostrar) | 6 | Historial local |
| Modo viaje | 7 | Seguimiento de vehículo |
| Mis rutas aprendidas | 8 | Persistencia local |
| Confiabilidad observada (calcular) | 8 | Persistencia local |
| Offline con fecha | 9 | Caché |
