# Requirements — aviso_turno_incompleto

> Feature #21 de `feature_list.json`: Aviso de turno incompleto dentro de
> la app.
>
> Cada requisito está en EARS estricto (ver `docs/specs.md`) y se verifica
> con al menos una prueba concreta. Los ids son estables: en la revisión
> con las respuestas a P1–P5 se reescribieron R9, R27, R29, R30, R31, R34,
> R37 y R39, y se agregaron R40 a R63; no se renumeró nada.
>
> Punto de partida (código actual, ver `design.md`): `Franja` solo tiene
> el texto del horario ("20:00 - 22:00"), sin horas de inicio ni de fin.
> No existe el concepto de "turno incompleto". El inicio
> (`InicioViewModel`) carga los turnos de un mes fijo (`mesDeTurnos`,
> octubre de 2026) y se recarga con cualquier evento del bus. No hay
> nada que recalcule el inicio con el paso del tiempo. Se asume que la
> feature 20 (`guardia_normal_mayores`) ya está: un vecino de 70 años o
> más puede ser patrullero de un turno.
>
> Lo que este spec resuelve (decisiones de la persona, ver `design.md`):
>
> - "Personas anotadas" = patrulleros + guardia de ventana, que cuentan
>   igual. Un turno con **exactamente una** persona está incompleto y no
>   se realiza; con dos o más, se realiza (1 patrullero + 1 guardia de
>   ventana se realiza). Con cero personas no hay a quién avisar.
> - Los horarios de inicio y fin de cada franja pasan a ser un dato del
>   dominio. La Madrugada de la fecha D va de las 00:00 a las 02:00 de
>   D+1 ("la noche del 9 al 10 es la madrugada del 9").
> - **No** hay aviso de una hora antes a todos, **no** hay push, **no**
>   hay temporizador en el servidor y **no** hay notificaciones
>   programadas. Desde 30 minutos antes del inicio y hasta el fin de la
>   franja, el vecino que quedó solo ve una tarjeta en el **inicio** y
>   en la pestaña **Turnos** que le dice que la guardia no se va a hacer.
> - La tarjeta del inicio lleva a la pestaña Turnos. Las dos tienen un
>   botón "Entendido" que oculta el aviso de ese turno.
> - El texto depende del lugar que el vecino ocupa en el turno
>   (patrullero o guardia de ventana), no de su edad.
> - La API y el backend no cambian.
>
> "Ventana de aviso" de un turno: desde 30 minutos antes de su inicio
> (incluido) hasta el fin de su franja (excluido), con la hora del `Reloj`
> de la app (hora local del teléfono). "El vecino" es el vecino con la
> sesión abierta. "Aviso" es la tarjeta de turno incompleto, en el inicio
> o en la pestaña Turnos. "Cerrar un aviso" es tocar su botón
> "Entendido"; "cierre" es lo que queda guardado al hacerlo.

## Regla de turno incompleto (dominio)

## R1
El sistema DEBE contar como personas anotadas de un turno a todos sus
patrulleros más su guardia de ventana, si tiene uno.

## R2
MIENTRAS un turno tiene exactamente una persona anotada (un patrullero
solo o un guardia de ventana solo), el sistema DEBE considerarlo
incompleto y que no se realiza.

## R3
MIENTRAS un turno tiene dos o más personas anotadas (por ejemplo, un
patrullero y un guardia de ventana), el sistema DEBE considerarlo un
turno que se realiza y no incompleto.

## R4
MIENTRAS un turno no tiene ninguna persona anotada, el sistema NO DEBE
considerarlo incompleto.

## Horarios de las franjas (dominio)

## R5
El sistema DEBE fijar el inicio de la franja Temprano de la fecha D a
las 20:00 de D y su fin a las 22:00 de D.

## R6
El sistema DEBE fijar el inicio de la franja Noche de la fecha D a las
22:00 de D y su fin a las 00:00 de D+1.

## R7
El sistema DEBE fijar el inicio de la franja Madrugada de la fecha D a
las 00:00 de D+1 y su fin a las 02:00 de D+1, también cuando D es el
último día del mes o del año.

## R8
El sistema DEBE seguir mostrando el horario de cada franja con los
textos de hoy: "20:00 - 22:00", "22:00 - 00:00" y "00:00 - 02:00".

## Cuándo se ve el aviso (app)

## R9
MIENTRAS el vecino está anotado en un turno incompleto, la hora del
reloj está dentro de la ventana de aviso de ese turno y el vecino no
cerró ese aviso, el sistema DEBE mostrar el aviso de ese turno en el
inicio y en la pestaña Turnos.

