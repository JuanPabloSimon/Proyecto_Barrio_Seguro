# Requirements — requiere_conexion

> Feature #15 de `feature_list.json`: La app requiere conexión.
>
> Cada requisito está en EARS estricto (ver `docs/specs.md`) y se verifica
> con al menos una prueba concreta.
>
> Vocabulario:
> - **Comprobación de conexión**: un `GET /salud` a la API (ver R2). "Hay
>   conexión" quiere decir que la última comprobación terminada dio bien.
> - **Pantalla sin conexión**: la pantalla `SinConexionScreen` que tapa a
>   todas las demás.

## Detección de la conexión

## R1
CUANDO la app arranca, el sistema DEBE hacer una comprobación de conexión.

## R2
El sistema DEBE dar por buena una comprobación de conexión solo si `GET /salud` de la API responde 200 con el cuerpo JSON `{"estado": "ok"}` en 5 segundos o menos.

## R3
SI la comprobación de conexión falla por la red, se pasa de 5 segundos, responde con un código de error o responde un cuerpo que no es `{"estado": "ok"}` (por ejemplo, la página HTML de un wifi con portal de acceso) ENTONCES el sistema DEBE dar por perdida la conexión.

## R4
SI un pedido de alertas o de turnos al servidor falla por la red ENTONCES el sistema DEBE hacer una comprobación de conexión en ese momento.

## R5
MIENTRAS hay conexión y la app está en primer plano, el sistema DEBE hacer una comprobación de conexión cada 30 segundos.

## R6
MIENTRAS no hay conexión y la app está en primer plano, el sistema DEBE hacer una comprobación de conexión cada 5 segundos.

## R7
CUANDO la app pasa a segundo plano, el sistema DEBE dejar de hacer comprobaciones de conexión periódicas.

## R8
CUANDO la app vuelve a primer plano, el sistema DEBE hacer una comprobación de conexión en ese momento.

## Pantalla sin conexión

## R9
MIENTRAS no hay conexión, el sistema DEBE mostrar la pantalla sin conexión, con el título "Necesitás conexión a internet para usar la app", en lugar de cualquier otra pantalla de la app (ingreso, registro, principal, SOS, detalle y las demás).

## R10
MIENTRAS no hay conexión, el sistema NO DEBE mostrar ni anunciar al lector de pantalla las alertas ni los turnos guardados en el teléfono.

## R11
MIENTRAS se muestra la pantalla sin conexión, el sistema DEBE ofrecer el botón "Llamar al 911".

## R12
CUANDO el vecino toca "Llamar al 911" en la pantalla sin conexión y confirma con "Llamar", el sistema DEBE abrir el teléfono con el 911 marcado.

## R13
DONDE el dispositivo no puede hacer llamadas, el sistema DEBE mostrar, al tocar "Llamar al 911" en la pantalla sin conexión, el diálogo "Llamá al 911 desde un teléfono".

## Cuando vuelve la conexión

## R14
CUANDO una comprobación da que hay conexión después de una que dio sin conexión, el sistema DEBE volver a mostrar la pantalla que estaba abierta, con el estado que tenía, sin reiniciar la app.

## R15
CUANDO una comprobación da que hay conexión después de una que dio sin conexión, el sistema DEBE publicar `AlertasActualizadas` y `TurnosActualizados` en el bus de eventos.

## Sin envío diferido de alertas

## R16
SI crear una alerta falla por la red ENTONCES el sistema DEBE informar el error sin guardar la alerta en el teléfono para mandarla después.

## R17
SI el envío de un SOS falla por la red ENTONCES el sistema DEBE mostrar en la pantalla SOS el mensaje "No pudimos enviar la alerta. Probá de nuevo o llamá al 911.".

## R18
El sistema NO DEBE crear en la base local una tabla de alertas pendientes de envío.

## R19
CUANDO se abre una base local de una versión anterior que tiene la tabla `alertas_pendientes`, el sistema DEBE borrar esa tabla sin borrar las alertas ni los turnos guardados.

## Copia local como caché

## R20
SI un pedido de alertas o de turnos falla y hay una copia guardada en el teléfono ENTONCES el sistema DEBE devolver esa copia y marcar `sinConexion`.

## Accesibilidad de la pantalla sin conexión

## R21
El sistema DEBE dar a todo elemento tocable de la pantalla sin conexión un objetivo táctil de al menos 48 x 48 dp y una etiqueta para el lector de pantalla.

## R22
CUANDO aparece la pantalla sin conexión, el sistema DEBE anunciar al lector de pantalla el título "Necesitás conexión a internet para usar la app" como encabezado.

## R23
MIENTRAS el texto del sistema está al 200 %, el sistema DEBE mostrar la pantalla sin conexión sin desbordes y con el botón "Llamar al 911" alcanzable.

## R24
El sistema DEBE mostrar los textos de la pantalla sin conexión con el contraste mínimo de las guías de accesibilidad y sin comunicar el estado solo con color.

## Trazabilidad con el `acceptance` de feature_list.json

| Criterio de aceptación | Cubierto por |
|---|---|
| Sin conexión, la app muestra "Necesitás conexión a internet para usar la app" en lugar de las pantallas normales | R1, R2, R3, R4, R9 |
| Sin conexión, el botón Llamar al 911 sigue a mano y funciona | R11, R12, R13 |
| Cuando vuelve la conexión, la app sigue sola sin tener que reiniciarla | R5, R6, R7, R8, R14, R15 |
| Ya no se puede crear una alerta sin conexión ni queda ninguna guardada para mandar después; se quita el código del envío diferido | R16, R17, R18, R19 |
| La copia local de alertas y turnos queda solo como caché y no permite usar la app sin conexión | R10, R20 |
| La pantalla sin conexión cumple las reglas de accesibilidad del proyecto | R21, R22, R23, R24 |
| Pruebas de la detección de conexión, del ViewModel y de la pantalla sin conexión | R1–R8 (detección y ViewModel), R9–R15 y R21–R24 (pantalla) |
