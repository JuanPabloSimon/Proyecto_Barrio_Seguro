# Tasks — rol_comision

> Pasos en orden. El `implementer` marca `[x]` al terminar cada uno. Cada
> task dice qué `R<n>` cubre.

## Dominio (app)

- [x] T1 — Agregar `enum RolVecino { vecino, comision }` con `desdeJson` y `json`, el campo `rol` (por defecto `RolVecino.vecino`), el getter `esComision` y `rol` en `fromJson`/`toJson` de `Vecino` en `lib/domain/models/vecino.dart`. `copyWith` conserva el rol. Cubre: R1, R2, R3, R4.
- [x] T2 — Pruebas en el grupo `JSON` de `test/unit/dominio_test.dart`: `el rol tiene solo dos valores: vecino y comision` (R1); `un vecino con rol comision es de la comisión` (R2); `sin rol o con un rol desconocido es vecino común` (R3, con `{}` sin `rol` y con `"rol": "admin"`); `el rol viaja en el JSON, ida y vuelta, para cada rol` (R4); `copyWith conserva el rol` (R4). Cubre: R1, R2, R3, R4.

## Datos (app)

- [x] T3 — En `SesionRepositoryRemoto.actualizarDatos` (`lib/data/repositories/sesion_repository.dart`) quitar `rol` del cuerpo además de `id`. Cubre: R8.
- [x] T4 — Prueba `actualizar los datos no manda el rol` en el grupo `Sesión contra la API` de `test/unit/servicios_http_test.dart` (el cuerpo del `PUT` no tiene la clave `rol`, con un vecino de la comisión). Cubre: R8.
- [x] T5 — Pruebas en el grupo `Sesión contra la API` de `test/unit/servicios_http_test.dart`: `ingresar como comisión guarda el rol y lo recupera al reabrir` y `ingresar como vecino común guarda el rol vecino` (la API falsa responde `vecino` con `"rol"`; después se crea otro `SesionRepositoryRemoto` con las mismas preferencias y almacén, se llama a `restaurar()` y se mira `usuario.rol`). Cubre: R5, R6.
- [x] T6 — Prueba `una sesión guardada sin rol se restaura como vecino` en el grupo `Sesión` de `test/unit/persistencia_test.dart` (se arma con `preferenciasEnMemoria({Preferencias.claveVecino: '<JSON de vecino sin rol>'})` y `almacenSeguroEnMemoria({AlmacenSeguro.claveToken: 't'})` de `test/ayudas/bases_de_prueba.dart`; `restaurar()` deja un usuario con `RolVecino.vecino`). Cubre: R7.
- [x] T7 — En `lib/data/services/simulados/servidor_simulado.dart`: `rol` en `_vecinosDeEjemplo` (`clara` → `comision`, el resto → `vecino`); `registrar` fuerza `'rol': 'vecino'`; `actualizarVecino` lanza `ErrorDelServidor('El rol no se puede cambiar desde la app.')` si `datos['rol']` existe y es distinto del actual. Cubre: R18, R19, R20.
- [x] T8 — Pruebas en `test/unit/repositorios_test.dart` (grupo nuevo `Rol contra el servidor simulado`): `la vecina de ejemplo es de la comisión y el resto no` (R20); `quien se registra queda como vecino aunque mande rol comision` (R18); `cambiar el rol en la actualización falla con el mensaje del servidor` (R19, para un vecino común y para la comisión); `actualizar con el mismo rol no falla` (R19). Cubre: R18, R19, R20.

## ViewModel y pantalla

- [x] T9 — Sin cambios de ViewModel ni de pantalla en esta feature (la opción visible es de `informe_alertas`). Correr las pruebas existentes de `editar_perfil` y de accesibilidad para confirmar que siguen verdes con el campo nuevo. Cubre: R8.

## Backend