## R10
MIENTRAS faltan más de 30 minutos para el inicio de un turno incompleto
del vecino, el sistema NO DEBE mostrar el aviso de ese turno.

## R11
CUANDO la hora del reloj llega al fin de la franja de un turno
incompleto, el sistema DEBE dejar de mostrar el aviso de ese turno.

## R12
MIENTRAS un turno del vecino tiene dos o más personas anotadas, el
sistema NO DEBE mostrar el aviso de ese turno.

## R13
CUANDO la app obtiene del servidor un turno del vecino en el que se
anotó otra persona, el sistema DEBE dejar de mostrar el aviso de ese
turno.

## R14
MIENTRAS el vecino no está anotado en un turno incompleto, el sistema NO
DEBE mostrarle el aviso de ese turno.

## R15
CUANDO el vecino sale de un turno incompleto desde la pestaña Turnos, el
sistema DEBE dejar de mostrar el aviso de ese turno.

## R16
MIENTRAS otra persona sale de un turno del vecino y el vecino queda
como única persona anotada dentro de la ventana de aviso, el sistema
DEBE mostrar el aviso de ese turno a partir de que la app obtiene el
turno actualizado.

## R17
MIENTRAS el vecino tiene más de un turno incompleto dentro de su ventana
de aviso, el sistema DEBE mostrar un aviso por turno, ordenados por la
hora de inicio.

## R18
MIENTRAS no hay una sesión abierta, el sistema NO DEBE mostrar ningún
aviso de turno incompleto.

## R19
El sistema DEBE mostrar el aviso como la primera tarjeta del inicio,
debajo del aviso "Sin conexión" si está y arriba del banner de alertas
activas y de "Tu próximo turno".

## R40
El sistema DEBE mostrar el aviso en la pestaña Turnos debajo del aviso
"Sin conexión" si está y arriba del selector "Todos / Mis turnos", tanto
en la vista del calendario como en la de "Mis turnos".

## R41
MIENTRAS hay avisos de turno incompleto para el vecino, el sistema DEBE
mostrar los mismos avisos, en el mismo orden, en el inicio y en la
pestaña Turnos.

## Tocar el aviso (app)

## R42
CUANDO el vecino toca el aviso del inicio, el sistema DEBE abrir la
pestaña Turnos.

## R43
CUANDO el vecino toca el aviso del inicio de un turno del mes que
muestra el calendario de Turnos, el sistema DEBE mostrar el calendario
(vista "Todos") con el día de ese turno elegido.

## R44
SI el vecino toca el aviso del inicio de un turno de un mes distinto del
que muestra el calendario de Turnos ENTONCES el sistema DEBE abrir la
pestaña Turnos sin cambiar el día elegido ni la vista.

## R45
CUANDO el vecino toca el aviso de la pestaña Turnos fuera del botón
"Entendido", el sistema NO DEBE cambiar de pestaña, de vista ni de día
elegido.

## R46
MIENTRAS se muestra el aviso en el inicio, el sistema DEBE mostrar
debajo del texto la indicación "Tocá para ver tus turnos" con un ícono
de flecha.

## Cerrar el aviso (app)

## R47
MIENTRAS se muestra un aviso de turno incompleto, en el inicio o en la
pestaña Turnos, el sistema DEBE mostrar en él un botón "Entendido".

## R48
CUANDO el vecino toca "Entendido" en el aviso de un turno, el sistema
DEBE dejar de mostrar el aviso de ese turno en el inicio y en la
pestaña Turnos.

## R49
CUANDO el vecino toca "Entendido" en el aviso de un turno, el sistema
DEBE seguir mostrando los avisos de sus otros turnos incompletos.

## R50
MIENTRAS un turno cuyo aviso el vecino cerró sigue incompleto con el
vecino dentro de la ventana de aviso, el sistema NO DEBE volver a
mostrar ese aviso, tampoco después de cerrar y volver a abrir la app.

## R51
CUANDO la app obtiene un turno cuyo aviso el vecino cerró y ese turno
ya no es un turno incompleto del vecino (alguien más se anotó o el
vecino salió), el sistema DEBE borrar ese cierre de las preferencias
del teléfono.

## R52
MIENTRAS un turno cuyo cierre se borró vuelve a estar incompleto con el
vecino dentro de la ventana de aviso, el sistema DEBE mostrar de nuevo
el aviso de ese turno.

## R53
MIENTRAS otro vecino tiene la sesión abierta en el mismo teléfono, el
sistema NO DEBE ocultarle un aviso por un cierre que hizo otro vecino.

