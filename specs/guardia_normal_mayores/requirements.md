# Requirements — guardia_normal_mayores

> Feature #20 de `feature_list.json`: Guardia normal opcional para mayores
> de 70.
>
> Pedido textual de la persona: "la gente mayor de 70 años que hace
> guardia de ventana debe poder tener la opcion en el perfil de habilitar
> la guardia normal si ellos quieren".
>
> Cada requisito está en EARS estricto (ver `docs/specs.md`) y se verifica
> con al menos una prueba concreta.
>
> Punto de partida (código actual, ver `design.md`): el lugar en un turno
> sale solo de la edad. `ReglasTurnos.esGuardiaVentana` (app y backend)
> devuelve verdadero desde los 70 años (`edadGuardiaVentana = 70`); con eso
> la app, el servidor simulado y la API anotan al vecino como
> `guardia_ventana` y nunca en `patrulleros`. No hay ninguna preferencia del
> vecino que lo cambie.
>
> Lo que este spec resuelve (ver `design.md`):
>
> - La preferencia se llama **guardia normal**. Se guarda **en el
>   servidor**, en los datos del vecino, con el campo `guardia_normal`
>   (booleano, `false` por defecto). La app la recibe con el vecino y la
>   guarda con la sesión, igual que el rol (feature 13).
> - "Guardia de ventana" pasa a ser: 70 años o más **y** guardia normal
>   desactivada. Es la misma regla en la app, el servidor simulado y la API.
> - Con la guardia normal activada, el vecino de 70 o más se anota **solo**
>   en la patrulla, con las mismas reglas que el resto (cupo de 2, máximo
>   de 2 turnos por mes). No puede anotarse como guardia de ventana mientras
>   la tenga activada (pregunta abierta P2, opción asumida).
> - Cambiar la opción **no mueve** los turnos que el vecino ya tomó: cada
>   uno sigue en el lugar que ocupa (pregunta abierta P1, opción asumida).
>   La app describe cada turno propio por el lugar que el vecino ocupa en
>   él, no por la preferencia actual.
> - Los menores de 70 no ven la opción, y la API no les deja activarla.
>
> Glosario: "mayor" es un vecino de 70 años o más el día de hoy; "menor"
> es un vecino de menos de 70 años. "Interruptor de guardia normal" es el
> `SwitchListTile` con el título "Hacer guardia normal (patrulla)" de la
> sección "Turnos" del perfil. "Texto del interruptor" es el subtítulo de
> ese interruptor.

## La preferencia en el modelo (app)

## R1
CUANDO la app lee un vecino de un JSON con `"guardia_normal": true`, el
sistema DEBE tratarlo como vecino con la guardia normal activada.

## R2
SI el JSON de un vecino no trae el campo `guardia_normal` o trae un valor
distinto de `true` ENTONCES el sistema DEBE tratarlo como vecino con la
guardia normal desactivada.

## R3
CUANDO la app convierte un vecino a JSON, el sistema DEBE incluir el campo
`guardia_normal` con su valor booleano.

## R4
CUANDO la app restaura la sesión guardada en el teléfono, el sistema DEBE
recuperar el mismo valor de guardia normal que se guardó.

## La regla (app, servidor simulado y API)

## R5
MIENTRAS un vecino es mayor y tiene la guardia normal desactivada, el
sistema DEBE tratarlo como guardia de ventana al anotarlo en un turno.

## R6
MIENTRAS un vecino es mayor y tiene la guardia normal activada, el sistema
DEBE tratarlo como patrullero al anotarlo en un turno.

## R7
MIENTRAS un vecino es menor, el sistema DEBE tratarlo como patrullero al
anotarlo en un turno, con la guardia normal activada o desactivada.

## La opción en el perfil (app)

## R8
MIENTRAS se muestra el perfil de un vecino mayor, el sistema DEBE mostrar
la sección "Turnos" con el interruptor de guardia normal.

## R9
MIENTRAS se muestra el perfil de un vecino menor, el sistema NO DEBE
mostrar el interruptor de guardia normal.

## R10
MIENTRAS se muestra el interruptor de guardia normal, el sistema DEBE
mostrarlo prendido si el vecino tiene la guardia normal activada y apagado
si la tiene desactivada.

## R11
MIENTRAS el interruptor de guardia normal está apagado, el sistema DEBE
mostrar como texto del interruptor "Hacés guardia de ventana desde tu
casa. Los turnos que ya tomaste no cambian."

## R12
MIENTRAS el interruptor de guardia normal está prendido, el sistema DEBE
mostrar como texto del interruptor "Te anotás en la patrulla, como el
resto. Los turnos que ya tomaste no cambian."

## R13
CUANDO el vecino toca el interruptor de guardia normal, el sistema DEBE
pedirle al servidor que guarde la guardia normal con el valor contrario al
que tenía.