- [x] T10 — Agregar `abstract final class Roles` en `backend/lib/src/almacen.dart` y normalizar el rol de cada vecino en `_leer` (falta o desconocido → `Roles.vecino`). Cubre: R11.
- [x] T11 — Agregar `'rol'` a cada vecino de `vecinosDeEjemplo` en `backend/lib/src/datos_de_ejemplo.dart` (`clara` → `comision`, el resto → `vecino`) y actualizar el comentario de cuentas de prueba. Cubre: R12.
- [x] T12 — En `backend/lib/src/api.dart`: `_registrar` guarda `'rol': Roles.vecino`; `_actualizarVecino` responde 403 con `mensajeRolFijo` si el cuerpo trae un `rol` distinto del actual, antes de tocar nada, y nunca copia `rol` del cuerpo. Cubre: R9, R10, R13, R14.
- [x] T13 — En `backend/lib/src/api.dart`: middleware público `soloComision`, sub-router `_rutasDeLaComision` (solo el comodín 404) y `..mount('/comision/', …)` en `_rutas` antes del comodín final. Cubre: R15, R16, R17.
- [x] T14 — Grupo `Rol` en `backend/test/api_test.dart`: `ingresar devuelve el rol de cada cuenta` (Clara `comision`, Rosa `vecino`; R9, R12); `GET /vecinos/yo y PUT /vecinos/<id> devuelven el rol` (R9); `registrarse da rol vecino aunque el pedido mande comision` (R10); `un vecino común no puede darse el rol comision: 403` (Rosa, mensaje exacto; R13); `el rol rechazado no cambia ningún dato` (Rosa manda `rol: comision` y `nombre` nuevo, después `GET /vecinos/yo` sigue igual; R14); `un miembro de la comisión tampoco cambia su rol por PUT` (Clara manda `rol: vecino` → 403 y sigue `comision`; R14); `mandar el mismo rol no falla` (R13). Cubre: R9, R10, R12, R13, R14.
- [x] T15 — Prueba `un archivo de datos viejo sin rol se lee con rol vecino` en `backend/test/api_test.dart` (escribe en un directorio temporal un JSON con `ultimo_id`, `vecinos` sin `rol`, `credenciales`, `sesiones`, `turnos` y `alertas` vacíos; `Almacen.abrir(archivo: …)` y se mira `almacen.vecinos[id]!['rol']`; también un vecino con `"rol": "admin"` queda `vecino`). Cubre: R11.
- [x] T16 — Grupo `Rutas de la comisión` en `backend/test/api_test.dart`: `un vecino común recibe 403 en cualquier ruta de la comisión` (Rosa, `GET` y `POST /comision/informes/alertas`, mensaje exacto; R15); `sin sesión, las rutas de la comisión responden 401` (R16); `un miembro de la comisión pasa el filtro` (Clara en `/comision/lo-que-sea` → 404 "Esa dirección no existe.", no 403; R17); `soloComision deja pasar a la comisión y frena al vecino común` (envuelve un handler falso que responde 200: con el token de Clara responde 200; con el de Rosa lanza `ErrorDeApi` con `codigo` 403; R15, R17). Cubre: R15, R16, R17.
- [x] T17 — Actualizar `backend/README.md`: tabla de cuentas de prueba (columna "Turnos" y nueva "Rol en la app"), fila de `/comision/…` en la tabla de rutas, 403 para rutas de la comisión en la tabla de errores, campo `rol` en la descripción del vecino, nota de que los vecinos dentro de los turnos no traen `rol`, y sección "Asignar el rol de la comisión": la asigna **el equipo de desarrollo** editando los datos del servidor (apagarlo, poner `"rol": "comision"` o `"vecino"` en `datos/barrio.json`, volver a arrancarlo; el vecino vuelve a ingresar). Cubre: R12.

## El rol no viaja en los turnos

- [x] T18 — En `Turno.toMap` (`lib/domain/models/turno.dart`) guardar cada vecino de `patrulleros` y `guardia_ventana` con `toJson()` sin la clave `rol`. Cubre: R23.
- [x] T19 — Prueba `la copia local de los turnos no guarda el rol` en el grupo `TurnosDao` de `test/unit/persistencia_test.dart`: un turno con un patrullero `Vecino(…, rol: RolVecino.comision)` y `vecinoMayor` de guardia; `dao.reemplazarMes(…)`, después `db.query('turnos')` y `jsonDecode` de las columnas `patrulleros` y `guardia_ventana`: ningún vecino tiene la clave `rol`; `dao.delMes(…)` lo devuelve con `incluye(patrullero)` verdadero. Cubre: R23.
- [x] T20 — En `lib/data/services/simulados/servidor_simulado.dart`: ayuda `_vecinoDelTurno(id)` (copia sin `rol`) y usarla en `_turnoCompleto` para patrulleros y guardia de ventana. Cubre: R22.
- [x] T21 — Pruebas en el grupo `Rol contra el servidor simulado` de `test/unit/repositorios_test.dart`, contra `ServidorSimulado` directo: `los vecinos de los turnos no traen el rol` (`turnosDelMes(2026, 10)`, el turno del 9 con Clara, Sofía y Ernesto: ningún mapa de `patrulleros` ni `guardia_ventana` tiene `rol`; lo mismo en lo que devuelven `anotarse` y `salir`); `sacar el rol de los turnos no le quita el rol a la vecina` (después de `turnosDelMes`, `ingresar(…)['vecino']['rol']` sigue `comision`). Cubre: R22.
- [x] T22 — En `backend/lib/src/api.dart`: ayuda `_vecinoDelTurno(id)` que devuelve `Map.of(_almacen.vecinos[id]!)..remove('rol')`, usada en `_turnoCompleto` para patrulleros y guardia de ventana. Nunca hacer `remove` sobre el mapa guardado en `Almacen`. Cubre: R21.
- [x] T23 — Prueba `los vecinos de los turnos no traen el rol` en el grupo `Turnos` de `backend/test/api_test.dart`: con el token de Clara, `GET /turnos?anio=2026&mes=10` (el turno del 9 con Clara de patrullera y Ernesto de guardia: ningún vecino tiene la clave `rol`), `PUT /turnos/2026-10-30/noche/vecinos/clara` y `DELETE` del mismo turno (tampoco); después `GET /vecinos/yo` sigue con `"rol": "comision"` (no se borró del almacén). Cubre: R21.

## Cierre

- [x] T24 — Trazabilidad `R<n>` → prueba en `progress/impl_rol_comision.md`.
- [x] T25 — `./init.sh` verde.
