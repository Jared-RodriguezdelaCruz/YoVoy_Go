# Dirección visual — Yo Voy Go

El **qué** y el **por qué** del producto viven en [`YOVOY_GO_SPEC.md`](YOVOY_GO_SPEC.md); el orden
de construcción en [`ROADMAP.md`](ROADMAP.md). Aquí está **cómo se ve y por qué se ve así**.

---

## La regla

> **El índigo es del sistema. Lo cálido es tuyo.**

El encargo era modernizar el estilo de Yo Voy: que se sienta futurista y a la vez hogareño. Los dos
adjetivos jalan en direcciones opuestas y promediarlos da algo tibio. La salida es que una sola
regla los resuelva, y que además cargue información.

- **El índigo institucional y los cuatro colores de tiempo real son la voz del sistema.** Dónde
  viene el camión, qué tan fresco es el dato, si hay alerta. Frío, preciso, de instrumento.
- **`cantera` marca lo que el teléfono aprendió de ti.** Favoritos, rutas de siempre, "sal en
  6 min", historial. Nada de eso sale del teléfono, y ahora además se ve distinto.

Lo hogareño no es un fondo beige: es que tus cosas tengan otra temperatura que las del sistema. El
color dice **de quién es el dato**, y eso es información, no decoración.

---

## De dónde salió cada color

El spec (§6.2) ordenaba extraer el color institucional con cuentagotas de las unidades o de la app
oficial, y **no inventarlo**. Hecho el 20 de septiembre de 2026, midiendo píxeles:

| Fuente | Color dominante |
|---|---|
| Splash de la app oficial, `com.mx.nrtec.agsstopbus` | `#3A3578` — 583 885 px de 755 200 |
| Ícono de la app oficial en Play | `#3A3578` |
| Fotografía oficial de la Tarjeta Soluciones YoVoy | `#3A3578` |

**Yo Voy no es verde: es índigo.** Las versiones anteriores del spec afirmaban lo contrario y
fijaban un `#00854A` que nadie había medido. Ese verde, además, daba 3.95:1 contra la superficie
oscura: llevaba tres fases sin pasar el piso de 4.5:1 que el propio spec exige.

`cantera` no es institucional y no pretende serlo: es el rosa de la piedra con la que está
construida Aguascalientes, y entra por la regla de arriba, no por la marca.

**Lo que se descartó.** Los acentos neón del wordmark oficial —cian `#10AFE6`, lima `#BDD52F`,
magenta `#EC3B94`, amarillo `#FFD200`— existen y se midieron, pero no se adoptan: acercarían la app
a imitar la identidad oficial, que la §10 del spec prohíbe, y el lima compite con los colores de
estado.

---

## Tokens, con su contraste medido

Los números salen de la misma cuenta que usa la app en
[`lib/design/tokens/contrast.dart`](lib/design/tokens/contrast.dart), y los vigila
`test/design/route_palette_test.dart`.

### Tema oscuro — superficie `#0E1016`

| Token | Hex | Contraste | Para qué |
|---|---|---|---|
| `brand` | `#8179DC` | 5.16:1 | El índigo institucional, aclarado hasta que se lee sobre negro |
| `cantera` | `#E0A98F` | 9.27:1 | Solo lo tuyo |
| `live` | `#3DDC84` | 10.66:1 | Dato fresco, < 60 s |
| `stale` | `#F2B705` | 10.46:1 | Dato viejo, 60–180 s |
| `unknown` | `#7A8A82` | 5.24:1 | Sin dato, > 180 s |
| `alert` | `#E5484D` | 4.86:1 | Alerta de servicio |
| `textPrimary` | `#F2F3F7` | 17.15:1 | |
| `textSecondary` | `#A2A7BD` | 7.97:1 | |
| `surfaceRaised` / `surfaceSunken` / `outline` | `#171A24` / `#080910` / `#2A2E3D` | — | |

### Tema claro — superficie `#F5F6FA`

| Token | Hex | Contraste |
|---|---|---|
| `brand` | `#3A3578` | 9.92:1 — el índigo tal cual sale de la fuente |
| `cantera` | `#8A4B32` | 6.21:1 |
| `live` / `stale` / `unknown` / `alert` | `#0F7A3E` / `#8A6100` / `#5E6C65` / `#C42A2F` | 5.02 / 5.13 / 5.11 / 5.23 |
| `textPrimary` / `textSecondary` | `#0E1016` / `#565C70` | 17.61:1 / 6.15:1 |
| `surfaceRaised` / `surfaceSunken` / `outline` | `#FFFFFF` / `#E7E9F2` / `#C9CDDD` | — |