## R54
CUANDO la hora del reloj pasa el fin de la franja de un turno cuyo aviso
el vecino cerró, el sistema DEBE borrar ese cierre de las preferencias
del teléfono en el recálculo siguiente.

## R55
SI la app no tiene ningún turno obtenido para calcular los avisos (falló
el pedido y no hay copia) ENTONCES el sistema DEBE conservar los cierres
guardados.

## Recalcular con el paso del tiempo (app)

## R20
MIENTRAS la app está en primer plano, el sistema DEBE recalcular los
avisos de turno incompleto cada 1 minuto con la hora del reloj.

## R21
MIENTRAS el vecino está anotado en algún turno cuya ventana de aviso
incluye la hora del reloj, el sistema DEBE pedirle los turnos al
servidor sin usar la copia en memoria en cada recálculo.

## R22
MIENTRAS el vecino no está anotado en ningún turno cuya ventana de aviso
incluye la hora del reloj, el sistema NO DEBE pedir que se refresquen
los turnos en el recálculo de cada minuto.

## R23
El sistema DEBE calcular los avisos con los turnos del mes de la fecha
de hoy y del mes de la fecha de ayer (para la Madrugada del último día
del mes), según el reloj y no según el mes fijo del calendario de
turnos.

## R24
CUANDO la app vuelve a primer plano, el sistema DEBE recalcular los
avisos de turno incompleto sin esperar al minuto siguiente.

## R25
MIENTRAS la app está en segundo plano, el sistema NO DEBE recalcular los
avisos de turno incompleto.

## R26
SI falla el pedido de turnos de un recálculo ENTONCES el sistema DEBE
calcular los avisos con los últimos turnos que sí obtuvo.

