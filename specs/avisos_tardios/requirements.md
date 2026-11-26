# Requirements — avisos_tardios

> Feature #16 de `feature_list.json`: Avisos de alertas que llegaron con
> demora.
>
> Cada requisito está en EARS estricto (ver `docs/specs.md`) y se verifica
> con al menos una prueba concreta.
>
> Vocabulario:
> - **Aviso**: la notificación de una alerta de otro vecino que procesa el
>   teléfono, sea por push (app cerrada o en segundo plano,
>   `procesarAvisoPush`) o por el vigilante (app abierta,
>   `VigilanteDeAlertas.revisar`).
> - **Llegada**: el momento en que el teléfono procesa por primera vez el
>   aviso de una alerta, expresado en la hora del servidor (la hora del
>   teléfono corregida por el desfase, ver R3).
> - **Demora**: llegada menos `creada_en` de la alerta.
> - **Aviso a tiempo**: demora de 5 minutos o menos (también si es negativa).
> - **Aviso tardío**: demora de más de 5 minutos y de 2 horas o menos.
> - **Aviso demasiado tardío**: demora de más de 2 horas.
> - **Alerta tardía**: alerta cuya llegada registrada da un aviso tardío o
>   demasiado tardío.
> - **Desfase**: hora del servidor menos hora del teléfono, medido con
>   `GET /salud`.

## Cálculo de la demora

## R1
El sistema DEBE clasificar un aviso como a tiempo si su demora es de 5 minutos o menos (incluida una demora negativa), como tardío si es de más de 5 minutos y hasta 2 horas inclusive, y como demasiado tardío si es de más de 2 horas.

## R2
CUANDO `GET /salud` recibe un pedido, la API DEBE responder 200 con `{"estado": "ok", "ahora": <milisegundos de la hora del servidor>}`.

## R3
CUANDO una comprobación de conexión recibe de `GET /salud` un campo `ahora` numérico, el sistema DEBE guardar en el teléfono el desfase entre esa hora y la hora del teléfono en el punto medio del pedido.

## R4
El sistema DEBE calcular la llegada como la hora del teléfono más el último desfase guardado, o con desfase cero si nunca se guardó uno.

## R5
CUANDO el teléfono procesa por primera vez el aviso de una alerta de otro vecino, no resuelta y con los avisos activos, el sistema DEBE guardar en el teléfono la llegada de esa alerta.

## R6
SI el teléfono ya tenía guardada una llegada para esa alerta ENTONCES el sistema DEBE conservar la primera y clasificar el aviso con ella.

## R7
MIENTRAS los avisos están apagados en el perfil, el sistema NO DEBE guardar la llegada de ninguna alerta.

## Nombre de quien reportó

## R8
La API DEBE incluir en cada alerta que devuelve (`GET /alertas`, `POST /alertas` y `PATCH /alertas/<id>`) el campo `reportada_por_nombre` con el primer nombre de quien la reportó.

## R9
CUANDO se crea una alerta no resuelta, la API DEBE incluir `reportada_por_nombre` en los datos del mensaje push.

## R10
La API NO DEBE agregar a la alerta ni al mensaje push ningún otro dato de quien la reportó (apellido, teléfono, calle, cuadra, fecha de nacimiento o rol).

## R11
El sistema DEBE leer `reportada_por_nombre` del JSON de la API, de los datos del push y de la copia local, y tomarlo como texto vacío si falta.

## R12
CUANDO la app abre una copia local de una versión anterior del esquema, el sistema DEBE agregar la columna `reportada_por_nombre` a la tabla `alertas` sin perder las alertas guardadas.

## Aviso

## R13
CUANDO el aviso de una alerta llega a tiempo, el sistema DEBE mostrar la notificación con el mismo título y cuerpo que antes de esta feature.

## R14
CUANDO el aviso de una alerta es tardío, el sistema DEBE mostrar la notificación con el título "<tipo de alerta> de <nombre de quien la reportó> <hora de la alerta>" y el cuerpo "Llegó con demora por falta de señal. Puede que ya no esté pasando.".

## R15
SI el aviso de una alerta es demasiado tardío ENTONCES el sistema NO DEBE mostrar la notificación.

## R16
El sistema DEBE usar como "<tipo de alerta>" el nombre corto de la categoría: "SOS" (sos), "Actividad sospechosa" (actividad_sospechosa), "Vehículo sospechoso" (vehiculo), "Robo" (robo) y "Ruidos" (ruidos); y, para una alerta de categoría arrebato, el texto `tipo` de la alerta tal como viene (por ejemplo "Arrebato de Marta 15:10" si `tipo` es "Arrebato").

## R17
El sistema DEBE escribir la "<hora de la alerta>" del título como `HH:mm` en 24 horas, en la zona horaria del teléfono, sin fecha aunque la demora cruce la medianoche.

## R18
SI la alerta no trae `reportada_por_nombre` (o viene vacío) ENTONCES el sistema DEBE usar "un vecino" como "<nombre de quien la reportó>" (por ejemplo "SOS de un vecino 15:10").