Dos hex por token y por tema no es capricho: el índigo institucional es oscuro y sobre fondo negro
da 1.74:1. El mismo patrón que ya usaban los cuatro semánticos.

### El riesgo que asumo

`cantera` y `stale` son los dos cálidos del sistema y los separan **26°** de tono. De reojo pueden
confundirse. Se sostienen con una regla dura —**`cantera` jamás aparece en la misma fila que un
estado de frescura**— y con que la frescura nunca depende solo del color: siempre lleva texto e
ícono. Si al verlos en pantalla siguen peleando, se cambia `cantera`, no la regla.

---

## La firma: la tira con luz de recorrido

[`RouteStrip`](lib/design/components/route_strip.dart) es el elemento por el que se debe recordar
la app. La línea de ruta con las paradas como marcas y el vehículo como bloque:

```
Bonanza    Héroes     CBTIS         TÚ        Centro
  ●━━━━━━━━━●━━━━━━━━━●━━━━█▸━━━━━━━━●━━━━━━━━━●
  └──── cantera: ya pasó ────┘└─ índigo: lo que falta ─┘
                           halo
```

- **Lo recorrido va en `cantera`.** Es pasado, es tibio, es de donde vienes.
- **Lo que falta va en el índigo de marca.** Es sistema, es futuro, es lo que promete.
- **El vehículo es la frontera**, con un halo encendido.

Y cuando el dato vence, **la luz se apaga**: se va el halo, el índigo se vuelve gris y el trazo se
puntea. La metáfora hace legible el estado sin una palabra extra —pero el texto se queda, porque
hay daltonismo y hay sol directo.

---

## Superficies encendidas, cero sombras

El spec prohíbe las sombras (§6.4) y tiene razón: en tema oscuro la sombra gris no comunica nada y
cuesta render. Pero prohibir la sombra no obliga a que todo sea plano.

[`LitSurface`](lib/design/components/lit_surface.dart) ilumina los paneles elevados: un gradiente
vertical de 4 % que baja desde el borde superior, más un filo de 1 px un punto más claro. Un
tablero encendido, una lámpara en un cuarto. Es futurista y hogareño con el mismo gesto, y en
render cuesta un `LinearGradient`: cero `saveLayer`, cero `BackdropFilter`, nada de lo que prohíbe
la §7.

---

## Tipografía: tres anchos de Barlow

| Rol | Fuente | Por qué |
|---|---|---|
| Contador de minutos | **Barlow Condensed 700**, tracking −2 % | Condensada y apretada se lee como instrumento de tablero, no como texto grande |
| Placas de ruta, datos densos | Barlow Semi Condensed | |
| Texto corrido | Barlow | Humanista y redondeada: es la mitad hogareña del encargo |

Sin versalitas, sin ALL CAPS, y los números siempre con `FontFeature.tabularFigures()`.

---

## El mapa: un grabado que se enciende

Cuarenta y ocho rutas a color pleno son un plato de espagueti, y eso es lo que enseñan casi todas
las apps de transporte. Aquí **la red en reposo es un grabado apagado**: delgada y al 30 %. Se ve
que la ciudad tiene rutas, pero ninguna grita. **Solo los camiones van a color pleno.**

Al tocar un camión o buscar una ruta, **esa ruta se enciende** —su grosor según el zoom, su halo,
su color completo— y todo lo demás baja: la red al 15 %, los camiones de otras rutas al 40 %. Es la
misma metáfora que `LitSurface` y `RouteStrip`: la luz marca lo que estás mirando. Y el callout del
camión **es** la tira: ruta, destino, próxima parada y su luz, que se apaga si el dato venció.

El fondo sale de los tokens, no de un tema ajeno:

| Capa | Oscuro | Claro |
|---|---|---|
| Suelo | `surface` `#0E1016` | `surface` `#F5F6FA` |
| Agua | `#0B0F1E`, sunken hacia el índigo | `#DADDEB` |
| Calles menores / mayores | `#191C27` / `outline` `#2A2E3D` | `#FFFFFF` con borde `#E7E9F2` |
| Etiquetas | solo colonias y calles mayores, `textSecondary` al 70 % | igual |
| POIs, íconos, números de casa | ninguno | ninguno |

El suelo del mapa es exactamente la superficie de la app: la hoja inferior sale del mapa, no se
pega encima. Un test lo vigila.

Los grupos de camiones van en los tonos de la superficie, con el número en `textPrimary`. Son un
resumen, no un protagonista: la primera versión llevaba anillo índigo y pesaba más que los camiones
que resumía.