## R27
SI falla el pedido de los turnos de los meses de hoy y de ayer para el
aviso ENTONCES el sistema DEBE mostrar igual el resto del inicio
(alertas y próximo turno) y de la pestaña Turnos (calendario y "Mis
turnos").

## R28
CUANDO un recálculo da los mismos avisos que ya se muestran, el sistema
NO DEBE avisarle a la pantalla que se redibuje.

## Textos (app)

## R29
MIENTRAS se muestra el aviso de un turno incompleto en el que el vecino
es patrullero, el sistema DEBE mostrar el título "Tu guardia no se va a
hacer".

## R30
MIENTRAS se muestra el aviso de un turno incompleto de la franja
Temprano o Noche en el que el vecino es patrullero, el sistema DEBE
mostrar el texto "Sos la única persona anotada en el turno del <día de
la semana> <día> de <mes>, <horario>. Con una sola persona, la guardia
no se hace: no salgas a patrullar." (por ejemplo: "Sos la única persona
anotada en el turno del viernes 9 de octubre, 22:00 - 00:00. Con una
sola persona, la guardia no se hace: no salgas a patrullar.").

## R31
MIENTRAS se muestra el aviso de un turno incompleto de la franja
Madrugada de la fecha D en el que el vecino es patrullero, el sistema
DEBE mostrar el texto "Sos la única persona anotada en el turno del <día
de la semana> <día> de <mes>, 00:00 - 02:00 (la noche del <día de D> al
<día de D+1>). Con una sola persona, la guardia no se hace: no salgas a
patrullar." (por ejemplo: "Sos la única persona anotada en el turno del
viernes 9 de octubre, 00:00 - 02:00 (la noche del 9 al 10). Con una
sola persona, la guardia no se hace: no salgas a patrullar.").

## R56
MIENTRAS se muestra el aviso de un turno incompleto en el que el vecino
es la guardia de ventana, el sistema DEBE mostrar el título "Tu guardia
de ventana no se va a hacer".

## R57
MIENTRAS se muestra el aviso de un turno incompleto de la franja
Temprano o Noche en el que el vecino es la guardia de ventana, el
sistema DEBE mostrar el texto "Nadie se anotó para patrullar en el turno
del <día de la semana> <día> de <mes>, <horario>. Sin patrulla, la
guardia no se hace: no hace falta que vigiles desde tu ventana." (por
ejemplo: "Nadie se anotó para patrullar en el turno del viernes 9 de
octubre, 22:00 - 00:00. Sin patrulla, la guardia no se hace: no hace
falta que vigiles desde tu ventana.").

## R58
MIENTRAS se muestra el aviso de un turno incompleto de la franja
Madrugada de la fecha D en el que el vecino es la guardia de ventana, el
sistema DEBE mostrar el texto "Nadie se anotó para patrullar en el turno
del <día de la semana> <día> de <mes>, 00:00 - 02:00 (la noche del <día
de D> al <día de D+1>). Sin patrulla, la guardia no se hace: no hace
falta que vigiles desde tu ventana.".

## R59
El sistema DEBE elegir el título y el texto del aviso según el lugar que
el vecino ocupa en ese turno (patrullero o guardia de ventana), no según
su edad ni su preferencia de guardia normal.

## Sin avisos fuera de la app

## R32
El sistema NO DEBE mostrar una notificación del sistema por un turno
incompleto.

## R33
El sistema NO DEBE suscribirse a avisos push ni pedirle al servidor
nada más que los turnos para mostrar el aviso de turno incompleto.

## Accesibilidad

## R34
CUANDO aparece el aviso de turno incompleto en la pestaña Turnos, el
sistema DEBE anunciarlo con el lector de pantalla con la etiqueta
"<título>. <texto>" (región en vivo).

## R60
CUANDO aparece el aviso de turno incompleto en el inicio, el sistema
DEBE anunciarlo con el lector de pantalla como un botón con la etiqueta
"<título>. <texto>. Ver turnos" (región en vivo).

## R61
MIENTRAS se muestra el botón "Entendido" de un aviso, el sistema DEBE
anunciarlo con el lector de pantalla como un botón con la etiqueta
"Entendido. Ocultar este aviso".

## R35
MIENTRAS se muestra el aviso de turno incompleto, el sistema DEBE
mostrar un ícono junto al título, de modo que el aviso no se distinga
solo por el color.

## R36
MIENTRAS el texto del sistema está al 200 %, el sistema DEBE mostrar el
aviso de turno incompleto completo (título, texto, indicación y botón
"Entendido"), sin desbordes ni texto cortado, en el inicio y en la
pestaña Turnos.

## R62
MIENTRAS se muestra el aviso de turno incompleto, el sistema DEBE darle
a la parte tocable del aviso del inicio y al botón "Entendido" un
objetivo táctil de al menos 48 x 48 dp.

## R37
MIENTRAS se muestra el inicio con un aviso de turno incompleto, el
sistema DEBE cumplir las guías de accesibilidad del proyecto
(objetivos táctiles de 48 x 48 dp, etiquetas y contraste de texto).

## R63
MIENTRAS se muestra la pestaña Turnos con un aviso de turno incompleto,
el sistema DEBE cumplir las guías de accesibilidad del proyecto
(objetivos táctiles de 48 x 48 dp, etiquetas y contraste de texto).

## Arquitectura

## R38
El sistema DEBE calcular las personas anotadas, el turno incompleto, los
horarios de las franjas, la ventana de aviso, el lugar del vecino en el
turno y la clave de cada cierre en `lib/domain/`, sin importar nada de
Flutter.

## R39
El `TurnoIncompletoViewModel` NO DEBE llegar, directamente ni por sus
`import`, a `dart:ui` ni a ningún `package:flutter/` que no sea
`foundation.dart`.

## Trazabilidad con el `acceptance` de feature_list.json

| Criterio de aceptación | Cubierto por |
|---|---|
| Un turno con una sola persona anotada (contando patrulleros y guardia de ventana) está incompleto y no se realiza; con dos o más personas, sí | R1, R2, R3, R4, R12, R38 |
| La franja Madrugada 00:00 - 02:00 de un día empieza a las 00:00 del día siguiente (la noche del 9 al 10 es la madrugada del 9) | R5, R6, R7, R8, R23, R31, R38, R58 |
| Desde 30 minutos antes del inicio de un turno incompleto, al entrar en la app el vecino anotado ve un aviso de que la guardia no se va a hacer | R9, R10, R11, R16, R17, R19, R20, R23, R24, R25, R26, R27, R28, R29, R30, R31, R39, R40, R41, R42, R43, R44, R45, R46, R47, R48, R49, R50, R52, R54, R55, R56, R57, R58, R59 |
| Si alguien más se anota, el aviso deja de mostrarse | R13, R15, R21, R22, R51 |
| No se avisa a los demás vecinos ni se mandan avisos push | R14, R18, R32, R33, R53 |
| El aviso cumple las reglas de accesibilidad del proyecto | R34, R35, R36, R37, R60, R61, R62, R63 |
| Pruebas en la app | R1 a R63, cada uno con su prueba en `tasks.md` (dominio, preferencias, ViewModel, pantalla, accesibilidad y arquitectura); el backend no cambia |
