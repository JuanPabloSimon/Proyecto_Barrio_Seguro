# Design — aviso_turno_incompleto

> Decisiones técnicas tomadas antes de escribir código. Se apoya en
> `docs/architecture.md` y `docs/conventions.md`; acá solo va lo que esta
> feature agrega o donde roza sus límites. Contexto de la exploración:
> `progress/explore_turnos_modelo.md` y
> `progress/explore_avisos_programados.md`.
>
> Revisión 2: incorpora las respuestas de la persona a P1–P5 (ver
> "Decisiones tomadas con la persona" al final). El cambio grande es que
> el aviso ya no vive en `InicioViewModel`: se ve en dos pestañas, así
> que tiene su propio ViewModel compartido.

## Punto de partida (código actual, verificado en `feature/guardia_normal_mayores`)

- **Modelo** (`lib/domain/models/turno.dart`): `enum Franja` tiene solo
  `horario` (texto: `'20:00 - 22:00'`, `'22:00 - 00:00'`,
  `'00:00 - 02:00'`) y `desdeNombre`. `Turno` tiene `fecha` (medianoche
  local, `DateTime.parse("2026-10-09")`), `franja`, `patrulleros` y
  `guardiaVentana` (nullable); `vacio`, `incluye(vecino)` (por id) y
  `companierosDe`. No hay horas de inicio ni de fin ni un conteo de
  personas.
- **Vecino** (`lib/domain/models/vecino.dart`): `id`, y con la feature 20
  `guardiaNormal` y `esGuardiaVentanaEn(hoy)` (preferencia para los
  turnos **nuevos**). Esa preferencia no dice qué lugar ocupa en un turno
  ya tomado: eso lo dice `turno.guardiaVentana?.id == vecino.id` (como
  `TurnosViewModel.esGuardiaEn`).
- **Reglas** (`lib/domain/reglas_turnos.dart`): `ReglasTurnos` con
  `maxTurnosPorMes`, `cupoPatrulla`, `edadGuardiaVentana` y
  `motivoNoDisponible`, duplicadas a propósito en
  `backend/lib/src/reglas.dart`. La feature 20 agrega cosas a este
  archivo. Esta feature no lo toca.
- **Repositorio** (`TurnosRepositoryRemoto`): `obtenerTurnos(mes,
  {refrescar})` con un `FuturoConEstado` por mes (memoria); si el pedido
  falla usa la copia de sqflite y marca `sinConexion`; `anotarse` y
  `salir` actualizan la memoria y la copia (`_actualizarCache`). Devuelve
  solo los turnos con al menos un vecino.
- **Preferencias** (`lib/data/services/local/preferencias.dart`): única
  puerta a `shared_preferences` (`SharedPreferencesAsync`), con claves
  como constantes, `todasLasClaves` y lecturas que devuelven un valor
  vacío si el dato no se puede leer (`avisosRecibidos()` es el modelo a
  seguir: JSON en un `String`). `PerfilViewModel` y
  `VigilanteDeAlertas` ya reciben `Preferencias` por constructor; en
  `Dependencias` está `d.preferencias`. Cerrar sesión llama a
  `olvidarVecino()`, no a `olvidarTodo()`.
- **Inicio** (`InicioViewModel` e `InicioScreen`): el ViewModel carga
  alertas y los turnos de `mesDeTurnos` (fijo: `DateTime(2026, 10)`),
  arma `proximoTurno` y se recarga con cualquier evento del bus.
  `_ContenidoInicio` es un `ListView` con, en orden, `AvisoSinConexion`,
  `_BannerAlertas`, `_ProximoTurno` (que ya hace `onIrA(Pestania.turnos)`
  al tocarlo), el mapa, "Reportar alerta", "Llamar al 911" y "Alertas
  cerca tuyo". `InicioScreen` recibe `onIrA`.
- **Turnos** (`TurnosViewModel` y `TurnosScreen`): el ViewModel tiene un
  `mes` fijo (`d.mesDeTurnos`), `dia`, `soloMios`,
  `verEnCalendario(dia)` (pasa a "Todos" y elige el día) y escucha
  `TurnosActualizados`. `_ContenidoTurnos` es un `ListView` con
  `AvisoSinConexion`, el `SegmentedButton` "Todos / Mis turnos",
  `_ResumenCupo` y la vista elegida. `TurnosScreen({viewModel})` se crea
  sola en `test/widget_test.dart` (línea ~717).
- **Armado** (`PrincipalScreen`): crea un ViewModel por pestaña en
  `initState` (`..cargar()`), los muestra en un `IndexedStack` (las dos
  pestañas viven a la vez) y los libera en `dispose`. `_irA(Pestania)`
  cambia de pestaña. El `VigilanteDeAlertas` usa `Timer.periodic` y se
  arma acá; es la referencia para el temporizador.
- **Reloj** (`lib/data/services/reloj.dart`): `RelojDelSistema` (hora
  local del teléfono) y `RelojFijo`; en las pruebas, además, `RelojManual`
  (`test/ayudas/falsos.dart`, hora mutable).
- **Pruebas**: `TurnosFalsos` devuelve la lista entera para cualquier mes
  e ignora `refrescar`. `appDePrueba()` usa `relojDePrueba`
  (`RelojFijo(2026-10-01 12:00)`) sin forma de cambiarlo y
  `preferenciasEnMemoria(...)` (`test/ayudas/bases_de_prueba.dart`). En
  el servidor simulado, Clara (la que ingresa) está en el turno Noche
  del 9/10 con Sofía (patrullera) y Ernesto (guardia de ventana). El
  servidor simulado no controla quién pide `anotarse`/`salir`, así que
  una prueba puede sacar o anotar a Sofía y a Ernesto con
  `dependencias.turnos`.
- **Arquitectura**: `test/unit/arquitectura_test.dart` recorre todos los
  `lib/ui/*/view_models/*.dart` (también uno nuevo) y falla si alguno
  llega a Flutter visual; tiene `importsVisuales(archivo,
  {permitirFoundation})`.

## Decisiones

