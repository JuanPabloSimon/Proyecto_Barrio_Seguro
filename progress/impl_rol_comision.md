# Implementación — rol_comision (feature 13)

- **Rama:** `feature/rol_comision` (sin commitear, como pidió el leader).
- **Fecha:** 2026-11-25
- **Spec:** `specs/rol_comision/` — tasks T1–T25 marcadas `[x]`.
- **Paquetes nuevos:** ninguno.
- **Estado en `feature_list.json`:** sigue `in_progress` (espera al reviewer).

## Archivos tocados

### App (`lib/`)

| Archivo | Cambio | Tasks |
|---|---|---|
| `lib/domain/models/vecino.dart` | `enum RolVecino { vecino, comision }` con `desdeJson` y `json`; campo `rol` (por defecto `vecino`), getter `esComision`, `rol` en `fromJson`/`toJson`; `copyWith` conserva el rol y no lo recibe. | T1 |
| `lib/domain/models/turno.dart` | `toMap` guarda patrulleros y guardia con `_sinRol` (`toJson()` sin `rol`). | T18 |
| `lib/data/repositories/sesion_repository.dart` | `actualizarDatos` quita `rol` (además de `id`) del cuerpo del `PUT`. | T3 |
| `lib/data/services/simulados/servidor_simulado.dart` | `rol` en los vecinos de ejemplo (Clara `comision`, resto `vecino`); `registrar` fuerza `vecino`; `actualizarVecino` lanza `ErrorDelServidor(mensajeRolFijo)` si piden otro rol (y conserva el rol actual); `_vecinoDelTurno(id)` (copia sin `rol`) usada en `_turnoCompleto`. | T7, T20 |

### Backend (`backend/`)

| Archivo | Cambio | Tasks |
|---|---|---|
| `backend/lib/src/almacen.dart` | `abstract final class Roles`; `_leer` normaliza el rol (falta o desconocido → `vecino`). | T10 |
| `backend/lib/src/datos_de_ejemplo.dart` | `rol` en los 12 vecinos de ejemplo (`clara` → `comision`); comentario de cuentas de prueba con el rol. | T11 |
| `backend/lib/src/api.dart` | `mensajeRolFijo`, `mensajeSoloComision`; `_registrar` guarda `rol: vecino`; `_actualizarVecino` responde 403 antes de tocar nada si piden otro rol (el `rol` nunca se copia del cuerpo); middleware público `soloComision`; sub-router `_rutasDeLaComision` (solo comodín 404) montado en `/comision/` antes del comodín final; `_vecinoDelTurno(id)` usada en `_turnoCompleto`. | T12, T13, T22 |
| `backend/README.md` | Cuentas de prueba con columnas "Turnos" y "Rol en la app"; sección "Asignar el rol de la comisión" (equipo de desarrollo); campo `rol` del vecino y nota de turnos sin `rol`; `PUT /vecinos/<id>` con 403 por rol; fila `/comision/…`; 403 ampliado en la tabla de errores. | T17 |

### Pruebas

| Archivo | Pruebas nuevas | Tasks |
|---|---|---|
| `test/unit/dominio_test.dart` | 5 en el grupo `JSON`. | T2 |
| `test/unit/servicios_http_test.dart` | 3 en `Sesión contra la API`. | T4, T5 |
| `test/unit/persistencia_test.dart` | 1 en `Sesión`, 1 en `TurnosDao`. | T6, T19 |
| `test/unit/repositorios_test.dart` | Grupo nuevo `Rol contra el servidor simulado` (6). | T8, T21 |
| `backend/test/api_test.dart` | Grupos nuevos `Rol` (9) y `Rutas de la comisión` (4); 1 en `Turnos`. | T14, T15, T16, T23 |

T9: sin cambios de ViewModel ni de pantalla; se corrieron `test/unit/view_models_test.dart`, `test/accesibilidad_test.dart` (incluye la pantalla "Editar datos") y `test/widget_test.dart`: verdes.

## Trazabilidad

