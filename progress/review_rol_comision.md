# Review — feature 13 (rol_comision)

**Veredicto:** APPROVED

Segunda vuelta. Revisado sobre el árbol de trabajo sin commitear de
`feature/rol_comision` (`git status` / `git diff` contra c41eae4, que tiene el
spec aprobado). La primera vuelta pidió cambios por cobertura parcial de R12 y
R20.

## Correcciones pedidas
1. **R12** — [x] `backend/test/api_test.dart:220` › Rol › de los vecinos de
   ejemplo, solo clara es de la comisión. Con el `almacen` del `setUp` (datos
   de ejemplo), verifica que hay 12 vecinos y que está `clara`, y recorre
   **todos** los de `almacen.vecinos`: `clara` → `comision`, cualquier otro →
   `vecino`, con `reason: id`. Falla si cualquier otro vecino quedara como
   `comision`. Cumple el requisito.
2. **R20** — [x] `test/unit/repositorios_test.dart:96-119` › la vecina de
   ejemplo es de la comisión y el resto no. Verifica Clara `comision` y recorre
   los 11 restantes (`jorge`, `ana`, `martin`, `pedro`, `laura`, `sofia`,
   `raul`, `ines`, `rosa`, `ernesto`, `elena`), que coinciden exactamente con
   los ids de `_vecinosDeEjemplo`
   (`lib/data/services/simulados/servidor_simulado.dart:269-340`). Sin exponer
   `_vecinos` ni tocar producción.
3. **`./init.sh`** — [x] corrido de nuevo por el reviewer: código 0.

**Producción sin cambios en esta vuelta:** todos los archivos de `lib/`,
`backend/lib/` y `backend/README.md` tienen fecha de modificación anterior al
review previo (20:14:23); las referencias de línea del review anterior
(`api.dart:164-167`, `api.dart:206-214`, `sesion_repository.dart:107-109`)
siguen apuntando al mismo código. Solo cambiaron
`backend/test/api_test.dart`, `test/unit/repositorios_test.dart` y
`progress/impl_rol_comision.md`.

## Trazabilidad
- R1: [x] `test/unit/dominio_test.dart` › JSON › el rol tiene solo dos valores: vecino y comision
- R2: [x] `test/unit/dominio_test.dart` › JSON › un vecino con rol comision es de la comisión
- R3: [x] `test/unit/dominio_test.dart` › JSON › sin rol o con un rol desconocido es vecino común
- R4: [x] `test/unit/dominio_test.dart` › JSON › el rol viaja en el JSON, ida y vuelta, para cada rol; › copyWith conserva el rol
- R5: [x] `test/unit/servicios_http_test.dart` › Sesión contra la API › ingresar como comisión guarda el rol y lo recupera al reabrir; › ingresar como vecino común guarda el rol vecino (registrarse usa el mismo `_abrirSesion`; T5 pide solo ingresar)
- R6: [x] mismas dos pruebas de R5 (`restaurar()` con otro repositorio sobre las mismas preferencias)
- R7: [x] `test/unit/persistencia_test.dart` › Sesión › una sesión guardada sin rol se restaura como vecino
- R8: [x] `test/unit/servicios_http_test.dart` › Sesión contra la API › actualizar los datos no manda el rol
- R9: [x] `backend/test/api_test.dart` › Rol › ingresar devuelve el rol de cada cuenta; › GET /vecinos/yo y PUT /vecinos/<id> devuelven el rol; › registrarse da rol vecino aunque el pedido mande comision
- R10: [x] `backend/test/api_test.dart` › Rol › registrarse da rol vecino aunque el pedido mande comision
- R11: [x] `backend/test/api_test.dart` › Rol › un archivo de datos viejo sin rol se lee con rol vecino
- R12: [x] `backend/test/api_test.dart:220` › Rol › de los vecinos de ejemplo, solo clara es de la comisión (los 12)
- R13: [x] `backend/test/api_test.dart` › Rol › un vecino común no puede darse el rol comision: 403; › mandar el mismo rol no falla
- R14: [x] `backend/test/api_test.dart` › Rol › el rol rechazado no cambia ningún dato; › un miembro de la comisión tampoco cambia su rol por PUT
- R15: [x] `backend/test/api_test.dart` › Rutas de la comisión › un vecino común recibe 403 en cualquier ruta de la comisión; › soloComision deja pasar a la comisión y frena al vecino común
- R16: [x] `backend/test/api_test.dart` › Rutas de la comisión › sin sesión, las rutas de la comisión responden 401
- R17: [x] `backend/test/api_test.dart` › Rutas de la comisión › un miembro de la comisión pasa el filtro; › soloComision deja pasar a la comisión y frena al vecino común
- R18: [x] `test/unit/repositorios_test.dart` › Rol contra el servidor simulado › quien se registra queda como vecino aunque mande rol comision
- R19: [x] `test/unit/repositorios_test.dart` › Rol contra el servidor simulado › cambiar el rol en la actualización falla con el mensaje del servidor; › actualizar con el mismo rol no falla
- R20: [x] `test/unit/repositorios_test.dart:96` › Rol contra el servidor simulado › la vecina de ejemplo es de la comisión y el resto no (los 12)
- R21: [x] `backend/test/api_test.dart` › Turnos › los vecinos de los turnos no traen el rol
- R22: [x] `test/unit/repositorios_test.dart` › Rol contra el servidor simulado › los vecinos de los turnos no traen el rol; › sacar el rol de los turnos no le quita el rol a la vecina
- R23: [x] `test/unit/persistencia_test.dart` › TurnosDao › la copia local de los turnos no guarda el rol

