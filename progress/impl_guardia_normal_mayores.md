# Implementación — guardia_normal_mayores (feature 20)

- **Rama:** `feature/guardia_normal_mayores` (sin commit ni push, como se pidió).
- **Spec:** `specs/guardia_normal_mayores/`, aprobado con las opciones asumidas de P1 a P4.
- **Tasks:** T1 a T30 marcadas `[x]`; no queda ninguna `[ ]`.
- **Estado:** listo para revisar. La feature sigue en `in_progress` y no la marqué `done`.

## Archivos tocados

### App (`lib/`)
| Archivo | Cambio |
|---|---|
| `lib/domain/reglas_turnos.dart` | Se agregan `puedeElegirGuardiaNormal(int edad)`, `haceGuardiaVentana({edad, guardiaNormal})`, `mensajeGuardiaNormalSoloMayores` y `mensajeGuardiaNormalInvalida`. `motivoNoDisponible` no cambia (ya usa `vecino.esGuardiaVentanaEn`). |
| `lib/domain/models/vecino.dart` | Campo `guardiaNormal` (por defecto `false`); `fromJson` toma `== true`; `toJson` lo agrega; `esGuardiaVentanaEn` usa `haceGuardiaVentana`; se agrega `puedeElegirGuardiaNormalEn(hoy)`; `copyWith` conserva el valor y no lo recibe como parámetro. |
| `lib/data/repositories/sesion_repository.dart` | Método `cambiarGuardiaNormal({required bool activa})` en la interfaz y en `SesionRepositoryRemoto`, que manda solo `{'guardia_normal': activa}`. `actualizarDatos` ya no manda `guardia_normal`. |
| `lib/data/services/simulados/servidor_simulado.dart` | `actualizarVecino` valida `guardia_normal` antes de tocar nada (no booleano o menor con `true`: error) y, si no viene, deja el guardado. `registrar` lo fija en `false`. Los 12 vecinos de ejemplo tienen `'guardia_normal': false`. |
| `lib/ui/perfil/view_models/perfil_view_model.dart` | Guarda `_bus`. Getters `puedeElegirGuardiaNormal`, `guardiaNormal` y `cambiandoGuardiaNormal`. Comando `cambiarGuardiaNormal(bool)`: espera al servidor y publica `PerfilActualizado` cuando confirma. |
| `lib/ui/perfil/widgets/perfil_screen.dart` | Sección "Turnos" con `_OpcionGuardiaNormal` (`Card` + `SwitchListTile`), solo si `puedeElegirGuardiaNormal`. `_cambiarGuardiaNormal` toma el `ScaffoldMessenger` antes del `await` y muestra el aviso con `mostrarAvisoEn`. |
| `lib/ui/turnos/view_models/turnos_view_model.dart` | Segunda suscripción a `PerfilActualizado`, cancelada en `dispose`. `esGuardiaEn(Turno)`. `detalleDe` decide por el lugar que el vecino ocupa en el turno. |
| `lib/ui/inicio/view_models/inicio_view_model.dart` | `_resumir`: si hay turno, el título, las líneas y `esGuardiaVentana` salen del lugar que el vecino ocupa en el próximo turno; si no hay turnos, de `esGuardiaVentanaEn`. |

### Backend (`backend/`)
| Archivo | Cambio |
|---|---|
| `backend/lib/src/reglas.dart` | Se agregan `puedeElegirGuardiaNormal`, `haceGuardiaVentana` y los dos mensajes (mismo texto que en la app). `motivoNoDisponible` recibe `required bool guardiaNormal`. |
| `backend/lib/src/almacen.dart` | `_leer`: si `guardia_normal` falta o no es `bool`, queda `false`. |
| `backend/lib/src/datos_de_ejemplo.dart` | `'guardia_normal': false` en los 12 vecinos. |
| `backend/lib/src/api.dart` | `_registrar` lo guarda en `false`. `_actualizarVecino` valida con 400/409 antes de tocar nada, y también antes de cambiar el teléfono; lo copia si es `bool` y, si no viene, deja el que estaba. `_anotarse` lo lee del almacén, nunca del pedido, y elige el lugar con `haceGuardiaVentana`. |
| `backend/README.md` | Campo `guardia_normal`, filas de `PUT /vecinos/<id>` y `PUT /turnos/…`, ejemplo en la fila del 409 y nota en la cuenta de Rosa. |

