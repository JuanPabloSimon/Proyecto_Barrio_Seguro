# Requirements — sos_mejorado

> Feature #17 de `feature_list.json`: SOS con contexto y confirmaciones.
>
> Cada requisito está en EARS estricto (ver `docs/specs.md`) y se verifica
> con al menos una prueba concreta.
>
> Decisiones ya tomadas por el equipo y que este spec da por fijas:
>
> - La alerta del SOS sigue siendo de categoría `sos` (color, ícono y
>   prioridad de SOS). Lo único que cambia de la alerta es el título
>   (`tipo`), que pasa a ser "Intento de robo".
> - El aviso tardío de la feature 16 sigue diciendo "SOS de <nombre> <hora>".
> - "Volver" cierra la pantalla y deja la alerta activa.
> - "Ya estoy a salvo" y "Fue una falsa alarma" piden confirmación; si se
>   cancela, no cambia nada.
> - Pedido del equipo en la aprobación: el SOS se distingue de un robo en
>   la lista, el mapa, el detalle y el lector de pantalla (R22 a R31), y el
>   informe mensual lo cuenta aparte (R32 a R34). La alerta de robo de
>   ejemplo (`a3`) conserva su título "Intento de robo" (ver `design.md`).
>
> "Pantalla del SOS enviado" es `SosScreen` en el paso `PasoSos.enviada`
> (la vista que muestra "Alerta enviada").

## La alerta que crea el SOS

## R1
CUANDO el vecino toca "Sí, enviar alerta" en la pantalla del SOS, el
sistema DEBE crear una alerta de categoría `sos` con el título (`tipo`)
"Intento de robo".

## R2
CUANDO el vecino toca "Sí, enviar alerta" en la pantalla del SOS, el
sistema DEBE mandar con la alerta la misma ubicación, dirección,
descripción ("Un vecino pidió ayuda con el botón SOS.") y vecino que
reporta (`reportadaPor` = id del vecino con la sesión abierta) que antes de
esta feature.

## R3
CUANDO el servidor recibe la alerta del SOS, el sistema DEBE guardarla en
estado `activa`, con la hora del servidor como `creada_en` y con el título
"Intento de robo" tal como lo mandó la app.

## R4
CUANDO llega con demora el aviso de una alerta de categoría `sos` con
título "Intento de robo", el sistema DEBE titular el aviso tardío
"SOS de <nombre> <hora>" (por ejemplo "SOS de Marta 15:10").

## Volver

## R5
MIENTRAS se muestra la pantalla del SOS enviado, el sistema DEBE mostrar un
botón "Volver" debajo de "Fue una falsa alarma".

## R6
CUANDO el vecino toca "Volver" en la pantalla del SOS enviado, el sistema
DEBE cerrar la pantalla del SOS sin cambiar el estado de la alerta enviada.

## R7
CUANDO el vecino usa el botón Atrás del sistema en la pantalla del SOS
enviado (con conexión), el sistema DEBE hacer lo mismo que "Volver": cerrar
la pantalla del SOS sin cambiar el estado de la alerta enviada.

## R8
CUANDO la pantalla del SOS enviado se cierra con "Volver" o con el botón
Atrás del sistema, el sistema DEBE mostrar en la pantalla que queda el
aviso "Tu alerta sigue activa. La encontrás en Perfil, en "Mis alertas
reportadas"."

## "Ya estoy a salvo"

## R9
CUANDO el vecino toca "Ya estoy a salvo", el sistema DEBE mostrar un
diálogo con el título "¿Ya estás a salvo?", el texto "Tu alerta va a
quedar como resuelta. Si todavía necesitás ayuda, tocá "Seguir con la
alerta"." y los botones "Seguir con la alerta" y "Sí, estoy a salvo".

## R10
CUANDO el vecino toca "Sí, estoy a salvo" en ese diálogo, el sistema DEBE
marcar la alerta enviada como `resuelta`.

## R11
CUANDO la alerta queda resuelta desde "Sí, estoy a salvo", el sistema DEBE
cerrar la pantalla del SOS y mostrar el aviso "Marcaste la alerta como
resuelta".

