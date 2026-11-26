# Review — feature 20 (guardia_normal_mayores)

**Veredicto:** APPROVED

Revisado sobre `feature/guardia_normal_mayores` (trabajo sin commitear encima
de 6d6a9bb). Se ignoró `specs/aviso_turno_incompleto/` y el cambio
`pending → spec_ready` de la feature 21 en `feature_list.json` (son de la
feature 21). No quedó nada a medias tras la interrupción del implementer:
todas las tasks están en `[x]`, cada prueba nombrada en el mapa existe con ese
nombre y verifica lo que dice, no hay `TODO`, `print`, `debugPrint` ni
`Platform.isX` en el diff, y `./init.sh` termina en verde.

## Trazabilidad
- R1: [x] `test/unit/dominio_test.dart` › guardia_normal true se lee como activada
- R2: [x] `test/unit/dominio_test.dart` › sin guardia_normal o con un valor que no es true queda desactivada (sin el campo, `si`, `1`, `false`); `test/unit/persistencia_test.dart` › una sesión guardada con guardia normal la recupera y una vieja sin el campo queda desactivada
- R3: [x] `test/unit/dominio_test.dart` › guardia_normal viaja en el JSON, ida y vuelta; › copyWith conserva la guardia normal
- R4: [x] `test/unit/persistencia_test.dart` › una sesión guardada con guardia normal la recupera…; `test/unit/servicios_http_test.dart` › cambiar la guardia normal manda solo guardia_normal… (reabre con `restaurar()`)
- R5: [x] app `dominio_test.dart` › un mayor sin guardia normal es guardia de ventana; simulado `repositorios_test.dart` › Rosa sin guardia normal se anota como guardia de ventana; backend `reglas_test.dart` › un mayor sin guardia normal es guardia de ventana (y `api_test.dart` › un mayor de 70 queda como guardia de ventana)
- R6: [x] app `dominio_test.dart` › un mayor con guardia normal es patrullero; simulado `repositorios_test.dart` › Rosa con guardia normal se anota en la patrulla; backend `reglas_test.dart` › un mayor con guardia normal es patrullero y `api_test.dart` › un mayor con guardia normal se anota en la patrulla
- R7: [x] app `dominio_test.dart` › un menor es patrullero con o sin guardia normal (incluye un menor con `true`); backend `reglas_test.dart` › un menor es patrullero con o sin guardia normal. El simulado usa la misma regla de dominio (`Vecino.esGuardiaVentanaEn`) y no deja que un menor quede con `true` (`repositorios_test.dart` › un menor no puede activarla)
- R8: [x] `view_models_test.dart` › un mayor puede elegir la guardia normal y un menor no; `widget_test.dart` › un mayor la ve apagada con su texto
- R9: [x] `view_models_test.dart` › un mayor puede elegir… y un menor no; `widget_test.dart` › un menor no ve la opción (sin título ni sección "Turnos")
- R10: [x] `view_models_test.dart` › arranca desactivada…; `widget_test.dart` › un mayor la ve apagada… (`value` false); `accesibilidad_test.dart` › el interruptor se anuncia… (`isToggled` según el valor)
- R11: [x] `widget_test.dart` › un mayor la ve apagada con su texto (texto exacto)
- R12: [x] `widget_test.dart` › al tocarla espera al servidor y después queda prendida (texto exacto)
- R13: [x] `widget_test.dart` › al tocarla… (`cambiosDeGuardiaNormal == [true]`); `view_models_test.dart` › al confirmar queda activada… (`[true, false]`); `servicios_http_test.dart` › cuerpo exacto `{guardia_normal: true}` a `PUT /vecinos/rosa`
- R14: [x] `view_models_test.dart` › mientras espera al servidor está cambiando; `widget_test.dart` › al tocarla… ("Guardando el cambio" y `onChanged` null)
- R15: [x] `view_models_test.dart` › al confirmar queda activada…; `widget_test.dart` › al tocarla… (`value` true)
- R16: [x] `view_models_test.dart` › al confirmar queda activada, el rol es patrullaje… (y vuelve a "guardia de ventana"); `widget_test.dart` › chip "Turnos: patrullaje"
- R17: [x] `servicios_http_test.dart` › cambiar la guardia normal manda solo guardia_normal y guarda el vecino que devuelve
- R18: [x] `view_models_test.dart` › si el servidor la rechaza devuelve su mensaje…; `widget_test.dart` › si el servidor la rechaza muestra el mensaje y queda apagada; `servicios_http_test.dart` › si la API rechaza…
- R19: [x] `view_models_test.dart` › sin conexión devuelve el mensaje de conexión…; `widget_test.dart` › sin conexión muestra el aviso de conexión y queda apagada
- R20: [x] `view_models_test.dart` (rechazo y sin conexión: `guardiaNormal` y `sesion.usuario` en false, sin evento en el bus); `widget_test.dart` (interruptor apagado); `servicios_http_test.dart` › si la API rechaza… (sesión y lo restaurado en false)
- R21: [x] `servicios_http_test.dart` › actualizar los datos no manda guardia_normal
- R22: [x] `view_models_test.dart` › al cambiar el perfil se redibuja con el rol nuevo; › dispose cancela la suscripción al perfil; `widget_test.dart` › al activar la guardia normal, Turnos ofrece "Anotarme" sin recargar
- R23: [x] `dominio_test.dart` › un mayor con guardia normal choca con la patrulla completa…; `view_models_test.dart` › con guardia normal, la patrulla completa la deja sin anotarse…
- R24: [x] `dominio_test.dart` › un mayor con guardia normal puede anotarse en un turno con guardia ocupada…; `view_models_test.dart` › … y la guardia ocupada no
- R25: [x] `view_models_test.dart` › con guardia normal, un turno donde es guardia se describe como guardia de ventana
- R26: [x] `view_models_test.dart` › sin guardia normal, un turno donde está en la patrulla se describe con su compañero ("Con Ana López" y "Sin compañero todavía")
- R27: [x] `view_models_test.dart` › InicioViewModel › el próximo turno se titula por el lugar que ocupa, no por la preferencia
- R28: [x] `backend/test/api_test.dart` › ingresar, GET /vecinos/yo y PUT /vecinos/<id> traen guardia_normal; › registrarse arranca sin guardia normal…
- R29: [x] `backend/test/api_test.dart` › registrarse arranca sin guardia normal aunque el pedido la mande
- R30: [x] `backend/test/api_test.dart` › un archivo de datos viejo sin guardia_normal se lee con false (sin el campo, `si`, y un `true` que se conserva)
- R31: [x] `backend/test/api_test.dart` › ingresar, GET… (recorre `almacen.vecinos`)
- R32: [x] `backend/test/api_test.dart` › Rosa activa la guardia normal y queda guardada
- R33: [x] `backend/test/api_test.dart` › un menor puede mandar false
- R34: [x] `backend/test/api_test.dart` › un menor no puede activarla: 409 (cuerpo exacto)
- R35: [x] `backend/test/api_test.dart` › un valor que no es booleano: 400 (`si`, `1`, `null`)
- R36: [x] `backend/test/api_test.dart` › la guardia normal rechazada no cambia ningún dato (incluye que el teléfono de ingreso no cambia)
- R37: [x] `backend/test/api_test.dart` › Rosa activa… (PUT con solo `calle` la conserva); `repositorios_test.dart` › Rosa activa la guardia normal y queda guardada
- R38: [x] `backend/test/api_test.dart` › Turnos › un mayor con guardia normal se anota en la patrulla
- R39: [x] `backend/test/api_test.dart` › un mayor de 70 queda como guardia de ventana; › un mayor que desactiva la guardia normal vuelve a ser guardia de ventana
- R40: [x] `backend/test/api_test.dart` › con guardia normal, la patrulla completa responde 409 aunque la guardia esté libre; `reglas_test.dart` › equivalente
- R41: [x] `backend/test/api_test.dart` › con guardia normal sigue el máximo de 2 por mes; `reglas_test.dart` y `dominio_test.dart` › equivalentes
- R42: [x] app `view_models_test.dart` › con guardia normal, un turno donde es guardia…; simulado `repositorios_test.dart` › cambiar la guardia normal no mueve los turnos ya tomados (en los dos sentidos); backend `api_test.dart` › cambiar la guardia normal no mueve los turnos ya tomados (en los dos sentidos)
- R43: [x] `repositorios_test.dart` › Rosa activa la guardia normal y queda guardada
- R44: [x] `repositorios_test.dart` › un menor no puede activarla (mensaje exacto, datos sin cambios, `false` aceptado)
- R45: [x] `repositorios_test.dart` › un valor que no es booleano se rechaza (mensaje exacto, datos sin cambios)
- R46: [x] `repositorios_test.dart` › quien se registra arranca sin guardia normal
- R47: [x] `accesibilidad_test.dart` › Guardia normal › el perfil de un mayor cumple las guías (apagado y prendido)
- R48: [x] `accesibilidad_test.dart` › el interruptor se anuncia con su título y su estado
- R49: [x] `accesibilidad_test.dart` › "Turnos" se anuncia como encabezado
- R50: [x] `accesibilidad_test.dart` › al 200 % se ve sin desbordes (apagado, prendido y guardando)