## R14
MIENTRAS se espera la respuesta del servidor a un cambio de guardia
normal, el sistema DEBE mostrar el interruptor deshabilitado con el texto
del interruptor "Guardando el cambio".

## R15
CUANDO el servidor confirma el cambio de guardia normal, el sistema DEBE
mostrar el interruptor con el valor nuevo.

## R16
CUANDO el servidor confirma el cambio de guardia normal, el sistema DEBE
mostrar en el perfil "Turnos: patrullaje" si quedó activada y "Turnos:
guardia de ventana" si quedó desactivada.

## R17
CUANDO el servidor confirma el cambio de guardia normal, el sistema DEBE
guardar en el teléfono, con la sesión, el vecino que devolvió el servidor.

## R18
SI el servidor rechaza el cambio de guardia normal con un mensaje
ENTONCES el sistema DEBE mostrar ese mensaje en un aviso.

## R19
SI el pedido de cambio de guardia normal falla sin respuesta del servidor
ENTONCES el sistema DEBE mostrar el aviso "No pudimos guardar el cambio.
Revisá tu conexión y probá de nuevo."

## R20
SI el cambio de guardia normal falla por cualquier motivo ENTONCES el
sistema DEBE dejar el interruptor y la sesión con el valor que tenían.

## R21
CUANDO el vecino guarda cambios desde "Editar datos personales", el
sistema NO DEBE enviar el campo `guardia_normal` en el pedido de
actualización.

## Turnos e inicio (app)

## R22
CUANDO el servidor confirma el cambio de guardia normal, el sistema DEBE
mostrar en la pestaña Turnos, sin que el vecino tenga que recargar, el
botón "Anotarme" en los turnos donde no está si quedó activada y "Anotarme
como guardia de ventana" si quedó desactivada.

## R23
MIENTRAS un vecino mayor con la guardia normal activada ve en la pestaña
Turnos un turno en el que no está y cuya patrulla está completa, el
sistema DEBE mostrar el botón "Anotarme" deshabilitado con el motivo "La
patrulla de este turno ya está completa."

## R24
MIENTRAS un vecino mayor con la guardia normal activada ve en la pestaña
Turnos un turno en el que no está, que ya tiene guardia de ventana y tiene
lugar en la patrulla, el sistema DEBE mostrar el botón "Anotarme"
habilitado.

## R25
MIENTRAS se muestra en "Mis turnos" un turno en el que el vecino es
guardia de ventana, el sistema DEBE describirlo con "Guardia de ventana
desde tu casa", con la guardia normal activada o desactivada.

## R26
MIENTRAS se muestra en "Mis turnos" un turno en el que el vecino está en
la patrulla, el sistema DEBE describirlo con su compañero ("Con <nombre>"
o "Sin compañero todavía"), con la guardia normal activada o desactivada.

## R27
MIENTRAS el inicio muestra el próximo turno del vecino, el sistema DEBE
titularlo "Tu próxima guardia de ventana" si en ese turno es guardia de
ventana y "Tu próximo turno de patrullaje" si está en la patrulla, sin
importar el valor de la guardia normal.

## API

## R28
CUANDO la API devuelve los datos del vecino (al ingresar, al registrarse,
en `GET /vecinos/yo` y en `PUT /vecinos/<id>`), el sistema DEBE incluir el
campo `guardia_normal` con un valor booleano.

## R29
CUANDO alguien se registra con `POST /vecinos`, el sistema DEBE crear la
cuenta con `guardia_normal` en `false`, aunque el pedido traiga otro
valor.

## R30
CUANDO el servidor arranca con un archivo de datos que tiene vecinos sin
`guardia_normal` o con un valor que no es booleano, el sistema DEBE
leerlos con `guardia_normal` en `false`.

## R31
CUANDO el servidor arranca sin archivo de datos, el sistema DEBE cargar
todos los vecinos de ejemplo con `guardia_normal` en `false`.

## R32
CUANDO un vecino mayor pide en `PUT /vecinos/<id>` sus propios datos con
`guardia_normal` booleano, el sistema DEBE guardar ese valor y devolverlo
en la respuesta.

## R33
CUANDO un vecino menor pide en `PUT /vecinos/<id>` sus propios datos con
`"guardia_normal": false`, el sistema DEBE responder 200 con
`guardia_normal` en `false`.

## R34
SI un vecino menor pide en `PUT /vecinos/<id>` `"guardia_normal": true`
ENTONCES el sistema DEBE responder 409 con `{"error": "Solo los vecinos de
70 años o más pueden elegir la guardia normal."}`.

## R35
SI un pedido a `PUT /vecinos/<id>` trae `guardia_normal` con un valor que
no es booleano ENTONCES el sistema DEBE responder 400 con `{"error": "La
opción de guardia normal no es válida."}`.