| Requisito | Prueba |
|---|---|
| R1 | `test/unit/dominio_test.dart` › JSON › el rol tiene solo dos valores: vecino y comision |
| R2 | `test/unit/dominio_test.dart` › JSON › un vecino con rol comision es de la comisión |
| R3 | `test/unit/dominio_test.dart` › JSON › sin rol o con un rol desconocido es vecino común |
| R4 | `test/unit/dominio_test.dart` › JSON › el rol viaja en el JSON, ida y vuelta, para cada rol; › copyWith conserva el rol |
| R5 | `test/unit/servicios_http_test.dart` › Sesión contra la API › ingresar como comisión guarda el rol y lo recupera al reabrir; › ingresar como vecino común guarda el rol vecino |
| R6 | `test/unit/servicios_http_test.dart` › Sesión contra la API › ingresar como comisión guarda el rol y lo recupera al reabrir; › ingresar como vecino común guarda el rol vecino |
| R7 | `test/unit/persistencia_test.dart` › Sesión › una sesión guardada sin rol se restaura como vecino |
| R8 | `test/unit/servicios_http_test.dart` › Sesión contra la API › actualizar los datos no manda el rol |
| R9 | `backend/test/api_test.dart` › Rol › ingresar devuelve el rol de cada cuenta; › GET /vecinos/yo y PUT /vecinos/<id> devuelven el rol; › registrarse da rol vecino aunque el pedido mande comision |
| R10 | `backend/test/api_test.dart` › Rol › registrarse da rol vecino aunque el pedido mande comision |
| R11 | `backend/test/api_test.dart` › Rol › un archivo de datos viejo sin rol se lee con rol vecino |
| R12 | `backend/test/api_test.dart` › Rol › de los vecinos de ejemplo, solo clara es de la comisión (recorre los 12 de `almacen.vecinos`: `clara` → `comision`, el resto → `vecino`, con `reason: id`); › ingresar devuelve el rol de cada cuenta |
| R13 | `backend/test/api_test.dart` › Rol › un vecino común no puede darse el rol comision: 403; › mandar el mismo rol no falla |
| R14 | `backend/test/api_test.dart` › Rol › el rol rechazado no cambia ningún dato; › un miembro de la comisión tampoco cambia su rol por PUT |
| R15 | `backend/test/api_test.dart` › Rutas de la comisión › un vecino común recibe 403 en cualquier ruta de la comisión; › soloComision deja pasar a la comisión y frena al vecino común |
| R16 | `backend/test/api_test.dart` › Rutas de la comisión › sin sesión, las rutas de la comisión responden 401 |
| R17 | `backend/test/api_test.dart` › Rutas de la comisión › un miembro de la comisión pasa el filtro; › soloComision deja pasar a la comisión y frena al vecino común |
| R18 | `test/unit/repositorios_test.dart` › Rol contra el servidor simulado › quien se registra queda como vecino aunque mande rol comision |
| R19 | `test/unit/repositorios_test.dart` › Rol contra el servidor simulado › cambiar el rol en la actualización falla con el mensaje del servidor (Rosa y Clara); › actualizar con el mismo rol no falla |
| R20 | `test/unit/repositorios_test.dart` › Rol contra el servidor simulado › la vecina de ejemplo es de la comisión y el resto no (Clara `comision`; los 11 restantes — `jorge`, `ana`, `martin`, `pedro`, `laura`, `sofia`, `raul`, `ines`, `rosa`, `ernesto`, `elena` — `vecino`) |
| R21 | `backend/test/api_test.dart` › Turnos › los vecinos de los turnos no traen el rol |
| R22 | `test/unit/repositorios_test.dart` › Rol contra el servidor simulado › los vecinos de los turnos no traen el rol; › sacar el rol de los turnos no le quita el rol a la vecina |
| R23 | `test/unit/persistencia_test.dart` › TurnosDao › la copia local de los turnos no guarda el rol |

## `./init.sh` completo (resumen)

```
[OK]    Flutter 3.47.5 • channel stable
[OK]    Dart SDK version: 3.13.4 (stable)
[OK]    Existe … (11 archivos del arnés)
[OK]    feature_list.json válido (14 features)
[OK]    Specs presentes para las features sdd que ya no están en pending
[OK]    flutter pub get
[OK]    dart pub get en backend/
No issues found! (ran in 14.7s)
[OK]    flutter analyze sin avisos
No issues found!
[OK]    dart analyze sin avisos en backend/
00:27 +172: All tests passed!
[OK]    Pruebas de la app
00:00 +42: All tests passed!
[OK]    Pruebas del backend
[OK]    Entorno listo. Podés empezar a trabajar.
```

Salida: código 0. `dart format` sobre `lib/`, `test/`, `backend/lib/` y `backend/test/`: sin cambios pendientes.

## Correcciones tras CHANGES_REQUESTED (`progress/review_rol_comision.md`)

1. **R12:** prueba nueva en `backend/test/api_test.dart` › Rol › de los vecinos de ejemplo, solo clara es de la comisión. Con el `almacen` del `setUp` (datos de ejemplo), recorre todos los vecinos de `almacen.vecinos` (verifica que son 12 y que está `clara`) y exige `comision` para `clara` y `vecino` para cada uno de los demás, con `reason: id`.
2. **R20:** `test/unit/repositorios_test.dart` › la vecina de ejemplo es de la comisión y el resto no ahora recorre los 11 vecinos restantes de `_vecinosDeEjemplo`. Sin cambios de código de producción.
3. `dart format` (0 cambiados) y `./init.sh` completo: código 0, 172 pruebas de la app y 42 del backend.

Solo se tocaron esas dos pruebas y este informe.

## Notas para el reviewer

- `ServidorSimulado.actualizarVecino`, además del rechazo de T7, fija `'rol': actual['rol']` en el vecino actualizado (como ya hacía con `fecha_nacimiento` y `vecino_desde`). No cambia el comportamiento pedido: un `rol` distinto ya se rechazó antes y uno igual no cambia nada; solo evita que el rol pueda venir del pedido.
- El mensaje del simulado vive en `ServidorSimulado.mensajeRolFijo`, con el mismo texto que `Api.mensajeRolFijo` del backend.
- No hay `print` ni `debugPrint` nuevos. Sin cambios en `pubspec.yaml`, `lib/dependencias.dart` ni pantallas.

## Prueba manual

No se hizo (la feature no tiene pantalla). La cobertura es con pruebas automáticas de la app y del backend.