### Pruebas
`test/ayudas/falsos.dart`, `test/unit/dominio_test.dart`, `test/unit/servicios_http_test.dart`, `test/unit/persistencia_test.dart`, `test/unit/repositorios_test.dart`, `test/unit/view_models_test.dart`, `test/widget_test.dart`, `test/accesibilidad_test.dart`, `backend/test/reglas_test.dart` y `backend/test/api_test.dart`.

### No toqué
`specs/aviso_turno_incompleto/` ni la entrada de la feature 21 en `feature_list.json`. El cambio `pending → spec_ready` que aparece en ese archivo lo hizo el otro agente.

## Decisiones y desvíos

1. **Grupo nuevo `InicioViewModel` en `view_models_test.dart` (T16).** La task pide ponerla en el "grupo de `InicioViewModel`", pero ese grupo no existía: las pruebas del inicio estaban dentro de "Alertas tardías…". Armé un grupo propio con ese nombre.
2. **En T19 usé `pumpAndSettle` en lugar de `pump`.** El evento del bus llega en un microtask que corre después del primer frame, así que con un solo `pump` la pantalla todavía no se había redibujado.
3. **En T20, `UniqueKey` en el `MaterialApp`.** Cada prueba arma el perfil varias veces (apagado, prendido y guardando el cambio). Sin una clave nueva, `ConViewModel` reutilizaba el ViewModel de la primera vez, con la sesión anterior.
4. **En T25, `null` también da 400.** `guardia_normal: null` viene en el cuerpo y no es booleano, así que responde 400 como `"si"` y `1`. La regla de la API y la del simulado coinciden en esto (`containsKey` + `is! bool`).
5. **Orden de validación en `PUT /vecinos/<id>`:** primero el rol (403, como ya estaba), después `guardia_normal` (400 y luego 409) y recién ahí los demás campos y el cambio de teléfono. Así, un rechazo por `guardia_normal` no cambia ningún dato, tampoco el teléfono de ingreso (R36, probado).
6. Paquetes nuevos: ninguno. `PerfilViewModel` y `TurnosViewModel` siguen importando solo `foundation.dart` y archivos puros (`arquitectura_test.dart` en verde).

## Trazabilidad

