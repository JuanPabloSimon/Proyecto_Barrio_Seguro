# Requirements — rol_comision

> Feature #13 de `feature_list.json`: Rol de miembro de la comisión.
>
> Cada requisito está en EARS estricto (ver `docs/specs.md`) y se verifica
> con al menos una prueba concreta.
>
> Glosario: "vecino común" es un vecino con rol `vecino`; "miembro de la
> comisión" es un vecino con rol `comision`. "Ruta solo para la comisión"
> es cualquier ruta de la API bajo el prefijo `/comision/`.

## Rol en el modelo (app)

## R1
El sistema DEBE representar el rol de cada vecino con exactamente uno de dos valores: `vecino` o `comision`.

## R2
CUANDO la app lee un vecino de un JSON con `"rol": "comision"`, el sistema DEBE tratarlo como miembro de la comisión.

## R3
SI el JSON de un vecino no trae el campo `rol` o trae un valor distinto de `vecino` y `comision` ENTONCES el sistema DEBE tratarlo como vecino común.

## R4
CUANDO la app convierte un vecino a JSON, el sistema DEBE incluir el campo `rol` con el valor de su rol.

## Rol en la sesión (app)

## R5
CUANDO el vecino ingresa o se registra, el sistema DEBE guardar en el teléfono el rol que devolvió el servidor junto con los demás datos de la sesión.

## R6
CUANDO la app restaura la sesión guardada en el teléfono, el sistema DEBE recuperar el mismo rol que se guardó.

## R7
SI la sesión guardada en el teléfono es de una versión anterior y no tiene rol ENTONCES el sistema DEBE restaurarla con el rol `vecino`.

## R8
CUANDO el vecino guarda cambios en sus datos desde el perfil, el sistema NO DEBE enviar el campo `rol` en el pedido de actualización.

## Rol en la API

## R9
CUANDO la API devuelve los datos de un vecino (al ingresar, al registrarse, en `GET /vecinos/yo` y en `PUT /vecinos/<id>`), el sistema DEBE incluir el campo `rol`.

## R10
CUANDO alguien se registra con `POST /vecinos`, el sistema DEBE crear la cuenta con rol `vecino`, aunque el pedido traiga otro valor de `rol`.

## R11
CUANDO el servidor arranca con un archivo de datos que tiene vecinos sin campo `rol`, el sistema DEBE asignarles el rol `vecino`.

## R12
CUANDO el servidor arranca sin archivo de datos, el sistema DEBE cargar los datos de ejemplo con Clara Medina como miembro de la comisión y el resto de los vecinos con rol `vecino`.

## R13
SI un vecino común pide en `PUT /vecinos/<id>` un `rol` distinto del que tiene ENTONCES el sistema DEBE responder 403 con `{"error": "El rol no se puede cambiar desde la app."}`.

## R14
SI un pedido a `PUT /vecinos/<id>` es rechazado por intentar cambiar el rol ENTONCES el sistema DEBE dejar el rol y los demás datos del vecino sin cambios.

## Rutas solo para la comisión (API)

## R15
SI un vecino común pide cualquier ruta bajo `/comision/` ENTONCES el sistema DEBE responder 403 con `{"error": "Esta opción es solo para la comisión vecinal."}`.

## R16
SI un pedido a una ruta bajo `/comision/` no trae una sesión válida ENTONCES el sistema DEBE responder 401.

## R17
MIENTRAS el vecino de la sesión es miembro de la comisión, el sistema DEBE pasar sus pedidos bajo `/comision/` a la ruta correspondiente.

## Servidor simulado (app sin API)

## R18
DONDE la app usa el servidor simulado, el sistema DEBE crear con rol `vecino` a quien se registra, aunque los datos traigan otro valor de `rol`.

## R19
DONDE la app usa el servidor simulado, el sistema DEBE rechazar con el mensaje "El rol no se puede cambiar desde la app." una actualización de datos que pide un `rol` distinto del que tiene el vecino.

## R20
DONDE la app usa el servidor simulado, el sistema DEBE tener a la vecina de ejemplo Clara Medina con rol `comision` y al resto de los vecinos de ejemplo con rol `vecino`.

## El rol no viaja en los turnos

> Pedido del equipo: "no hace falta que aparezca que es de la comision" en
> los turnos. Precisa dónde viaja el rol (criterio "El rol viaja en el JSON
> de la API y se guarda con la sesión"): con los datos del propio vecino y
> la sesión, no con los vecinos que aparecen en un turno.

## R21
CUANDO la API devuelve un turno (en `GET /turnos`, `PUT /turnos/<fecha>/<franja>/vecinos/<id>` y `DELETE /turnos/<fecha>/<franja>/vecinos/<id>`), el sistema NO DEBE incluir el campo `rol` en los vecinos de `patrulleros` ni en `guardia_ventana`.

## R22
DONDE la app usa el servidor simulado, el sistema NO DEBE incluir el campo `rol` en los vecinos de `patrulleros` ni en `guardia_ventana` de los turnos que devuelve.

## R23
CUANDO la app guarda un turno en la base local del teléfono, el sistema NO DEBE guardar el campo `rol` de los vecinos del turno.

## Trazabilidad con el `acceptance` de feature_list.json

| Criterio de aceptación | Cubierto por |
|---|---|
| El vecino tiene un rol: vecino o comision | R1, R2, R3, R11, R12, R20 |
| El rol viaja en el JSON de la API y se guarda con la sesión | R4, R5, R6, R7, R9, R21, R22, R23 (estos tres limitan el rol a los datos del propio vecino y a la sesión, por pedido del equipo) |
| Un vecino común no puede cambiarse el rol a sí mismo (la API responde 403) | R8, R10, R13, R14, R18, R19 |
| Las rutas solo para la comisión responden 403 a un vecino común | R15, R16, R17 |
| Pruebas en la app y en el backend para cada rol | R1–R23 (cada uno con su prueba; ver `tasks.md`, que prueba cada comportamiento con un vecino común y con un miembro de la comisión) |