## R36
SI un pedido a `PUT /vecinos/<id>` es rechazado por `guardia_normal`
ENTONCES el sistema DEBE dejar todos los datos del vecino sin cambios.

## R37
CUANDO un pedido a `PUT /vecinos/<id>` no trae `guardia_normal`, el
sistema DEBE dejar el valor guardado sin cambios.

## R38
CUANDO un vecino mayor con `guardia_normal` en `true` se anota con
`PUT /turnos/<fecha>/<franja>/vecinos/<id>`, el sistema DEBE agregarlo a
`patrulleros` y dejar `guardia_ventana` como estaba.

## R39
CUANDO un vecino mayor con `guardia_normal` en `false` se anota con
`PUT /turnos/<fecha>/<franja>/vecinos/<id>`, el sistema DEBE ponerlo en
`guardia_ventana`.

## R40
SI un vecino mayor con `guardia_normal` en `true` pide anotarse en un
turno con la patrulla completa ENTONCES el sistema DEBE responder 409 con
`{"error": "La patrulla de este turno ya está completa."}`, aunque el
turno no tenga guardia de ventana.

## R41
SI un vecino mayor con `guardia_normal` en `true` pide anotarse y ya
tiene 2 turnos en el mes ENTONCES el sistema DEBE responder 409 con
`{"error": "Ya tenés 2 turnos este mes, que es el máximo permitido."}`.

## R42
CUANDO un vecino cambia `guardia_normal`, el sistema NO DEBE cambiar el
lugar que ocupa en los turnos que ya tomó.

## Servidor simulado (app sin API)

## R43
DONDE la app usa el servidor simulado, el sistema DEBE guardar el
`guardia_normal` booleano que un vecino mayor manda en la actualización de
sus datos y devolverlo.

## R44
DONDE la app usa el servidor simulado, el sistema DEBE rechazar con el
mensaje "Solo los vecinos de 70 años o más pueden elegir la guardia
normal." la actualización de un vecino menor que pide `"guardia_normal":
true`.

## R45
DONDE la app usa el servidor simulado, el sistema DEBE rechazar con el
mensaje "La opción de guardia normal no es válida." una actualización con
`guardia_normal` que no es booleano.

## R46
DONDE la app usa el servidor simulado, el sistema DEBE crear con
`guardia_normal` en `false` a quien se registra, aunque los datos traigan
otro valor.

## Accesibilidad

## R47
MIENTRAS se muestra el perfil de un vecino mayor, el sistema DEBE cumplir
las guías de área tocable (Android e iOS), de etiquetas de lo tocable y de
contraste de texto.

## R48
El sistema DEBE anunciar en el lector de pantalla el interruptor de
guardia normal como interruptor, con el título "Hacer guardia normal
(patrulla)" y su estado prendido o apagado.

## R49
El sistema DEBE anunciar el título de la sección "Turnos" del perfil como
encabezado.

## R50
MIENTRAS el texto del sistema está al 200 %, el sistema DEBE mostrar el
perfil de un vecino mayor sin desbordes, con el interruptor apagado,
prendido y guardando el cambio.

## Trazabilidad con el `acceptance` de feature_list.json

| Criterio de aceptación | Cubierto por |
|---|---|
| En el perfil, un vecino de 70 años o más tiene una opción para habilitar la guardia normal (patrulla); los menores de 70 no la ven | R8, R9, R10, R11, R12, R13, R14, R15, R16, R17, R18, R19, R20, R21 |
| Por defecto la opción está desactivada y el vecino sigue haciendo guardia de ventana | R2, R5, R11, R29, R30, R31, R39, R46 |
| Con la opción activada, al anotarse en un turno ocupa un lugar de la patrulla con las mismas reglas que el resto | R1, R6, R7, R22, R23, R24, R25, R26, R27, R38, R40, R41, R42 |
| La API aplica la misma regla y guarda la preferencia del vecino | R3, R4, R5, R6, R7, R28, R32, R33, R34, R35, R36, R37, R38, R39, R40, R41, R42 (y R43 a R46 para el servidor simulado, que hace de API sin internet) |
| La opción cumple las reglas de accesibilidad del proyecto | R11, R12, R47, R48, R49, R50 |
| Pruebas en la app y en el backend | R1 a R50, cada uno con su prueba en `tasks.md` (las reglas R5 a R7 y R42 se prueban en la app, en el servidor simulado y en el backend) |

> R25 a R27 y R42 salen de la opción asumida en la pregunta abierta P1
> (los turnos ya tomados no se mueven); R23, R24 y R40 salen de la opción
> asumida en P2 (con la opción activada no se anota como guardia de
> ventana). Si la persona cambia alguna de las dos al aprobar, se reescriben
> esos requisitos sin renumerar el resto.