### 1. Personas anotadas y turno incompleto (dominio)

```
personas anotadas = patrulleros.length + (guardiaVentana != null ? 1 : 0)
incompleto        ⇔ personas anotadas == 1
se realiza        ⇔ personas anotadas >= 2
```

Con 0 personas el turno no es incompleto ni se realiza: no hay a quién
avisar (y el servidor igual no lo devuelve). `personasAnotadas` es un
getter de `Turno`; `estaIncompleto` y `seRealiza` viven en un archivo
nuevo, `lib/domain/turno_incompleto.dart`, junto con la ventana de
aviso, el lugar del vecino en el turno y la clave de cada cierre.

**Por qué un archivo nuevo y no `reglas_turnos.dart`:** las reglas de
`ReglasTurnos` están duplicadas a propósito en el backend porque el
servidor las hace cumplir (principio 6). Esta regla solo la usa la app
para mostrar un aviso: el servidor no rechaza ni cambia nada por ella,
así que no se duplica en `backend/lib/src/reglas.dart`. Además, la
feature 20 cambia `reglas_turnos.dart`; un archivo aparte evita
conflictos.

### 2. Horarios de las franjas (dominio)

Cada `Franja` gana la hora de inicio y si empieza al día siguiente de su
fecha. Todas duran 2 horas. El texto `horario` no cambia (R8).

| Franja | `horaInicio` | `empiezaAlDiaSiguiente` | Inicio (fecha D) | Fin |
|---|---|---|---|---|
| `temprano` | 20 | no | D 20:00 | D 22:00 |
| `noche` | 22 | no | D 22:00 | D+1 00:00 |
| `madrugada` | 0 | sí | D+1 00:00 | D+1 02:00 |

El cálculo usa el constructor de `DateTime` con el día y la hora
"desbordados" (`DateTime(a, m, d + 1, 0)`, `DateTime(a, m, d, 24)`), que
Dart normaliza al día, mes o año siguiente; así no se suman `Duration`
de 24 horas, que fallarían en un cambio de horario. Ejemplos de prueba:
Madrugada del 31/10/2026 → 01/11/2026 00:00 a 02:00; Madrugada del
31/12/2026 → 01/01/2027 00:00.

La hora es la **local del teléfono** (la del `Reloj`, igual que la fecha
del turno, que se parsea a medianoche local). Confirmado por la persona
(P4).

### 3. Ventana de aviso

```
ventana de aviso = [inicio − 30 minutos, fin)
```

`ReglasTurnoIncompleto.estaEnVentanaDeAviso(turno, ahora)`: `ahora` no es
anterior a `inicio − 30 min` **y** es anterior a `fin`. Un turno es
"candidato" a aviso si el vecino está en el turno
(`turno.incluye(vecino)`), el turno está incompleto y `ahora` está en la
ventana (`paraAvisar`). Se **muestra** si además el vecino no lo cerró
(punto 11). Para la Noche del 9: de 21:30 del 9 a 23:59:59 del 9. Para
la Madrugada del 9: de 23:30 del 9 a 01:59:59 del 10.

**Hasta cuándo:** hasta el fin de la franja. Pasado el inicio el vecino
todavía puede estar esperando a alguien o puede abrir la app para ver
qué pasa; al terminar la franja el aviso ya no sirve.

### 4. Dónde se muestra: arriba de todo en el inicio y en Turnos (P1)

**Inicio (R19):** primer elemento de la lista de `_ContenidoInicio`,
después de `AvisoSinConexion` (si está) y antes de `_BannerAlertas` y
`_ProximoTurno`.

**Turnos (R40):** primer elemento de la lista de `_ContenidoTurnos`,
después de `AvisoSinConexion` (si está) y antes del `SegmentedButton`
"Todos / Mis turnos". Está fuera de la vista elegida, así que se ve
igual en el calendario y en "Mis turnos", y no se mueve al cambiar de
día. Es la misma regla de ventana y el mismo recálculo: las dos pestañas
leen el **mismo** ViewModel (punto 6), así que muestran siempre los
mismos avisos (R41) y un "Entendido" en una los oculta en la otra (R48).