## R12
SI el vecino cierra el diálogo de "Ya estoy a salvo" sin confirmar (con
"Seguir con la alerta", con el botón Atrás o tocando fuera del diálogo)
ENTONCES el sistema DEBE dejar la pantalla del SOS enviado abierta y la
alerta en estado `activa`, sin pedir ningún cambio de estado.

## "Fue una falsa alarma"

## R13
CUANDO el vecino toca "Fue una falsa alarma", el sistema DEBE mostrar un
diálogo con el título "¿Fue una falsa alarma?", el texto "Tu alerta se va
a cancelar y va a quedar como resuelta. Si de verdad necesitás ayuda, tocá
"Seguir con la alerta"." y los botones "Seguir con la alerta" y "Sí, fue
una falsa alarma".

## R14
CUANDO el vecino toca "Sí, fue una falsa alarma" en ese diálogo, el
sistema DEBE marcar la alerta enviada como `resuelta`.

## R15
CUANDO la alerta queda resuelta desde "Sí, fue una falsa alarma", el
sistema DEBE cerrar la pantalla del SOS y mostrar el aviso "Cancelaste la
alerta: fue una falsa alarma".

## R16
SI el vecino cierra el diálogo de "Fue una falsa alarma" sin confirmar
(con "Seguir con la alerta", con el botón Atrás o tocando fuera del
diálogo) ENTONCES el sistema DEBE dejar la pantalla del SOS enviado abierta
y la alerta en estado `activa`, sin pedir ningún cambio de estado.

## R17
SI falla el cambio de estado después de confirmar "Sí, estoy a salvo" o
"Sí, fue una falsa alarma" ENTONCES el sistema DEBE cerrar la pantalla del
SOS y mostrar el aviso "No pudimos cerrar la alerta. Hacelo desde "Mis
alertas"." (como hoy).

## Accesibilidad

## R18
El sistema DEBE mostrar la pantalla del SOS enviado y los dos diálogos de
confirmación cumpliendo las guías `androidTapTargetGuideline`,
`iOSTapTargetGuideline`, `labeledTapTargetGuideline` y
`textContrastGuideline` (objetivos táctiles de 48 x 48 dp como mínimo,
todos con etiqueta y con contraste suficiente).

## R19
MIENTRAS el texto del sistema está al 200 %, el sistema DEBE mostrar la
pantalla del SOS enviado (con "Volver") y los dos diálogos de confirmación
sin desbordes, con todos sus botones alcanzables desplazando.

## R20
El sistema DEBE distinguir en cada diálogo el botón de confirmar del de
cancelar por el texto y por la forma (confirmar con relleno, cancelar con
contorno), no solo por el color.

## R21
El sistema DEBE exponer al lector de pantalla el título de cada diálogo de
confirmación y cada uno de sus botones con su texto visible como etiqueta,
y el botón "Volver" con la etiqueta "Volver".

## Distinguir el SOS de un robo (pedido del equipo en la aprobación)

> Como el SOS y una alerta de robo pueden tener el mismo título "Intento de
> robo", la categoría tiene que verse y escucharse. "Marca SOS" es una
> pastilla con el ícono de SOS (`Icons.campaign`) y el texto "SOS".

## R22
El sistema DEBE mostrar la marca SOS en la tarjeta de cada alerta de
categoría `sos`, tanto en la lista de Inicio como en "Mis alertas
reportadas".

## R23
CUANDO el vecino abre el resumen de una alerta de categoría `sos` desde su
pin en el mapa, el sistema DEBE mostrar la marca SOS en ese resumen.

## R24
CUANDO el vecino abre el detalle de una alerta de categoría `sos`, el
sistema DEBE mostrar la marca SOS en el detalle.

## R25
El sistema NO DEBE mostrar la marca SOS en la tarjeta, el resumen del mapa
ni el detalle de una alerta de otra categoría.

