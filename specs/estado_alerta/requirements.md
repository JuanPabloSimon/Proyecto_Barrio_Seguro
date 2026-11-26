# Requirements — estado_alerta

> Feature #19 de `feature_list.json`: Cambiar el estado desde el detalle de
> la alerta.
>
> Cada requisito está en EARS estricto (ver `docs/specs.md`) y se verifica
> con al menos una prueba concreta.
>
> Punto de partida (código actual, ver `design.md`): el detalle solo deja
> **cerrar** la alerta ("Marcar como resuelta" y "Fue una falsa alarma"),
> solo a quien la reportó y solo si no está resuelta; al cerrarla, la
> pantalla se va. `PATCH /alertas/<id>` responde 403 a todos menos a quien
> la reportó (RF-05). El servidor simulado no controla permisos.
>
> Lo que este spec resuelve (ver `design.md`):
>
> - "Puede cambiar el estado" = quien la reportó **o** un miembro de la
>   comisión (`rol: comision`, feature 13). Es la misma regla en la app, en
>   el servidor simulado y en el backend, con el mismo mensaje de error.
>   Esta feature **amplía RF-05**: la comisión pasa a poder cambiar el
>   estado de cualquier alerta.
> - El cambio es libre entre los tres estados, en cualquier dirección,
>   también para reabrir una alerta resuelta ("cambiar su estado entre
>   Activa, En atención y Resuelta").
> - El control es un grupo de tres opciones en el detalle; el detalle
>   **queda abierto** y muestra el estado nuevo.
> - "Marcar como resuelta" se reemplaza por la opción Resuelta del
>   control. "Fue una falsa alarma" se mantiene como hoy (decisión P1).
> - Pasar a Resuelta y reabrir una alerta resuelta piden confirmación;
>   pasar entre Activa y En atención, no (decisión P2).
> - Reabrir una alerta resuelta manda un aviso push al barrio; ningún otro
>   cambio de estado lo manda (decisión P3). La app lo muestra con la app
>   cerrada (push) y con la app abierta (vigilante), con la misma regla de
>   demora que los avisos tardíos.
> - No se guarda ni se muestra quién hizo el último cambio de estado
>   (decisión P4, fuera de alcance).
>
> "Control de estado" es el grupo "Estado de la alerta" del detalle.
> "Vecino común" es un vecino con rol `vecino`. Los nombres visibles de
> los estados son los de `PresentacionEstado.etiqueta`: "Activa", "En
> atención" y "Resuelta".

## Quién ve el control (app)

## R1
MIENTRAS se muestra el detalle de una alerta que reportó el vecino con la
sesión abierta, el sistema DEBE mostrar el control de estado con las
opciones "Activa", "En atención" y "Resuelta", en ese orden.

## R2
MIENTRAS se muestra el detalle de una alerta que reportó otro vecino y el
vecino con la sesión abierta es de la comisión, el sistema DEBE mostrar el
control de estado con las opciones "Activa", "En atención" y "Resuelta".

## R3
MIENTRAS se muestra el detalle de una alerta que reportó otro vecino y el
vecino con la sesión abierta es un vecino común, el sistema NO DEBE
mostrar el control de estado.

## R4
MIENTRAS se muestra el detalle de una alerta, el sistema DEBE mostrar su
estado actual con el ícono y el nombre del estado, para cualquier rol.

## R5
MIENTRAS se muestra el control de estado, el sistema DEBE tener elegida
la opción del estado que la alerta tiene en ese momento.

## R6
MIENTRAS se muestra el detalle de una alerta resuelta a quien la reportó
o a un miembro de la comisión, el sistema DEBE mostrar el control de
estado con las tres opciones habilitadas.

## Cambiar el estado (app)

## R7
CUANDO quien puede cambiar el estado elige en el control "Activa" o "En
atención" en una alerta que está Activa o En atención con otro estado, el
sistema DEBE pedirle al servidor el cambio de esa alerta a ese estado sin
pedir confirmación.

## R8
CUANDO quien puede cambiar el estado elige en el control el estado que la
alerta ya tiene, el sistema NO DEBE pedirle ningún cambio al servidor.

## R9
MIENTRAS se espera la respuesta de un cambio de estado, el sistema DEBE
mostrar las tres opciones deshabilitadas y el indicador "Cambiando el
estado".

## R10
CUANDO el servidor confirma el cambio de estado, el sistema DEBE mostrar
el estado nuevo en el detalle (el estado de arriba y la opción elegida)
sin cerrar el detalle.

## R11
CUANDO el servidor confirma el cambio de estado, el sistema DEBE mostrar
el aviso "Cambiaste el estado a <estado nuevo>." (por ejemplo "Cambiaste
el estado a En atención.").

## Lista y mapa

## R12
CUANDO el servidor confirma el cambio de una alerta a Activa o En
atención, el sistema DEBE mostrarla con el estado nuevo en "Alertas cerca
tuyo" del inicio sin que el vecino tenga que recargar.

## R13
CUANDO el servidor confirma el cambio de una alerta a Resuelta, el
sistema DEBE quitarla de "Alertas cerca tuyo" del inicio sin que el
vecino tenga que recargar.

## R14
CUANDO el servidor confirma el cambio de estado, el sistema DEBE mostrar
el pin de esa alerta en el mapa con el ícono y la etiqueta del estado
nuevo sin que el vecino tenga que recargar.

## R15
CUANDO el servidor confirma el cambio de estado de una alerta propia, el
sistema DEBE mostrarla con el estado nuevo en "Mis alertas" sin que el
vecino tenga que recargar.

## Si el cambio falla (app)

## R16
SI el servidor rechaza el cambio de estado con un mensaje
(`ErrorDelServidor`) ENTONCES el sistema DEBE mostrar ese mensaje tal
cual en el detalle.

## R17
SI el cambio de estado falla por la red ENTONCES el sistema DEBE mostrar
en el detalle el mensaje "No pudimos cambiar el estado. Probá de nuevo."

## R18
SI el cambio de estado falla ENTONCES el sistema DEBE seguir mostrando en
el detalle el estado anterior (arriba y como opción elegida).

## Botones que ya había en el detalle

## R19
El sistema NO DEBE mostrar el botón "Marcar como resuelta" en el detalle
de una alerta (lo reemplaza la opción "Resuelta" del control).

## R20
MIENTRAS se muestra el detalle de una alerta no resuelta que reportó el
vecino con la sesión abierta, el sistema DEBE mostrar el botón "Fue una
falsa alarma", que la deja resuelta, cierra el detalle y muestra
"Cancelaste la alerta: falsa alarma", como hoy.

## API y servidor simulado

## R21
CUANDO `PATCH /alertas/<id>` recibe un estado válido de quien reportó la
alerta, el sistema DEBE guardar el estado nuevo y responder 200 con la
alerta actualizada.

## R22
CUANDO `PATCH /alertas/<id>` recibe un estado válido de un miembro de la
comisión que no reportó la alerta, el sistema DEBE guardar el estado
nuevo y responder 200 con la alerta actualizada.

## R23
SI `PATCH /alertas/<id>` recibe un pedido de un vecino común que no
reportó la alerta ENTONCES el sistema DEBE responder 403 con `{"error":
"Solo quien reportó la alerta o la comisión vecinal pueden cambiar su
estado."}` y no cambiar la alerta.

## R24
CUANDO `PATCH /alertas/<id>` recibe `activa` o `en_atencion` para una
alerta `resuelta` de quien puede cambiarla, el sistema DEBE guardarla con
ese estado.

## R25
CUANDO el servidor simulado recibe un cambio de estado de quien reportó
la alerta o de un miembro de la comisión, el sistema DEBE guardar el
estado nuevo y devolver la alerta actualizada.

## R26
SI el servidor simulado recibe un cambio de estado de un vecino común que
no reportó la alerta ENTONCES el sistema DEBE rechazarlo con
`ErrorDelServidor` y el mismo mensaje que la API, sin cambiar la alerta.

## Accesibilidad

## R27
El sistema DEBE dar a cada opción del control de estado un área tocable
de al menos 48 x 48 dp.

## R28
El sistema DEBE anunciar en el lector de pantalla el encabezado "Estado
de la alerta" y cada opción con su nombre y si está elegida.

## R29
MIENTRAS se muestra el control de estado, el sistema DEBE mostrar cada
opción con el ícono y el nombre del estado, además del color.

## R30
CUANDO aparece un error de cambio de estado, el sistema DEBE anunciarlo
con una región en vivo (`liveRegion`) que muestre un ícono además del
texto.

## R31
MIENTRAS el texto del sistema está al 200 %, el sistema DEBE mostrar el
detalle sin desbordes con el control de estado, con un error de cambio de
estado y sin el control (vecino común).

## R32
El sistema DEBE ordenar la lectura del detalle así: estado actual, título
de la alerta, "Reportada por", "Llamar al 911", "Estado de la alerta" con
sus tres opciones, "Fue una falsa alarma" (si se muestra).

## Confirmación (decisión P2)

## R33
CUANDO quien puede cambiar el estado elige "Resuelta" en una alerta que
no está resuelta, el sistema DEBE mostrar, antes de pedir el cambio, el
diálogo con el título "¿Marcar la alerta como resuelta?", el texto "Va a
dejar de aparecer en "Alertas cerca tuyo". Si hace falta, la podés volver
a abrir desde acá." y los botones "No, dejarla como está" y "Sí, está
resuelta".

## R34
CUANDO quien puede cambiar el estado elige "Activa" o "En atención" en
una alerta resuelta, el sistema DEBE mostrar, antes de pedir el cambio,
el diálogo con el título "¿Volver a abrir la alerta?", el texto "Va a
quedar como <estado elegido> y se les va a avisar a los vecinos del
barrio." (por ejemplo "Va a quedar como En atención y se les va a avisar
a los vecinos del barrio.") y los botones "No, dejarla resuelta" y "Sí,
volver a abrirla".

## R35
CUANDO quien puede cambiar el estado toca "Sí, está resuelta" o "Sí,
volver a abrirla", el sistema DEBE cerrar el diálogo y pedirle al
servidor el cambio de la alerta al estado elegido.

## R36
CUANDO quien puede cambiar el estado cierra el diálogo de confirmación
con "No, dejarla como está", "No, dejarla resuelta", tocando fuera del
diálogo o con el botón Atrás, el sistema NO DEBE pedirle ningún cambio al
servidor.

## R37
CUANDO quien puede cambiar el estado cierra el diálogo de confirmación
sin confirmar, el sistema DEBE seguir mostrando el estado actual arriba y
como opción elegida, sin ningún aviso ni mensaje de error.

## R38
El sistema DEBE dar a cada botón de los diálogos de confirmación de
estado un área tocable de al menos 48 x 48 dp.

## R39
MIENTRAS el texto del sistema está al 200 %, el sistema DEBE mostrar los
dos diálogos de confirmación de estado sin desbordes, con el contenido
desplazable y los botones apilados si no entran en una fila.

## R40
CUANDO se abre un diálogo de confirmación de estado, el sistema DEBE
anunciar en el lector de pantalla su título y cada botón por su texto.

## Aviso push al reabrir: backend (decisión P3)

## R41
CUANDO `PATCH /alertas/<id>` cambia una alerta de `resuelta` a `activa` o
a `en_atencion`, el sistema DEBE enviar un aviso push al tópico `alertas`
con los datos de la alerta actualizada (incluido `reportada_por_nombre`),
`aviso: "reabierta"` y `reabierta_en` (la hora del servidor del cambio, en
milisegundos).

## R42
CUANDO `PATCH /alertas/<id>` guarda un cambio que no sale de `resuelta`
hacia `activa` o `en_atencion` (entre `activa` y `en_atencion`, hacia
`resuelta` o al mismo estado), el sistema NO DEBE enviar ningún aviso
push.

## R43
SI `PATCH /alertas/<id>` rechaza el pedido (400, 401, 403 o 404) ENTONCES
el sistema NO DEBE enviar ningún aviso push.

## R44
SI el servicio de push falla al avisar que se reabrió una alerta ENTONCES
el sistema DEBE guardar igual el estado nuevo y responder 200 con la
alerta actualizada.

## R45
El sistema DEBE armar el aviso push de reapertura solo con las claves de
la alerta (las mismas que el aviso de una alerta nueva), `aviso` y
`reabierta_en`, sin ningún dato de quien la reabrió.

## Aviso de reapertura en la app, con la app cerrada (decisión P3)

## R46
CUANDO llega con la app cerrada o en segundo plano un aviso push de
reapertura de una alerta que reportó otro vecino, con los avisos activos
y hasta 5 minutos después de `reabierta_en` (en hora del servidor), el
sistema DEBE mostrar la notificación con el título "Se reabrió una
alerta: <tipo>" (por ejemplo "Se reabrió una alerta: Robo") y el cuerpo
"<dirección>. Tocá para ver dónde." ("Tocá para ver dónde." si la alerta
no tiene dirección).

## R47
CUANDO llega con la app cerrada o en segundo plano un aviso push de
reapertura de una alerta que reportó otro vecino, con los avisos activos
y más de 5 minutos y hasta 2 horas después de `reabierta_en`, el sistema
DEBE mostrar la notificación con el título "Se reabrió una alerta: <tipo>
<HH:mm de la reapertura>" (por ejemplo "Se reabrió una alerta: Robo
15:10") y el cuerpo "Llegó con demora por falta de señal. Puede que ya no
esté pasando.".

## R48
SI un aviso push de reapertura llega más de 2 horas después de
`reabierta_en` ENTONCES el sistema NO DEBE mostrar ninguna notificación.

## R49
SI llega un aviso push de reapertura de una alerta que reportó el vecino
con la sesión abierta ENTONCES el sistema NO DEBE mostrar ninguna
notificación.

## R50
SI llega un aviso push de reapertura con los avisos apagados en el perfil
ENTONCES el sistema NO DEBE mostrar ninguna notificación.

## R51
SI llega un aviso push de reapertura sin `reabierta_en` válido, con datos
de alerta incompletos o con estado `resuelta` ENTONCES el sistema NO DEBE
mostrar ninguna notificación.

## R52
CUANDO la app procesa un aviso push de reapertura, el sistema NO DEBE
cambiar la llegada guardada del aviso original de esa alerta (la marca de
"tardía" del detalle y de la lista sigue igual).

## Aviso de reapertura en la app, con la app abierta (decisión P3)

## R53
CUANDO, con la app abierta, el vigilante encuentra que una alerta de otro
vecino que estaba resuelta en la revisión anterior ya no lo está y los
avisos están activos, el sistema DEBE mostrar la notificación de
reapertura a tiempo de R46.

## R54
CUANDO, con la app abierta, el vigilante encuentra que una alerta que
estaba resuelta en la revisión anterior ya no lo está, el sistema DEBE
actualizar las pantallas abiertas (inicio, mapa y "Mis alertas") sin que
el vecino tenga que recargar.

## R55
SI el vigilante encuentra reabierta una alerta que reportó el vecino con
la sesión abierta, o los avisos están apagados, ENTONCES el sistema NO
DEBE mostrar la notificación de reapertura.

## Trazabilidad con el `acceptance` de feature_list.json

| Criterio de aceptación | Cubierto por |
|---|---|
| En el detalle de una alerta, quien la reportó y los miembros de la comisión pueden cambiar su estado entre Activa, En atención y Resuelta | R1, R2, R5, R6, R7, R8, R9, R10, R11, R16, R17, R18, R19, R20, R33, R34, R35, R36, R37 |
| Para el resto de los vecinos, el estado se ve pero no se puede cambiar | R3, R4 |
| La API permite el cambio a quien la reportó y a la comisión, y responde 403 al resto | R21, R22, R23, R24, R25, R26, R43 |
| Al cambiar el estado, se actualiza en la lista, el mapa y el detalle | R10, R12, R13, R14, R15, R54 |
| El control de estado cumple las reglas de accesibilidad del proyecto | R9, R27, R28, R29, R30, R31, R32, R38, R39, R40 |
| Pruebas en la app y en el backend para cada rol | R1 a R55 (cada uno con su prueba, ver `tasks.md`; los roles quien la reportó, comisión y vecino común se prueban en el ViewModel, la pantalla, el servidor simulado y el backend) |
| Decisión P2 de la aprobación (no está en el `acceptance`): confirmar al pasar a Resuelta y al reabrir | R7, R33, R34, R35, R36, R37, R38, R39, R40 |
| Decisión P3 de la aprobación (no está en el `acceptance`): aviso push al reabrir una alerta resuelta | R41, R42, R43, R44, R45, R46, R47, R48, R49, R50, R51, R52, R53, R54, R55 |

> P1 a P4 las respondió la persona en la aprobación del spec (ver
> "Decisiones de la aprobación" en `design.md`). P1 y P4 no agregan
> requisitos (P1 deja R20 como estaba; P4 queda fuera de alcance). El
> leader puede sumar P2 y P3 al `acceptance` de `feature_list.json` para
> que queden a la vista; el spec ya las cubre.