| Requisito | Prueba |
|---|---|
| R1 | `test/unit/dominio_test.dart` › JSON › guardia_normal true se lee como activada |
| R2 | `test/unit/dominio_test.dart` › JSON › sin guardia_normal o con un valor que no es true queda desactivada; `test/unit/persistencia_test.dart` › Sesión › una sesión guardada con guardia normal la recupera y una vieja sin el campo queda desactivada |
| R3 | `test/unit/dominio_test.dart` › JSON › guardia_normal viaja en el JSON, ida y vuelta; › copyWith conserva la guardia normal |
| R4 | `test/unit/persistencia_test.dart` › Sesión › una sesión guardada con guardia normal la recupera…; `test/unit/servicios_http_test.dart` › Sesión contra la API › cambiar la guardia normal manda solo guardia_normal y guarda el vecino que devuelve (restaurar) |
| R5 | App: `dominio_test.dart` › Reglas de turnos › un mayor sin guardia normal es guardia de ventana. Simulado: `repositorios_test.dart` › Guardia normal contra el servidor simulado › Rosa sin guardia normal se anota como guardia de ventana. Backend: `reglas_test.dart` › Guardia normal › un mayor sin guardia normal es guardia de ventana |
| R6 | App: `dominio_test.dart` › un mayor con guardia normal es patrullero. Simulado: `repositorios_test.dart` › Rosa con guardia normal se anota en la patrulla. Backend: `reglas_test.dart` › un mayor con guardia normal es patrullero |
| R7 | App: `dominio_test.dart` › un menor es patrullero con o sin guardia normal. Backend: `reglas_test.dart` › un menor es patrullero con o sin guardia normal. Simulado: `repositorios_test.dart` › un menor no puede activarla (el menor no puede quedar con `true`). Sobre el simulado `anotarse` sigue igual y usa la misma regla de dominio |
| R8 | `view_models_test.dart` › Guardia normal en PerfilViewModel › un mayor puede elegir la guardia normal y un menor no; `widget_test.dart` › Perfil: guardia normal › un mayor la ve apagada con su texto |
| R9 | `view_models_test.dart` › un mayor puede elegir… y un menor no; `widget_test.dart` › un menor no ve la opción |
| R10 | `view_models_test.dart` › arranca desactivada y el rol es guardia de ventana; `widget_test.dart` › un mayor la ve apagada con su texto |
| R11 | `widget_test.dart` › un mayor la ve apagada con su texto; `accesibilidad_test.dart` › Guardia normal (guías y 200 % con el interruptor apagado) |
| R12 | `widget_test.dart` › al tocarla espera al servidor y después queda prendida; `accesibilidad_test.dart` › Guardia normal (prendido) |
| R13 | `widget_test.dart` › al tocarla espera al servidor… (`cambiosDeGuardiaNormal == [true]`); `view_models_test.dart` › al confirmar queda activada…; `servicios_http_test.dart` › cambiar la guardia normal manda solo guardia_normal… |
| R14 | `view_models_test.dart` › mientras espera al servidor está cambiando; `widget_test.dart` › al tocarla espera al servidor… ("Guardando el cambio", `onChanged` null) |
| R15 | `view_models_test.dart` › al confirmar queda activada, el rol es patrullaje y avisa por el bus; `widget_test.dart` › al tocarla espera al servidor y después queda prendida |
| R16 | `view_models_test.dart` › al confirmar queda activada… (y vuelve a "guardia de ventana"); `widget_test.dart` › al tocarla… (chip "Turnos: patrullaje") |
| R17 | `servicios_http_test.dart` › cambiar la guardia normal manda solo guardia_normal y guarda el vecino que devuelve |
| R18 | `view_models_test.dart` › si el servidor la rechaza devuelve su mensaje…; `widget_test.dart` › si el servidor la rechaza muestra el mensaje y queda apagada; `servicios_http_test.dart` › si la API rechaza la guardia normal, la sesión queda como estaba |
| R19 | `view_models_test.dart` › sin conexión devuelve el mensaje de conexión…; `widget_test.dart` › sin conexión muestra el aviso de conexión y queda apagada |
| R20 | `view_models_test.dart` › si el servidor la rechaza… / sin conexión…; `widget_test.dart` › las mismas dos pruebas; `servicios_http_test.dart` › si la API rechaza la guardia normal, la sesión queda como estaba |
| R21 | `servicios_http_test.dart` › actualizar los datos no manda guardia_normal |
| R22 | `view_models_test.dart` › TurnosViewModel › al cambiar el perfil se redibuja con el rol nuevo; › dispose cancela la suscripción al perfil; `widget_test.dart` › al activar la guardia normal, Turnos ofrece "Anotarme" sin recargar |
| R23 | `dominio_test.dart` › un mayor con guardia normal choca con la patrulla completa aunque la guardia esté libre; `view_models_test.dart` › con guardia normal, la patrulla completa la deja sin anotarse y la guardia ocupada no |
| R24 | `dominio_test.dart` › un mayor con guardia normal puede anotarse en un turno con guardia ocupada y lugar en la patrulla; `view_models_test.dart` › con guardia normal, la patrulla completa la deja sin anotarse y la guardia ocupada no |
| R25 | `view_models_test.dart` › con guardia normal, un turno donde es guardia se describe como guardia de ventana |
| R26 | `view_models_test.dart` › sin guardia normal, un turno donde está en la patrulla se describe con su compañero |
| R27 | `view_models_test.dart` › InicioViewModel › el próximo turno se titula por el lugar que ocupa, no por la preferencia |
| R28 | `backend/test/api_test.dart` › Guardia normal › ingresar, GET /vecinos/yo y PUT /vecinos/<id> traen guardia_normal; › registrarse arranca sin guardia normal… |
| R29 | `backend/test/api_test.dart` › registrarse arranca sin guardia normal aunque el pedido la mande |
| R30 | `backend/test/api_test.dart` › un archivo de datos viejo sin guardia_normal se lee con false |
| R31 | `backend/test/api_test.dart` › ingresar, GET /vecinos/yo y PUT… (recorre todos los vecinos de ejemplo) |
| R32 | `backend/test/api_test.dart` › Rosa activa la guardia normal y queda guardada |
| R33 | `backend/test/api_test.dart` › un menor puede mandar false |
| R34 | `backend/test/api_test.dart` › un menor no puede activarla: 409 |
| R35 | `backend/test/api_test.dart` › un valor que no es booleano: 400 |
| R36 | `backend/test/api_test.dart` › la guardia normal rechazada no cambia ningún dato |
| R37 | `backend/test/api_test.dart` › Rosa activa la guardia normal y queda guardada (PUT con solo `calle`); `repositorios_test.dart` › Rosa activa la guardia normal y queda guardada |
| R38 | `backend/test/api_test.dart` › Turnos › un mayor con guardia normal se anota en la patrulla |
| R39 | `backend/test/api_test.dart` › Turnos › un mayor de 70 queda como guardia de ventana; › un mayor que desactiva la guardia normal vuelve a ser guardia de ventana |
| R40 | `backend/test/api_test.dart` › con guardia normal, la patrulla completa responde 409 aunque la guardia esté libre; `backend/test/reglas_test.dart` › un mayor con guardia normal choca con la patrulla completa… |
| R41 | `backend/test/api_test.dart` › con guardia normal sigue el máximo de 2 por mes; `reglas_test.dart` y `dominio_test.dart` › un mayor con guardia normal y 2 turnos en el mes choca con el máximo |
| R42 | App: `view_models_test.dart` › con guardia normal, un turno donde es guardia se describe como guardia de ventana. Simulado: `repositorios_test.dart` › cambiar la guardia normal no mueve los turnos ya tomados. Backend: `api_test.dart` › Turnos › cambiar la guardia normal no mueve los turnos ya tomados |
| R43 | `repositorios_test.dart` › Guardia normal contra el servidor simulado › Rosa activa la guardia normal y queda guardada |
| R44 | `repositorios_test.dart` › un menor no puede activarla |
| R45 | `repositorios_test.dart` › un valor que no es booleano se rechaza |
| R46 | `repositorios_test.dart` › quien se registra arranca sin guardia normal |
| R47 | `accesibilidad_test.dart` › Guardia normal › el perfil de un mayor cumple las guías |
| R48 | `accesibilidad_test.dart` › Guardia normal › el interruptor se anuncia con su título y su estado |
| R49 | `accesibilidad_test.dart` › Guardia normal › "Turnos" se anuncia como encabezado |
| R50 | `accesibilidad_test.dart` › Guardia normal › al 200 % se ve sin desbordes |