## Tasks
- T1 a T30: [x] (ninguna `[ ]` en `specs/guardia_normal_mayores/tasks.md`; el diff de ese archivo solo cambia `[ ]` por `[x]`, sin tocar el texto aprobado)

## Arquitectura y convenciones
- [x] Misma regla en los tres lados: `lib/domain/reglas_turnos.dart` (`haceGuardiaVentana` = 70+ y sin guardia normal), usada por `Vecino.esGuardiaVentanaEn` y por eso por `ServidorSimulado.anotarse`; `backend/lib/src/reglas.dart` (`haceGuardiaVentana`, `motivoNoDisponible` con `required bool guardiaNormal`). Mensajes idénticos en app y backend (probado en `reglas_test.dart` › los mensajes son los mismos que en la app).
- [x] La API no deja activarla a menores: `backend/lib/src/api.dart:171-187` valida 400/409 antes de armar el vecino nuevo y antes de `cambiarTelefono`; `false` siempre se acepta. `_anotarse` (`api.dart:392`) lee la preferencia del almacén, nunca del pedido. El simulado hace lo mismo (`lib/data/services/simulados/servidor_simulado.dart:98-110`).
- [x] El registro fuerza `false` en la API (`api.dart:149`) y en el simulado (`servidor_simulado.dart:82`); `Almacen._leer` normaliza a `false` (`backend/lib/src/almacen.dart:165-167`); datos de ejemplo con `false` en los dos lados.
- [x] Los turnos ya tomados no se mueven: la preferencia solo se consulta al anotarse (ningún código recorre turnos al cambiarla). "Mis turnos" (`lib/ui/turnos/view_models/turnos_view_model.dart:147`, `esGuardiaEn`) y el inicio (`lib/ui/inicio/view_models/inicio_view_model.dart:160`) describen por el lugar ocupado.
- [x] Capas: el widget solo llama a `_vm.cambiarGuardiaNormal`; el ViewModel llama a `SesionRepository.cambiarGuardiaNormal`; el repositorio reutiliza `VecinosService.actualizar`. Sin piezas nuevas que armar en `lib/dependencias.dart` (no cambia, como dice el design).
- [x] MVVM: `PerfilViewModel` y `TurnosViewModel` importan solo `foundation.dart` y archivos puros (`error_del_servidor.dart` es Dart puro). `test/unit/arquitectura_test.dart` verde dentro de `./init.sh`.
- [x] La suscripción nueva de `TurnosViewModel` a `PerfilActualizado` se cancela en `dispose` (`turnos_view_model.dart:215`), con prueba.
- [x] `lib/ui/perfil/widgets/perfil_screen.dart:73-77` toma el `ScaffoldMessenger` antes del `await`; el `build` crece con una clase de widget (`_OpcionGuardiaNormal`), no con un método `_buildX`.
- [x] Accesibilidad del interruptor: `SwitchListTile` de ancho completo, sin alturas fijas, estado comunicado por texto además del color, encabezado con `_TituloSeccion`; pruebas en `test/accesibilidad_test.dart` (guías, semántica, encabezado, 200 %).
- [x] Textos en voseo ("Hacés", "Te anotás", "Revisá", "probá").
- [x] Sin paquetes nuevos: `pubspec.yaml` y `backend/pubspec.yaml` sin cambios.
- [x] Sin decisiones de plataforma (no aplica `Capacidades`/`Politicas`).
- [x] Desvíos justificados en `progress/impl_guardia_normal_mayores.md` (grupo `InicioViewModel` nuevo, `pumpAndSettle` en T19, `UniqueKey` en T20, `null` da 400, orden de validación). Ninguno contradice el spec.

