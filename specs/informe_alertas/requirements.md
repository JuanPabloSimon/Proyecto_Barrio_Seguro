# Requirements — informe_alertas

> Feature #14 de `feature_list.json`: Informe de alertas para la comisión.
>
> Cada requisito está en EARS estricto (ver `docs/specs.md`) y se verifica
> con al menos una prueba concreta.

## Cálculo del informe mensual y exportación CSV (dominio)

## R1
CUANDO se calcula el informe para un mes y un año dados, el sistema DEBE incluir únicamente las alertas cuya fecha de creación pertenece a ese mes y año.

## R2
CUANDO se calcula el informe de un mes con alertas, el sistema DEBE agrupar y contar la cantidad de alertas por calle, ordenadas de mayor a menor cantidad y, a igual cantidad, por orden alfabético.

## R3
CUANDO se calcula el informe de un mes con alertas, el sistema DEBE agrupar y contar la cantidad de alertas por tipo, ordenadas de mayor a menor cantidad y, a igual cantidad, por orden alfabético.

## R4
CUANDO se calcula el informe de un mes con alertas, el sistema DEBE agrupar y contar la cantidad de alertas por franja horaria según la hora de creación (`Madrugada (00:00 - 06:00)`, `Mañana (06:00 - 12:00)`, `Tarde (12:00 - 20:00)` y `Noche (20:00 - 00:00)`).

## Visibilidad según el rol del vecino

## R5
MIENTRAS el vecino con la sesión abierta tiene rol `comision`, el sistema DEBE mostrar en la pantalla de perfil la opción "Informe mensual de alertas" para abrir la pantalla del informe.

## R6
MIENTRAS el vecino con la sesión abierta tiene rol `vecino`, el sistema NO DEBE mostrar en la pantalla de perfil la opción para abrir el informe de alertas.

## Pantalla del informe y selección de mes

## R7
CUANDO un miembro de la comisión abre la pantalla del informe o cambia el mes seleccionado, el sistema DEBE mostrar para ese mes la cantidad total de alertas y los desgloses por calle, por tipo y por franja horaria.

## R8
SI el mes elegido no tiene alertas registradas ENTONCES el sistema DEBE mostrar un mensaje indicando que no hubo alertas en ese mes y ocultar las tablas de calle, tipo y franja horaria.

## R9
SI ocurre un error al cargar las alertas y no hay copia local disponible ENTONCES el sistema DEBE mostrar el estado de error con la opción de reintentar.

## Descarga del informe en CSV

## R10
CUANDO un miembro de la comisión toca "Descargar informe (CSV)" en un mes con alertas, el sistema DEBE guardar un archivo CSV con el total y los conteos por calle, por tipo y por franja horaria del mes elegido y mostrar un aviso confirmando la descarga.

## R11
SI la descarga del archivo CSV falla ENTONCES el sistema DEBE mostrar el mensaje "No pudimos descargar el informe. Probá de nuevo.".

## R12
SI el mes elegido no tiene alertas registradas ENTONCES el sistema NO DEBE mostrar el botón para descargar el informe en CSV.

## Accesibilidad

## R13
El sistema DEBE cumplir en la pantalla de informe de alertas con objetivos táctiles de al menos 48 x 48 dp, etiquetas para lector de pantalla en los controles de cambio de mes, contraste mínimo de texto y diseño sin desbordes con el texto del sistema al 200 %.

## Trazabilidad con el `acceptance` de feature_list.json

| Criterio de aceptación | Cubierto por |
|---|---|
| Una pantalla nueva muestra, para un mes elegido, la cantidad de alertas por calle, por tipo y por franja horaria (y permite descargarlo en CSV, por pedido del equipo) | R1, R2, R3, R4, R7, R10, R11 |
| Solo la ven los miembros de la comisión; para el resto la opción no aparece | R5, R6 |
| Sin alertas en el mes, la pantalla lo dice en lugar de mostrar tablas vacías | R8, R12 |
| La pantalla cumple las reglas de accesibilidad del proyecto | R13 |
| Pruebas del cálculo del informe, del ViewModel y de la pantalla | R1, R2, R3, R4, R5, R6, R7, R8, R9, R10, R11, R12, R13 |