- El inicio es lo primero que se ve al abrir la app ("al entrar en la
  app"); en Turnos está lo que el vecino mira para decidir si sale.
- Es una tarjeta, no un diálogo: no tapa el SOS ni interrumpe al lector
  de pantalla. Se anuncia como región en vivo si aparece con la pestaña
  abierta (R34, R60).

Con más de un turno incompleto en ventana (por ejemplo, Temprano y Noche
del mismo día: la ventana de la Noche empieza 21:30, antes de que
termine la Temprano) se muestra una tarjeta por turno, ordenadas por
inicio (R17), en las dos pestañas.

### 5. Qué turnos se miran: los del mes de hoy y los del mes de ayer

El aviso no usa `mesDeTurnos` (fijo en octubre de 2026): usa la fecha
del reloj. Los únicos turnos que pueden estar en ventana son los de
fecha **hoy** (Temprano, Noche y Madrugada, que empieza a las 23:30 de
hoy contando la anticipación) y la Madrugada de **ayer** (hasta las 02:00
de hoy). Se piden los meses de esas dos fechas, sin repetir (casi
siempre es uno solo; el 1.° de cada mes son dos, R23).
`ReglasTurnoIncompleto.mesesParaAvisar(ahora)` devuelve esa lista. El
repositorio ya deduplica por mes, así que si coincide con `mesDeTurnos`
no sale un pedido de más.

### 6. Un ViewModel propio, compartido por las dos pestañas

El aviso tiene su ViewModel, `TurnoIncompletoViewModel`, en una carpeta
nueva `lib/ui/turno_incompleto/` (`view_models/` y `widgets/`). Lo crea
`PrincipalScreen` una vez, como el resto, y se lo pasa a `InicioScreen`
y a `TurnosScreen`. Es el ViewModel de la **tarjeta** del aviso, que es
una parte de pantalla que aparece en dos lugares.

- `InicioViewModel` y la parte de "Tu próximo turno" **no cambian**
  (justo lo que toca la feature 20).
- `TurnosViewModel` solo gana `mostrarTurno(fecha)` (punto 10).
- Un solo temporizador, un solo pedido por minuto y una sola lista de
  cierres: las dos pestañas no pueden quedar en desacuerdo (R41).
- Si fallan los turnos del aviso, el inicio y Turnos siguen con lo suyo
  sin enterarse (R27): son ViewModels distintos.

El ViewModel guarda los últimos turnos de los meses del aviso
(`_turnosDelAviso`, `null` hasta el primer pedido que sale bien), los
cierres (`_cerrados`, un `Set<String>`) y la lista visible (`_avisos`).
Escucha `TurnosActualizados` del bus (lo publican `TurnosViewModel` al
anotarse o salir y `ConexionViewModel` al volver la conexión) y ahí
llama a `cargar()` (R15).

### 7. Recalcular con el paso del tiempo (reloj inyectado, sin paquetes)

Tres caminos llegan a `_recalcular(ahora)`:

1. **`cargar()`** (al crearlo `PrincipalScreen` y con cada
   `TurnosActualizados`): la primera vez lee los cierres de
   `Preferencias`; después pide los turnos de `mesesParaAvisar(ahora)`
   sin refrescar. Si falla, sigue con los últimos turnos que tenía
   (R26). Cuando el vecino sale de un turno desde Turnos, el repositorio
   ya actualizó la memoria y el evento dispara `cargar()` (R15).
2. **`revisar()`** cada minuto (R20), con un `Timer.periodic` de
   `dart:async` (no es Flutter). Si, con los últimos turnos conocidos, el
   vecino está en algún turno cuya ventana incluye `ahora` (incompleto o
   no), pide los meses con `refrescar: true` para ver si alguien se
   anotó o salió (R13, R16, R21); si no, los pide sin refrescar, que
   sale de la memoria (R22). Así la red se usa solo en las 2 h 30 min de
   la ventana de los turnos propios. Si hay un `revisar()` en curso, el
   siguiente no hace nada (`_revisando`).
3. **Volver a primer plano**: `PrincipalScreen` tiene un
   `AppLifecycleListener` (la vista puede; el ViewModel no) que en
   `onPause` llama a `detenerRevision()` (R25) y en `onResume` a
   `revisar()` y `empezarRevision()` (R24), igual que el vigilante.

`_recalcular(ahora)`:

```
u = sesion.usuario
si u == null                → avisos = []                        (R18)
si _turnosDelAviso == null  → avisos = [], cierres sin tocar     (R55)
candidatos = paraAvisar(_turnosDelAviso, u, ahora)
claves     = { claveDeCierre(u, t) para t en candidatos }
si _cerrados tiene claves que no están en claves:
    _cerrados = _cerrados ∩ claves; guardar en Preferencias      (R51, R54)
avisos = candidatos sin los cerrados → AvisoTurnoIncompleto.de(t, u)
notificar solo si cambió la lista de claves de avisos            (R28)
```

Así un tick que no cambia nada no redibuja ni rompe `pumpAndSettle` en
las pruebas. Guardar en `Preferencias` se hace sin bloquear el cálculo
(`unawaited` con `catch` vacío): si falla, el estado en memoria ya es el
correcto y se reintenta en el siguiente recorte.

El temporizador **no** arranca en el constructor: lo arranca
`empezarRevision()` (lo llama `PrincipalScreen` después de `cargar()`).
Así las pruebas que crean el ViewModel no dejan un `Timer` pendiente.
`dispose()` lo cancela y cancela la suscripción al bus.

En las pruebas: `RelojManual` + `revisar()` a mano en las de ViewModel;
en las de widgets (`testWidgets` corre con tiempo falso) se mueve el
reloj y se hace `tester.pump(const Duration(minutes: 1))` para que
dispare el `Timer`.

### 8. "Si alguien más se anota"

Los datos salen del repositorio de turnos con conexión, como hoy. El
otro vecino se anota desde su teléfono; este teléfono se entera en el
recálculo siguiente (como mucho, 1 minuto, porque en la ventana se
refresca) o al volver a primer plano, o con cualquier `cargar()`. No hay
push ni aviso del servidor. Si la conexión se corta, la compuerta tapa
la app (principio 7); si un pedido falla, se sigue con lo último (R26).

### 9. Textos exactos (español rioplatense), según el lugar en el turno (P5)

El lugar sale del **turno**, no de la edad ni de la preferencia del
vecino (R59): `ReglasTurnoIncompleto.esGuardiaVentanaEn(turno, vecino)`
= `turno.guardiaVentana?.id == vecino.id`. Con la feature 20, una
persona de 75 años con la guardia normal activada que quedó sola como
patrullera ve el texto de patrullero; y quien cambió la preferencia
después de anotarse ve el texto del lugar que de verdad ocupa.

`<fecha>` = `'${nombreDia(fecha).toLowerCase()} ${fecha.day} de ${nombreMes(fecha.month)}'`
(con las funciones de `lib/ui/core/formato.dart`, Dart puro): "viernes 9
de octubre", "sábado 31 de octubre". Es la fecha del **turno**, no la del
día en que empieza la Madrugada.

`<cuándo>` = `franja.horario` para Temprano y Noche; para la Madrugada
de la fecha D, `'00:00 - 02:00 (la noche del ${D.day} al ${(D+1).day})'`
(D+1 con `DateTime(a, m, d + 1)`: del 31/10 da "al 1").

**Patrullero solo** (R29, R30, R31):

- Título: `Tu guardia no se va a hacer`
- Texto: `Sos la única persona anotada en el turno del <fecha>, <cuándo>. Con una sola persona, la guardia no se hace: no salgas a patrullar.`

**Guardia de ventana sola** (R56, R57, R58): si quedó sola, no hay
nadie en la calle a quien mirarle la espalda; el texto dice eso y le
saca la tarea, en vez de decirle "sos la única" (que es cierto, pero no
le dice qué hacer).

- Título: `Tu guardia de ventana no se va a hacer`
- Texto: `Nadie se anotó para patrullar en el turno del <fecha>, <cuándo>. Sin patrulla, la guardia no se hace: no hace falta que vigiles desde tu ventana.`

Ejemplos:

- Patrullero, Noche del 9/10: "Sos la única persona anotada en el turno
  del viernes 9 de octubre, 22:00 - 00:00. Con una sola persona, la
  guardia no se hace: no salgas a patrullar."
- Patrullero, Madrugada del 31/10: "Sos la única persona anotada en el
  turno del sábado 31 de octubre, 00:00 - 02:00 (la noche del 31 al 1).
  Con una sola persona, la guardia no se hace: no salgas a patrullar."
- Guardia de ventana, Noche del 9/10: "Nadie se anotó para patrullar en
  el turno del viernes 9 de octubre, 22:00 - 00:00. Sin patrulla, la
  guardia no se hace: no hace falta que vigiles desde tu ventana."
- Guardia de ventana, Madrugada del 9/10: "Nadie se anotó para patrullar
  en el turno del viernes 9 de octubre, 00:00 - 02:00 (la noche del 9 al
  10). Sin patrulla, la guardia no se hace: no hace falta que vigiles
  desde tu ventana."

Textos fijos de la tarjeta:

- Indicación del inicio (R46): `Tocá para ver tus turnos`, con
  `Icons.chevron_right`.
- Botón (R47): `Entendido`.
- Etiquetas del lector: Turnos `'$titulo. $texto'` (R34); inicio
  `'$titulo. $texto. Ver turnos'` (R60, igual que "Tu próximo turno",
  que termina en "Ver turnos"); botón `Entendido. Ocultar este aviso`
  (R61).

Los textos se arman en el ViewModel (`AvisoTurnoIncompleto.de`), como
`ResumenTurno` en el inicio.

### 10. Tocar el aviso del inicio lleva a Turnos, en el día del turno (P2)

`TarjetaTurnoIncompleto` recibe un `onTap` opcional: en el inicio se lo
pasa; en Turnos, no (ahí ya se está en la pestaña; tocar fuera de
"Entendido" no hace nada, R45).

`InicioScreen` gana `onVerTurno` (`ValueChanged<DateTime>`), y el
`onTap` de cada aviso llama a `onVerTurno(aviso.fecha)`.
`PrincipalScreen._verTurno(fecha)`:

```dart
void _verTurno(DateTime fecha) {
  _turnos.mostrarTurno(fecha);
  _irA(Pestania.turnos);
}
```

`TurnosViewModel.mostrarTurno(fecha)`: si `mismoMes(fecha, mes)`, llama a
`verEnCalendario(fecha)` (pasa a "Todos" y elige el día, R43); si no,
no hace nada (R44). El calendario solo muestra `mes`; elegir un día de
otro mes dejaría el `SelectorDia` sin día marcado. Con el mes fijo de
hoy esto pasa solo fuera de octubre de 2026.

**Por qué posicionar en el día:** el vecino llega directo a las tres
franjas de ese día, con la suya y quién más está (o no) anotado, y
puede salir del turno ahí mismo. No se hace scroll hasta la franja: el
día ya queda arriba, debajo del aviso, y mover la lista sola desorienta
con el lector de pantalla.

### 11. "Entendido": un cierre por vecino y turno, guardado en el teléfono (P3)

**Qué cierra:** el aviso de **un** turno (fecha + franja) para el
vecino con la sesión abierta. La clave es
`ReglasTurnoIncompleto.claveDeCierre(vecino, turno)` =
`'<vecino.id>|<aaaa-mm-dd>|<franja.name>'`, por ejemplo
`'v3|2026-10-09|noche'`. Es también la `clave` de
`AvisoTurnoIncompleto`. Con el id del vecino adelante, un cierre de
Clara no le oculta nada a otro vecino que ingrese en el mismo teléfono
(R53).

**Dónde se ve:** el ViewModel es uno solo, así que el aviso desaparece
del inicio y de Turnos a la vez (R48); los avisos de otros turnos siguen
(R49).

**Dónde se guarda:** en `Preferencias`, clave nueva
`avisos_turno_cerrados`, como un JSON de lista de `String` (igual que
`avisos_recibidos`). Sin paquetes nuevos: `shared_preferences` ya está.
Se agrega a `todasLasClaves`. Al reabrir la app, `cargar()` lee los
cierres antes del primer cálculo y el aviso no reaparece (R50).

**Cuándo vuelve a aparecer y cómo se limpia** (una sola regla): en cada
recálculo con turnos obtenidos, se conservan solo los cierres cuya clave
sigue siendo un **candidato** a aviso (turno del vecino, incompleto y
en ventana). Todo lo demás se borra:

- pasó el fin de la franja → ya no es candidato → se borra (R54); así no
  quedan cierres viejos acumulados;
- alguien más se anotó, o el vecino salió → ya no es candidato → se
  borra (R51); si después el turno vuelve a quedar incompleto con el
  vecino dentro de la ventana, el aviso aparece de nuevo (R52), porque
  es una situación nueva: el vecino pudo haber contado con esa compañía;
- cierres de otro vecino → no son candidatos del vecino actual → se
  borran. Eso solo pasa si dos vecinos comparten teléfono dentro de la
  misma ventana; el costo es que el primero vuelve a ver su aviso.

Si nunca se obtuvieron turnos (falla la primera carga y no hay copia),
no se recorta nada (R55): sin datos no se sabe qué sigue vigente.

**Por qué así:** es simple (un `Set<String>` y una intersección, sin
fechas de vencimiento aparte ni tareas de limpieza), no crece (como
mucho, los turnos del vecino en ventana: uno o dos), y respeta la
intención de "Entendido": "ya sé que **esta** situación está así". Si la
situación cambia (alguien se anotó y después se fue), vale la pena
avisar de nuevo. Límite conocido: si alguien se anota y sale entre dos
recálculos (menos de 1 minuto), la app nunca ve el turno completo y el
cierre sigue; para el vecino la situación es la misma que cuando tocó
"Entendido", así que está bien.

`cerrar(aviso)`: agrega la clave a `_cerrados`, recalcula (el aviso se
va en el momento y notifica) y guarda en `Preferencias`. Si guardar
falla, el aviso igual queda oculto mientras la app siga abierta.

### 12. Sin avisos fuera de la app

`TurnoIncompletoViewModel` no recibe `NotificacionesService` ni
`PushService`, y no se agrega ningún método a esos servicios ni al
`VigilanteDeAlertas` (R32, R33). Al resto de los vecinos no les llega
nada: el aviso sale de `turno.incluye(vecino)` con el vecino de la
sesión (R14).

## Archivos a crear o cambiar

| Capa | Archivo | Cambio |
|---|---|---|
| domain | `lib/domain/models/turno.dart` | `Franja`: `horaInicio`, `empiezaAlDiaSiguiente`, `duracionEnHoras`, `inicioEn(fecha)`, `finEn(fecha)`. `Turno`: `personasAnotadas`, `inicio`, `fin`. `horario` sin cambios. |
| domain | `lib/domain/turno_incompleto.dart` (nuevo) | `ReglasTurnoIncompleto` (ver firmas). Sin imports de Flutter. |
| data | `lib/data/services/local/preferencias.dart` | `claveAvisosTurnoCerrados`, `avisosTurnoCerrados()`, `guardarAvisosTurnoCerrados(...)`; la clave entra en `todasLasClaves`. |
| data | `lib/data/repositories/turnos_repository.dart` | Sin cambios. |
| ui | `lib/ui/turno_incompleto/view_models/turno_incompleto_view_model.dart` (nuevo) | `AvisoTurnoIncompleto` y `TurnoIncompletoViewModel`. |
| ui | `lib/ui/turno_incompleto/widgets/tarjeta_turno_incompleto.dart` (nuevo) | `TarjetaTurnoIncompleto` (ver "Accesibilidad"). |
| ui | `lib/ui/inicio/widgets/inicio_screen.dart` | Parámetros `turnoIncompleto` y `onVerTurno`; en `_ContenidoInicio`, un `ListenableBuilder` sobre `turnoIncompleto` con una tarjeta por aviso, después de `AvisoSinConexion` y antes de `_BannerAlertas`. |
| ui | `lib/ui/inicio/view_models/inicio_view_model.dart` | **Sin cambios.** |
| ui | `lib/ui/turnos/view_models/turnos_view_model.dart` | `mostrarTurno(fecha)`. |
| ui | `lib/ui/turnos/widgets/turnos_screen.dart` | Parámetro opcional `turnoIncompleto`; en `_ContenidoTurnos`, un `ListenableBuilder` con una tarjeta por aviso (sin `onTap`), después de `AvisoSinConexion` y antes del `SegmentedButton`. |
| armado | `lib/ui/principal/widgets/principal_screen.dart` | Crea `TurnoIncompletoViewModel(...)..cargar()..empezarRevision()`; lo pasa a `InicioScreen` y `TurnosScreen`; `_verTurno(fecha)`; `AppLifecycleListener` (`onPause` → `detenerRevision`, `onResume` → `revisar` + `empezarRevision`); `dispose` libera las dos cosas. |
| armado | `lib/dependencias.dart` | Sin cambios: ya están `turnos`, `sesion`, `bus`, `reloj` y `preferencias`. |
| backend | `backend/` | Sin cambios (ver "API y datos"). |
| pruebas | `test/ayudas/falsos.dart` | `TurnosFalsos.pedidos` (lista de `(mes, refrescar)`). |
| pruebas | `test/ayudas/app_de_prueba.dart` | `appDePrueba({Reloj? reloj})` (por defecto `relojDePrueba`). |
| pruebas | `test/unit/dominio_test.dart` | Grupos de horarios, personas anotadas, ventana de aviso, lugar en el turno y clave de cierre. |
| pruebas | `test/unit/persistencia_test.dart` | Grupo de los cierres en `Preferencias`. |
| pruebas | `test/unit/view_models_test.dart` | Grupo `Aviso de turno incompleto` y prueba de `TurnosViewModel.mostrarTurno`. |
| pruebas | `test/widget_test.dart` | Grupo `Aviso de turno incompleto` (app completa con servidor simulado y `RelojManual`). |
| pruebas | `test/accesibilidad_test.dart` | Pantallas `Inicio con aviso de turno incompleto` y `Turnos con aviso de turno incompleto` en `pantallas`, y grupo `Aviso de turno incompleto`. |
| pruebas | `test/unit/arquitectura_test.dart` | Prueba de que `turno.dart` y `turno_incompleto.dart` no importan Flutter; la de ViewModels incluye sola el nuevo. |

## Firmas nuevas

```dart
// lib/domain/models/turno.dart
enum Franja {
  temprano('20:00 - 22:00', horaInicio: 20),
  noche('22:00 - 00:00', horaInicio: 22),
  madrugada('00:00 - 02:00', horaInicio: 0, empiezaAlDiaSiguiente: true);

  const Franja(
    this.horario, {
    required this.horaInicio,
    this.empiezaAlDiaSiguiente = false,
  });

  final String horario;

  /// Hora (0 a 23) en que empieza la franja.
  final int horaInicio;

  /// True si la franja de la fecha D empieza el día D+1 (la Madrugada:
  /// la noche del 9 al 10 es la madrugada del 9).
  final bool empiezaAlDiaSiguiente;

  /// Todas las franjas duran 2 horas.
  static const duracionEnHoras = 2;

  /// Inicio de la franja del turno de [fecha], hora local.
  DateTime inicioEn(DateTime fecha);

  /// Fin de la franja del turno de [fecha] (excluido), hora local.
  DateTime finEn(DateTime fecha);

  static Franja? desdeNombre(String nombre); // sin cambios
}

class Turno {
  // … lo de hoy, sin cambios …

  /// Patrulleros más el guardia de ventana, si hay: cuentan igual.
  int get personasAnotadas;

  DateTime get inicio; // franja.inicioEn(fecha)
  DateTime get fin;    // franja.finEn(fecha)
}
```

```dart
// lib/domain/turno_incompleto.dart
import 'models/turno.dart';
import 'models/vecino.dart';

/// Cuándo un turno no se realiza y cuándo se le avisa al vecino que quedó
/// solo. Funciones puras: la hora llega por parámetro.
class ReglasTurnoIncompleto {
  ReglasTurnoIncompleto._();

  /// Desde cuánto antes del inicio se ve el aviso.
  static const anticipacionAviso = Duration(minutes: 30);

  /// Exactamente una persona anotada.
  static bool estaIncompleto(Turno turno);

  /// Dos o más personas anotadas.
  static bool seRealiza(Turno turno);

  /// [ahora] en [inicio − anticipacionAviso, fin).
  static bool estaEnVentanaDeAviso(Turno turno, DateTime ahora);

  /// Los turnos de [turnos] en los que está [vecino], incompletos y en
  /// ventana de aviso, sin repetir (fecha + franja) y ordenados por inicio.
  /// No sabe nada de cierres: eso lo filtra el ViewModel.
  static List<Turno> paraAvisar({
    required Iterable<Turno> turnos,
    required Vecino vecino,
    required DateTime ahora,
  });

  /// True si [vecino] está en algún turno de [turnos] (incompleto o no)
  /// cuya ventana de aviso incluye [ahora]: hay que refrescar.
  static bool tieneTurnoEnVentana({
    required Iterable<Turno> turnos,
    required Vecino vecino,
    required DateTime ahora,
  });

  /// El mes de la fecha de [ahora] y el de la fecha anterior, como
  /// `DateTime(anio, mes)`, sin repetir: [mes de hoy] o [mes de hoy, mes
  /// de ayer].
  static List<DateTime> mesesParaAvisar(DateTime ahora);

  /// True si [vecino] es la guardia de ventana de [turno] (por id). Es el
  /// lugar que ocupa en ese turno, no su edad ni su preferencia.
  static bool esGuardiaVentanaEn(Turno turno, Vecino vecino);

  /// '<vecino.id>|<aaaa-mm-dd>|<franja.name>', por ejemplo
  /// 'v3|2026-10-09|noche'.
  static String claveDeCierre(Vecino vecino, Turno turno);
}
```

```dart
// lib/data/services/local/preferencias.dart, en Preferencias
static const claveAvisosTurnoCerrados = 'avisos_turno_cerrados';
// … y en todasLasClaves.

/// Claves de los avisos de turno incompleto que el vecino cerró con
/// "Entendido". {} si falta o no se puede leer.
Future<Set<String>> avisosTurnoCerrados();

Future<void> guardarAvisosTurnoCerrados(Set<String> claves);
```

```dart
// lib/ui/turno_incompleto/view_models/turno_incompleto_view_model.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
// + turnos_repository, sesion_repository, bus_de_eventos, reloj,
//   preferencias, evento_de_app, models/turno, models/vecino,
//   turno_incompleto, ui/core/formato.dart (Dart puro)

/// Aviso de un turno incompleto, listo para mostrar.
class AvisoTurnoIncompleto {
  const AvisoTurnoIncompleto({
    required this.clave,
    required this.fecha,
    required this.titulo,
    required this.texto,
  });

  /// Arma los textos de `design.md` (punto 9) para [turno], según el
  /// lugar que [vecino] ocupa en él.
  factory AvisoTurnoIncompleto.de(Turno turno, Vecino vecino);

  /// `ReglasTurnoIncompleto.claveDeCierre`: para cerrarlo y para saber si
  /// cambió la lista.
  final String clave;

  /// Fecha del turno, para ir a ese día en Turnos.
  final DateTime fecha;
  final String titulo;
  final String texto;

  /// Para el lector de pantalla: "<titulo>. <texto>".
  String get etiqueta;
}

class TurnoIncompletoViewModel extends ChangeNotifier {
  TurnoIncompletoViewModel({
    required TurnosRepository turnos,
    required SesionRepository sesion,
    required BusDeEventos bus,
    required Reloj reloj,
    required Preferencias preferencias,
    this.cadaCuantoRevisar = const Duration(minutes: 1),
  });

  final Duration cadaCuantoRevisar;

  /// Avisos visibles (candidatos menos cerrados), ordenados por inicio.
  /// Vacía si no hay ninguno o no hay sesión.
  List<AvisoTurnoIncompleto> get avisos;

  /// Lee los cierres (la primera vez), pide los turnos de
  /// `mesesParaAvisar` sin refrescar y recalcula.
  Future<void> cargar();

  /// Vuelve a pedir los turnos (refrescando si el vecino tiene un turno
  /// en ventana) y recalcula. Notifica solo si cambiaron los avisos.
  Future<void> revisar();

  /// "Entendido": oculta ese aviso en todas las pestañas y lo guarda.
  Future<void> cerrar(AvisoTurnoIncompleto aviso);

  /// Arranca el `Timer.periodic` (reemplaza uno anterior).
  void empezarRevision();

  /// Lo detiene (segundo plano). También lo llama `dispose`.
  void detenerRevision();
}
```

```dart
// lib/ui/turno_incompleto/widgets/tarjeta_turno_incompleto.dart
class TarjetaTurnoIncompleto extends StatelessWidget {
  const TarjetaTurnoIncompleto({
    super.key,
    required this.aviso,
    required this.onCerrar,
    this.onTap, // inicio: ir a Turnos; Turnos: null
  });
}
```

```dart
// lib/ui/turnos/view_models/turnos_view_model.dart, en TurnosViewModel
/// Desde el aviso del inicio: si [fecha] es del mes del calendario, pasa
/// a "Todos" y elige ese día; si no, no cambia nada.
void mostrarTurno(DateTime fecha);
```

```dart
// lib/ui/inicio/widgets/inicio_screen.dart
const InicioScreen({
  super.key,
  required this.viewModel,
  required this.dependencias,
  required this.onIrA,
  required this.turnoIncompleto,       // TurnoIncompletoViewModel
  required this.onVerTurno,            // ValueChanged<DateTime>
});

// lib/ui/turnos/widgets/turnos_screen.dart
const TurnosScreen({
  super.key,
  required this.viewModel,
  this.turnoIncompleto,                // opcional: la prueba que crea
});                                    // TurnosScreen sola sigue igual
```

```dart
// test/ayudas/falsos.dart, en TurnosFalsos
/// Cada pedido de `obtenerTurnos`, con su mes y si pidió refrescar.
final List<({DateTime mes, bool refrescar})> pedidos = [];
```

## API y datos

- Rutas nuevas o cambiadas: **ninguna**. El aviso sale de `GET
  /turnos?anio=&mes=`, que ya acepta cualquier mes (el backend valida
  solo `1 ≤ mes ≤ 12`) y devuelve patrulleros y guardia de ventana.
  La regla solo decide qué mostrar en la app; el servidor no rechaza ni
  cambia nada por ella.
- JSON de los modelos: sin cambios (los horarios son del enum, no viajan).
- sqflite: sin cambios (ni tabla ni versión).
- Preferencias locales: una clave nueva, `avisos_turno_cerrados` (JSON
  con una lista de claves). Un dato que no se puede leer cuenta como
  vacío (a lo sumo reaparece un aviso).
- Servidor simulado: sin cambios (ya devuelve cualquier mes).

## Plataforma

No depende de la plataforma: no pregunta nada a `Capacidades` ni a
`Politicas`. No usa notificaciones del sistema ni push. El ciclo de vida
(`AppLifecycleListener`) es el mismo que ya usa el vigilante en todas
las plataformas.

## Accesibilidad

`TarjetaTurnoIncompleto`: una `Card` con fondo `AppColors.superficie`,
borde de 2 dp `AppColors.alerta` y esquinas de 16 dp, con una `Column`:

1. **Parte de información.**
   - En Turnos (sin `onTap`): `Semantics(container: true, liveRegion:
     true, label: aviso.etiqueta, excludeSemantics: true)` (R34), como
     `AvisoSinConexion`.
   - En el inicio (con `onTap`): `Semantics(container: true, liveRegion:
     true, button: true, label: '${aviso.etiqueta}. Ver turnos', onTap:
     onTap, excludeSemantics: true)` sobre un `InkWell` (R60), con la
     línea "Tocá para ver tus turnos" y `Icons.chevron_right` debajo del
     texto (R46). Ocupa todo el ancho y, con el padding de 16 dp y dos
     líneas de texto, mide más de 48 dp de alto; igual se envuelve en
     `ConstrainedBox(minHeight: ObjetivoTactil.tamanioMinimo)` (R62).
   - Adentro, `Row` con `Icon(Icons.event_busy, color: AppColors.alerta,
     size: 32)` junto al título en negrita (R35) y un `Expanded(Column)`
     con título y texto, sin `maxLines` ni alturas fijas: crece hacia
     abajo al 200 % (R36).
2. **Botón "Entendido"** alineado a la derecha, separado de la parte
   tocable (8 dp, `ObjetivoTactil.separacion`): `Semantics(button: true,
   label: 'Entendido. Ocultar este aviso', excludeSemantics: true)` sobre
   un `OutlinedButton(onPressed: onCerrar, child: Text('Entendido'))`
   (R61). El tema le da 64 x 52 dp como mínimo (R62). Es un `Semantics`
   hermano, no hijo, de la parte de información: el `excludeSemantics`
   de esa parte no lo tapa.

- **Contraste (R37, R63):** título, texto e indicación en
  `AppColors.texto` sobre `AppColors.superficie` (par "Texto sobre
  superficie" que ya está en `AppColors.paresDeContraste`). El botón usa
  los colores del tema. No hace falta un par nuevo.
- **SOS:** el botón más alto sigue siendo el SOS (104 dp); "Entendido"
  mide 52 dp, como "Reportar alerta".
- **Orden de lectura (R19, R40):** primero en cada lista (después de
  "Sin conexión"), así el lector lo lee antes que el resto.

## Paquetes nuevos

Ninguno. `Timer` es de `dart:async`; los horarios usan `DateTime`; los
cierres usan `shared_preferences`, que ya está, a través de
`Preferencias`. No se agregan `timezone`, `flutter_timezone`,
`workmanager` ni `fake_async` (las pruebas de tiempo usan `RelojManual`
y el tiempo falso de `testWidgets`).

## Alternativas descartadas

**Temporizador en el servidor + push FCM (enfoque A de la exploración).**
Lo descartó la persona: necesita tópicos o tokens por vecino, solo anda
en Android, no se ve con la app abierta sin `onMessage`, y hay que
persistir qué aviso salió. Además, la feature pide explícitamente sin
push y sin temporizador en el servidor.

**Notificaciones locales programadas (`zonedSchedule`).** Necesita
paquetes nuevos (`timezone`, probablemente `flutter_timezone`),
permisos de alarmas exactas y no puede cancelarse si alguien se anota
con la app cerrada. Descartada por la persona.

**Un diálogo al abrir la app.** Interrumpe, tapa el SOS y, con el lector
de pantalla, corta lo que se estaba leyendo. La tarjeta con "Entendido"
da la misma posibilidad de cerrarlo sin esas contras.

**Lo del aviso dentro de `InicioViewModel` y `TurnosViewModel` (la
versión 1 de este spec, más una copia en Turnos).** Dos temporizadores,
dos pedidos por minuto y dos listas de cierres que había que mantener
iguales; un "Entendido" en una pestaña tenía que avisarle a la otra por
el bus. Además chocaba con la feature 20 en `inicio_view_model.dart`. Un
ViewModel compartido lo resuelve de una vez.

**Cierre que vale hasta el fin de la franja, pase lo que pase.** Más
simple todavía, pero si alguien se anota y después se baja, el vecino
nunca se entera de que volvió a quedar solo. Necesita igual una
limpieza por fecha. La intersección con los candidatos hace las dos
cosas con una regla.

**Guardar los cierres en sqflite.** Pide una tabla y subir la versión de
la base para un conjunto de uno o dos `String`. `Preferencias` ya
guarda datos de este tamaño (`avisos_recibidos`).

**Llevar al día del turno siempre, aunque sea de otro mes.** El
calendario solo muestra `mesDeTurnos`; elegir un día fuera de ese mes
dejaría el selector sin día marcado. Cambiar de mes en Turnos es otra
feature.

**Usar `mesDeTurnos` en vez del mes del reloj.** Más simple, pero no
vería la Madrugada del último día del mes a partir de las 00:00 del 1.°
y no funcionaría con la fecha real fuera de octubre de 2026.

**El temporizador en la pantalla (`StatefulWidget`) en vez del
ViewModel.** La vista quedaría decidiendo cuándo pedir datos y no se
podría probar sin widgets. En el ViewModel, `Timer` es `dart:async` (no
viola MVVM) y la cuenta se prueba con `revisar()`. Solo el ciclo de
vida queda en la vista, porque `AppLifecycleListener` es de
`widgets.dart`.

**Refrescar los turnos en cada minuto siempre.** Haría un pedido por
minuto todo el día. Solo hace falta mientras el vecino tiene un turno en
ventana.

**Elegir el texto por la edad (mayor de 70 = guardia de ventana).** Con
la feature 20 un mayor de 70 puede ser patrullero, y la preferencia
puede cambiar después de anotarse. El lugar en el turno es el dato
cierto.

**Poner la regla en `ReglasTurnos` y duplicarla en el backend.** El
servidor no la usa; duplicarla agregaría código sin prueba de uso y
chocaría con la feature 20 en el mismo archivo.

## Decisiones tomadas con la persona

Respuesta textual: "tambien se ve en la pestaña turnos, si la tarjeta
lleva a turnos, si se puede cerrar con entendido, usa la hora del
telefono, no ve el mismo texto".

- **P1. ¿El aviso se ve también en la pestaña Turnos?** **Sí.** Arriba
  del selector "Todos / Mis turnos", misma regla y mismo recálculo
  (punto 4, R40, R41).
- **P2. ¿La tarjeta lleva a la pestaña Turnos al tocarla?** **Sí**, la
  del inicio, y deja elegido el día del turno si es del mes del
  calendario; la de Turnos no navega (punto 10, R42 a R46, R60, R62).
- **P3. ¿Se puede cerrar ("Entendido")?** **Sí.** Por vecino y turno,
  en las dos pestañas, guardado en el teléfono y olvidado cuando el
  turno deja de estar incompleto o termina (punto 11, R47 a R55, R61).
- **P4. ¿Qué hora manda?** **La del teléfono** (`RelojDelSistema`), sin
  corregir con el desfase del servidor. Un teléfono con la hora mal
  mostraría el aviso antes o después.
- **P5. Texto para la guardia de ventana.** La quinta respuesta ("no ve
  el mismo texto") contesta lo que la versión 1 tenía como P7. Cada
  lugar tiene su texto, según el lugar en el turno y no la edad (punto
  9, R29 a R31, R56 a R59). Lo que la versión 1 llamaba P5 (si otro
  vecino sale y el vecino queda solo, aparece el aviso) queda como
  estaba asumido: **sí** (R16, y R52 con los cierres).

## Preguntas abiertas (con la opción asumida)

- **P6. ¿Cada cuánto se recalcula?** Asumido: cada 1 minuto, con
  refresco desde el servidor solo dentro de la ventana de los turnos
  propios.
- **P7.** Resuelta con P5 (textos distintos para patrullero y guardia de
  ventana).
- **P8. ¿"Tu próximo turno" o la tarjeta de la franja en Turnos cambian
  algo?** Asumido: **no** (siguen "Sin compañero todavía" y lo de hoy).

## Riesgos y notas

- **Feature 20 antes.** Esta feature se implementa después de la 20 y
  asume `Vecino.guardiaNormal`. Ya no toca `inicio_view_model.dart` ni
  `reglas_turnos.dart`; sí toca `inicio_screen.dart`, `turnos_screen.dart`,
  `turnos_view_model.dart` (un método), `principal_screen.dart`,
  `test/ayudas/falsos.dart` y `test/unit/view_models_test.dart`, que
  pueden traer cambios de la 20: partir de lo último.
- **Inicio en error.** El aviso va dentro de `_ContenidoInicio`, que se
  ve solo con el inicio en éxito. Si alertas y turnos del inicio fallan
  sin copia, se ve `MensajeDeError`; en ese caso la compuerta de
  conexión ya tapa la app (principio 7) y en Turnos el aviso igual se
  ve si Turnos cargó.
- **`_resumir` y turnos pasados.** "Tu próximo turno" toma el primero
  del mes aunque ya haya pasado; no es de esta feature y no se cambia.
- **Datos de ejemplo en octubre.** Con `RelojDelSistema` en otro mes, el
  servidor simulado no tiene turnos y no aparece ningún aviso: es lo
  correcto.
- **Segundo plano.** El `Timer` se detiene en `onPause`; si el sistema
  mata la app, al abrirla `cargar()` lee los cierres y recalcula.
- **Prueba con el servidor simulado.** En `testWidgets`, el simulado
  espera `Future.delayed(demora)` aun con `Duration.zero`: para sacar o
  anotar a Sofía y Ernesto desde la prueba, lanzar el pedido, hacer
  `await tester.pump()` y después esperar el `Future`.
- **`excludeSemantics`.** Los `find.text` siguen encontrando los textos
  (buscan widgets); las pruebas de semántica buscan por la etiqueta
  completa. "Entendido" se busca con `find.text('Entendido')` o por su
  etiqueta.
- **`IndexedStack`.** Inicio y Turnos están montados a la vez: con un
  aviso hay dos tarjetas en el árbol. En las pruebas de la app completa,
  buscar dentro de la pestaña visible (`find.descendant` de
  `InicioScreen` o `TurnosScreen`) o con `skipOffstage: true` (el
  valor por defecto de `find.text`).