## R19
CUANDO el vigilante encuentra una alerta nueva de otro vecino con los avisos activos, el sistema DEBE clasificar su aviso y mostrarlo según R13, R14 y R15, igual que un push.

## Lista, mapa y detalle

## R20
MIENTRAS una alerta es tardía, el sistema DEBE mostrar en su tarjeta de la lista del inicio la marca "Llegó con demora. Alerta de las HH:mm", con la hora de `creada_en` en la zona horaria del teléfono.

## R21
SI una alerta tardía no se creó el mismo día (en la zona horaria del teléfono) en que se muestra ENTONCES el sistema DEBE escribir la marca como "Llegó con demora. Alerta del dd/mm a las HH:mm".

## R22
MIENTRAS una alerta es tardía, el sistema DEBE dibujar su pin en el mapa con un distintivo de reloj, además del color y el ícono del estado.

## R23
CUANDO el vecino toca el pin de una alerta tardía en el mapa, el sistema DEBE mostrar la marca de R20 o R21 en el resumen.

## R24
MIENTRAS se muestra el detalle de una alerta tardía, el sistema DEBE mostrar la marca de R20 o R21.

## R25
MIENTRAS una alerta no tiene llegada guardada o su aviso llegó a tiempo, el sistema NO DEBE mostrar la marca ni el distintivo de reloj en la lista, el mapa ni el detalle.

## R26
CUANDO el aviso de una alerta es demasiado tardío, el sistema DEBE mostrar esa alerta en la lista del inicio y en el mapa, con la marca de alerta tardía.

## Accesibilidad

## R27
El sistema DEBE mostrar la marca de alerta tardía con un ícono de reloj y su texto, nunca solo con un color.

## R28
El sistema DEBE incluir el texto de la marca en la etiqueta que lee el lector de pantalla de la tarjeta de la lista y del pin del mapa de una alerta tardía.

## R29
El sistema DEBE mostrar la marca de alerta tardía en la tarjeta, el resumen del mapa y el detalle con el texto al 200 % sin cortarse ni desbordar.

## R30
El sistema DEBE dibujar la marca con colores de texto e ícono registrados en `AppColors.paresDeContraste` que cumplen 4.5:1 (texto) y 3:1 (ícono).

## R31
El sistema DEBE incluir en la leyenda del mapa una muestra del pin con el distintivo de reloj y el texto "Llegó con demora".

## Quién reportó, en el detalle

> Pedido del equipo en la aprobación del spec: "la alerta debe decir el
> nombre de quien la reportó", en el aviso y también en la app. Hoy solo el
> detalle muestra quién reportó; la tarjeta de la lista, el pin y el resumen
> del mapa no lo muestran y siguen sin mostrarlo.

## R32
MIENTRAS se muestra el detalle de una alerta de otro vecino cuyo `reportada_por_nombre` no está vacío, el sistema DEBE mostrar ese nombre en "Reportada por" en lugar de "Un vecino de la zona".

## R33
SI el detalle es de una alerta de otro vecino sin `reportada_por_nombre` (o vacío) ENTONCES el sistema DEBE mostrar "Un vecino" en "Reportada por".

## R34
MIENTRAS se muestra el detalle de una alerta propia, el sistema DEBE mostrar "Vos" en "Reportada por", venga o no `reportada_por_nombre`.

## R35
El sistema DEBE exponer al lector de pantalla "Reportada por" junto con el texto de R32, R33 o R34 como una sola etiqueta, y mostrarlo con el texto al 200 % sin cortarse ni desbordar.

## Trazabilidad con el `acceptance` de feature_list.json

| Criterio de aceptación | Cubierto por |
|---|---|
| Una alerta es tardía si el aviso llega al teléfono más de 5 minutos después de creada | R1, R2, R3, R4, R5, R6, R7 |
| El aviso de una alerta tardía tiene el título "<tipo de alerta> de <nombre de quien la reportó> <hora de la alerta>" (por ejemplo "SOS de Marta 15:10" o "Robo de Marta 15:10") y el cuerpo "Llegó con demora por falta de señal. Puede que ya no esté pasando." | R8, R9, R10, R11, R12, R14, R16, R17, R18, R19 |
| Si el aviso llega más de 2 horas después de creada la alerta, no se muestra la notificación; la alerta igual aparece en la lista y el mapa | R1, R15, R19, R26 |
| En la lista y en el mapa, una alerta tardía figura como tardía con su hora real | R20, R21, R22, R23, R24, R25 |
| Las alertas que llegan a tiempo se avisan igual que hoy | R13, R19, R25 |
| La marca de tardía cumple las reglas de accesibilidad del proyecto | R27, R28, R29, R30, R31 |
| Pruebas del cálculo de tardía, del aviso y de la lista y el mapa | R1–R35 (cada uno con su prueba en `tasks.md`) |
| Pedido del equipo en la aprobación (no está en el `acceptance`): el nombre de quien reportó también se ve en la app | R8, R11, R32, R33, R34, R35 |