## R26
El sistema DEBE anunciar al lector de pantalla la tarjeta de una alerta de
categoría `sos` con una etiqueta que empieza con "Alerta SOS: " seguido del
título en minúsculas (por ejemplo "Alerta SOS: intento de robo, hace 5
minutos, activa. Calle Plantamura. Ver detalle").

## R27
El sistema DEBE anunciar al lector de pantalla el pin del mapa de una
alerta de categoría `sos` con una etiqueta que empieza con "Alerta SOS: "
seguido del título (por ejemplo "Alerta SOS: Intento de robo, activa, Calle
Plantamura. Ver resumen").

## R28
El sistema DEBE anunciar al lector de pantalla el título de una alerta de
categoría `sos` en el resumen del mapa y en el detalle como "SOS: <título>"
(por ejemplo "SOS: Intento de robo").

## R29
El sistema DEBE mantener sin cambios las etiquetas de lector de pantalla de
la tarjeta ("Alerta de <título en minúsculas>, …"), del pin ("Alerta:
<título>, …") y del título en el resumen y el detalle de las alertas que no
son de categoría `sos`.

## R30
El sistema NO DEBE anunciar la marca SOS como un elemento aparte del título
en la tarjeta, el resumen del mapa y el detalle (el lector dice "SOS" una
sola vez por alerta).

## R31
El sistema DEBE mostrar la tarjeta, el resumen del mapa y el detalle de una
alerta de categoría `sos` con la marca SOS cumpliendo las guías
`androidTapTargetGuideline`, `iOSTapTargetGuideline`,
`labeledTapTargetGuideline` y `textContrastGuideline`, y sin desbordes con
el texto del sistema al 200 %.

## Informe mensual: todos los SOS en una fila "SOS" (pedido del equipo en la aprobación)

## R32
CUANDO se calcula el informe de un mes con alertas, el sistema DEBE contar
todas las alertas de categoría `sos` del mes, sea cual sea su título, en una
sola fila de "Por tipo" llamada "SOS" (por ejemplo, un SOS "Intento de robo"
y un SOS "Pedido de ayuda (SOS)" dan la fila "SOS · 2"), y NO DEBE sumar a
esa fila ninguna alerta de otra categoría, aunque su título sea "SOS".

## R33
CUANDO se calcula el informe de un mes con alertas, el sistema DEBE seguir
contando en "Por tipo" las alertas que no son de categoría `sos` bajo su
título tal cual, como antes de esta feature (R3 de `informe_alertas`), salvo
la que se titula "SOS" (sin importar mayúsculas ni espacios al borde), que
se cuenta bajo "<título> (<categoría>)" (por ejemplo "SOS (Robo)") para que
su fila no se confunda con la de R32.

## R34
CUANDO un miembro de la comisión descarga el CSV de un mes con alertas SOS,
el sistema DEBE incluir en el archivo la fila "Por tipo,SOS,<cantidad>"
(por ejemplo "Por tipo,SOS,2") y ninguna fila "Por tipo" que empiece con
"SOS: ".

## Trazabilidad con el `acceptance` de feature_list.json

| Criterio de aceptación | Cubierto por |
|---|---|
| El botón SOS crea una alerta de categoría SOS con el título "Intento de robo" (con ubicación, hora y quien la reportó, como hoy) | R1, R2, R3, R4 |
| En la pantalla del SOS enviado hay una opción Volver que cierra la pantalla y deja la alerta activa | R5, R6, R7, R8 |
| "Ya estoy a salvo" pide confirmación antes de marcar la alerta como resuelta; si se cancela, no cambia nada | R9, R10, R11, R12, R17 |
| "Fue una falsa alarma" pide confirmación antes de marcarla; si se cancela, no cambia nada | R13, R14, R15, R16, R17 |
| Las confirmaciones y el botón Volver cumplen las reglas de accesibilidad del proyecto | R18, R19, R20, R21 |
| Pruebas del ViewModel y de la pantalla | R1, R2, R6, R10, R12, R14, R16, R17 (ver `tasks.md`: cada `R<n>` tiene su prueba de ViewModel o de pantalla) |
| Pedido del equipo en la aprobación: una alerta SOS se distingue de una de robo en la lista, el mapa y el detalle, también para el lector de pantalla | R22, R23, R24, R25, R26, R27, R28, R29, R30, R31 |
| Pedido del equipo en la aprobación: el informe mensual cuenta todos los SOS en una fila "SOS" de "Por tipo", aparte de los robos y del resto | R32, R33, R34 |