Una limitación que queda: las etiquetas del fondo usan la fuente del sistema, porque
`flutter_map_vector_tiles` no acepta otra familia.

---

## La parada y la ruta

**La parada se lee como el letrero del paradero.** El nombre va grande, en el ancho semi condensado
de los datos. Debajo, el código y cuántas rutas pasan. Luego los arribos, con el `EtaChip` grande:
el número es lo que se busca con la vista. Las alertas van como una franja con un filo en `alert`,
no como una tarjeta roja. Avisan sin empujar los camiones fuera de la pantalla.

**La ruta es la tira, puesta de pie.** Es el riesgo de la fase 6. La lista de paradas no lleva
viñetas: una línea en el color de la ruta baja por el margen, cada parada es una marca (hueca en
medio, llena en las terminales) y cada camión es el mismo bloque rectangular de `RouteStrip`,
dibujado **entre** la parada por la que pasó y la siguiente. La regla de la luz no cambia: con dato
vigente el bloque lleva halo; con el dato vencido el halo se va, el bloque se vuelve gris y el tramo
de delante se puntea. Así la firma deja de ser un componente suelto y se vuelve una pantalla.

El sentido se elige por su destino, "Hacia Margaritas", en el índigo de marca. La estrella de
favorito va en **cantera**: la decidió el usuario.

**La ocupación son figuras más una palabra.** Una, dos o tres personas y "va vacío", "va
llenándose", "va lleno". Solo "va lleno" cambia a `alert`; las otras dos van en `textSecondary`. La
palabra nunca se va, porque el color no carga el significado solo.

**Sin dato en vivo, el chip da la frecuencia**: "cada 20 min · según horario", con el reloj y el
borde apagado. No es un número que se pueda confundir con una promesa.

**La confiabilidad es una línea chica**, "suele llegar 3 min tarde · según 14 observaciones tuyas",
con un ícono de historial en `textSecondary`. No va en cantera aunque sea algo que el teléfono
aprendió: va en la fila del `EtaChip`, y cantera no comparte fila con un estado de frescura.

---

## El modo paradero

Es la pantalla para la que existe el rol del contador. **El número va a 144 pt** en Barlow
Condensed 700 (`AppTypography.etaBoard`), que es `etaDisplay` tres veces más grande, y crece con el
ancho del teléfono. Encima, la placa y "Hacia X"; debajo, la frescura y la ocupación; al pie, la
tira desde donde viene el camión hasta esta parada, y los dos siguientes en una línea.

**El contraste va al máximo, pero sigue el tema del sistema.** Fondo y texto puros: negro y blanco
de noche, blanco y negro de día. De noche no se deslumbra a nadie con una pantalla blanca. No hay
nada más en pantalla: todo el vacío es a propósito, para que el número se encuentre de un vistazo.
Un toque en cualquier parte sale.

---

## El planificador y el modo viaje

**Una opción es una tarjeta que se compara de un vistazo**: la duración en el tamaño del ETA, las
horas a la derecha, y abajo las placas en el orden en que se toman (`RouteSequence`), con la
caminata marcada en las puntas. La línea de abajo dice los transbordos y los metros a pie, que es
lo que más pesa al elegir. Solo la primera tarjeta trae el `EtaChip` en vivo de su primer camión:
el planificador compara viajes, no es un tablero de arribos. Una nota al pie admite que las horas
no cuentan la espera.

**La línea de tiempo es la tira otra vez**, ahora como riel: la caminata punteada en gris y cada
camión sólido en el color de su ruta. El color nunca va solo: cada tramo dice con palabras qué es,
dónde se sube y dónde se baja, y las paradas accesibles llevan ♿.

**"No encontré ruta" no es una disculpa.** El título nombra los dos lugares y abajo va lo que sí se
puede hacer: hasta dónde te acerca un camión y qué rutas pasan cerca de donde estás, cada una con su
placa y un toque para abrirla.

**El modo viaje usa la paleta del modo paradero**, fondo y texto puros
(`design/tokens/max_contrast.dart`), porque se lee igual: con una mano, en movimiento, con el sol
por la ventana. El texto grande son palabras y no un número suelto: "Faltan 3 paradas" se entiende
de un vistazo; un "3", no. El aviso de prepararse va en una franja índigo con ícono y texto, y el
botón de cada paso queda abajo, al alcance del pulgar.

---

## Lo que el teléfono recuerda

**El cálido es de lo tuyo.** `cantera` pinta la estrella de un favorito y nada más: lo que el
usuario decidió se ve distinto de lo que el sistema reporta. Un favorito y una sugerencia usan la
**misma fila del mapa** (`StopTile`, con sus arribos en vivo): guardar una parada no la convierte en
otra cosa, solo la sube.