## Tasks
- T1–T25: [x] todas marcadas. `requirements.md` y `design.md` sin cambios respecto de c41eae4; `tasks.md` solo cambia `[ ]` por `[x]`.

## Arquitectura y convenciones
- [x] Archivos tocados = los de la tabla del design; sin cambios en `lib/ui/`, `lib/dependencias.dart`, `feature_list.json` ni en los `pubspec`.
- [x] Capas, armado por constructor, sin decisiones de plataforma, sin `static` con estado (ver review anterior; nada cambió en producción).
- [x] Backend: `soloComision` lee el rol del almacén (`backend/lib/src/api.dart:206-214`); 403 de rol antes de tocar datos (`api.dart:164-167`).
- [x] Mismo mensaje en app (simulado) y backend: "El rol no se puede cambiar desde la app."
- [x] Ninguna regla de turnos cambiada.
- [x] `dart format` sin cambios en las dos pruebas corregidas.
- [x] Sin pantalla nueva: no aplica `test/accesibilidad_test.dart` (sigue verde).
- [x] Sin paquetes nuevos.
- Observación no bloqueante (se mantiene): las pruebas del simulado usan `servidor.actualizarVecino(id, {})` como lectura (`test/unit/repositorios_test.dart:116`). Funciona; es un comando usado como consulta.

## Checkpoints
- C1: [x] Arnés completo; `./init.sh` sale con 0.
- C2: [x] Una sola feature `in_progress` (13); `progress/current.md` describe la sesión.
- C3: [x] Capas, armado, plataforma y paquetes correctos; sin cambios en reglas de turnos.
- C4: [x] `flutter analyze` y `dart analyze` sin avisos; 172 pruebas de la app y 42 del backend en verde.
- C5: [x] No aplica (sin pantalla); accesibilidad sigue verde.
- C6: [x] Sin temporales ni `print`. `progress/history.md` y el estado final los cierra el leader.
- C7: [x] Spec completo en EARS, tasks en `[x]`, cada R1–R23 con prueba concreta que lo verifica.

## Salida de init.sh
```text
[OK]    feature_list.json válido (14 features)
[OK]    Specs presentes para las features sdd que ya no están en pending
No issues found! (ran in 4.3s)
[OK]    flutter analyze sin avisos
No issues found!
[OK]    dart analyze sin avisos en backend/
00:19 +172: All tests passed!
[OK]    Pruebas de la app
00:00 +42: All tests passed!
[OK]    Pruebas del backend
[OK]    Entorno listo. Podés empezar a trabajar.
```
Código de salida: 0.

## Cambios requeridos
Ninguno.