## Checkpoints
- C1: [x] arnés completo; `./init.sh` con código 0.
- C2: [x] una sola feature `in_progress` (la 20); `progress/current.md` describe la sesión activa.
- C3: [x] capas, MVVM (`arquitectura_test.dart` verde), armado por constructor, sin `Platform.isX`, sin paquetes nuevos, regla cambiada en app, simulado y backend con pruebas en los dos lados.
- C4: [x] `flutter analyze` y `dart analyze` sin avisos; 563 pruebas de la app y 99 del backend en verde; falsos de `test/ayudas/falsos.dart` y `relojDePrueba`; la pantalla tiene pruebas de widgets y de accesibilidad.
- C5: [x] 48 dp, etiquetas, 200 % y estado no solo por color, probados.
- C6: [x] sin temporales ni `print`/`debugPrint`; la feature sigue en `in_progress` (correcto hasta el cierre). La entrada en `progress/history.md` y el paso a `done` le tocan al leader al cerrar la sesión.
- C7: [x] `specs/guardia_normal_mayores/` completo, EARS, tasks en `[x]`, R1 a R50 con prueba.

## Salida de init.sh
```
[OK]    flutter analyze sin avisos
[OK]    dart analyze sin avisos en backend/
00:59 +563: All tests passed!
[OK]    Pruebas de la app
00:00 +99: All tests passed!
[OK]    Pruebas del backend
[OK]    Entorno listo. Podés empezar a trabajar.
exit=0
```

## Cambios requeridos
Ninguno.

## Observaciones (no bloquean)
1. La prueba manual (nivel 6 de `docs/verification.md`, recomendada) no se hizo porque no había emulador. Conviene recorrerla contra la API con la cuenta de Rosa antes de integrar a `develop`, como indica `progress/impl_guardia_normal_mayores.md`.
2. El ícono propio del calendario y `_ResumenCupo` (`lib/ui/turnos/widgets/turnos_screen.dart:31` y `:98`) siguen la preferencia actual y no el lugar ocupado. Es lo que dice la decisión 4 del design, pero un mayor con turnos de los dos tipos ve un solo ícono para todos. Se puede revisar en una feature futura.
3. Al cerrar, el commit de esta feature no tiene que incluir el cambio de la feature 21 en `feature_list.json` ni `specs/aviso_turno_incompleto/`, salvo que el leader decida commitearlos aparte.