**Lo aprendido se anuncia en voz baja.** La sección dice "A esta hora sueles tomar" y cada fila
repite la razón en su línea chica, junto al código del poste. La app no presume que adivinó: dice
por qué está ahí y ofrece callarse. Con poco historial la sección no existe —ni un hueco ni un
"todavía no sé"—, igual que la nota de confiabilidad calla con menos de cinco observaciones. **El
silencio es el estado por defecto de todo lo que la app deduce.**

**Ajustes no inventa controles.** Tema y tamaño de texto son chips con la paleta de la app —el chip
de Material se pinta solo de verde y aquí la marca es índigo—; el resto son filas con su ícono, su
verbo y una línea que dice qué va a pasar: cuántos MB se liberan, cuántas observaciones se borran, y
que nada de eso salió nunca del teléfono. "Acerca de" es la única pantalla donde el aviso de app
independiente se lee completo, en cuerpo de texto y no en letra chica.

---

## Avisar sin tapar

Dos franjas nacieron en la fase 9 y comparten forma con `AlertBanner`: un filo de color a la
izquierda, un ícono junto al texto, una línea. No tapan nada, no piden nada y **no se pueden
cerrar**, porque lo que dicen sigue siendo cierto mientras se ve.

**"Sin conexión. El mapa y los horarios son los que ya tenías."** Es el cuarto estado del spec
aplicado a la red entera: el dato no se borra, se marca. No dice "no se pudo cargar" ni ofrece
reintentar, porque lo que está en pantalla sigue sirviendo; solo dejó de refrescarse.

**"Horario del 2 de septiembre de 2025 · su vigencia terminó."** Aparece **una vez por pantalla** y
solo donde algún renglón salió del feed empacado en vez de un camión. Un horario sin fecha se lee
como si fuera de hoy, y este no lo es. Mientras la vigencia vale, la franja va en contorno y no
compite con los arribos; vencida, sube a filo de alerta.

**El ícono nunca es decoración.** Nube tachada y calendario dicen de qué va cada franja sin leer,
que es la misma regla del color: si dos avisos se distinguieran solo por su filo, no se
distinguirían.

---

## Lo que la auditoría cambió

La fase 9 midió cada pantalla en los dos temas. Tres cosas se movieron, y ninguna es cosmética:

- **La letra chica pasó a Medium.** A 13 px, Barlow Regular pierde tanto cuerpo al antialiasear que
  el contraste que llega al ojo cae debajo de 4.5:1, aunque el color nominal dé 8:1. El tamaño no
  cambió: el peso sí.
- **El cuerpo se quedó en Regular.** Subir todo el texto a Medium habría pasado el matcher de un
  golpe y habría cambiado la voz de la app. Los dos casos que faltaban se arreglaron donde estaban:
  la etiqueta de un campo pesa más que su contenido, y el modo viaje —que se lee a un brazo de
  distancia— no lleva Regular en ninguna línea.
- **La atribución del mapa se volvió opaca.** Translúcida sobre calles iba a 3:1. Una obligación
  legal que no se lee no está cumplida.

**Un mapa es un control, no un dibujo.** Se arrastra y se acerca, así que lleva nombre para el
lector de pantalla. Lo que dibuja no se narra: la hoja de abajo y la escalera de paradas ya lo
dicen con palabras, y leer cuarenta marcadores en voz alta sería ruido.

---

## Lo que se descartó, y por qué

- **Neón cian sobre negro con cristal esmerilado.** Es el default de "futurista" y el
  `BackdropFilter` está prohibido por rendimiento.
- **Fondo crema, serif de alto contraste y terracota.** Es el default de "hogareño". `cantera` se
  le parece de lejos, así que la diferencia tiene que ser real: **no es un fondo, es una regla.**
  El cálido aparece únicamente sobre tus datos, nunca como ambiente.
- **Marcadores numerados 01 / 02 / 03.** Aquí no hay secuencia que contar.
- **Redondear la placa de ruta.** La señalética no redondea. Es la herencia literal de las
  unidades y se queda en radio `0`.

---

## Cómo verlo

```bash
flutter run          # y de ahí al ícono de la esquina del mapa → "Ver el design system"
```

`/debug/gallery` monta cada componente en todos sus estados, con interruptor de tema y escala de
texto hasta 200 %. Sin dispositivo, las mismas piezas están fotografiadas en
`test/design/goldens/`, y el mapa, la parada y la ruta en `test/features/{map,stop,route}/goldens/`
—con la hora fija para que la flota salga igual—. Se regeneran con `flutter test --update-goldens`.