## `./init.sh` (resumen)

```
[OK] feature_list.json válido (21 features)
[OK] Specs presentes para las features sdd que ya no están en pending
[OK] flutter analyze sin avisos
[OK] dart analyze sin avisos en backend/
00:44 +563: All tests passed!        (app)
[OK] Pruebas de la app
00:00 +99: All tests passed!         (backend)
[OK] Pruebas del backend
[OK] Entorno listo. Podés empezar a trabajar.
```

Corrí `dart format` sobre todos los `.dart` que toqué.

## Prueba manual

No la hice: no tenía emulador en esta sesión. En la app sin API la opción no aparece, porque la sesión simulada es Clara (45 años). Para probarla a mano: `cd backend && dart run bin/servidor.dart`, después `flutter run --dart-define=API_URL=http://10.0.2.2:8080`, ingresar con Rosa (261 555-0177 / barrio1234), ir a Perfil › Turnos, activar la opción y revisar en Turnos que el botón diga "Anotarme".

## Cierre

- Review aprobado (`progress/review_guardia_normal_mayores.md`, APPROVED, sin cambios requeridos).
- `feature_list.json`: feature 20 pasa de `in_progress` a `done`. La entrada de la feature 21 no se tocó.
- `progress/history.md`: entrada de la feature 20 con resumen, verificación y pendientes que no bloquean (prueba manual, ícono del calendario y `_ResumenCupo`, separar el cambio de la feature 21 del commit).
- `progress/current.md`: vuelto a la plantilla vacía.
- Sin cambios en `lib/`, `test/`, `backend/` ni `specs/`. Sin commit ni push.
