# Implementación — estado_alerta (feature 19)

- **Rama:** `feature/estado_alerta` (sin commitear, como pidió el leader).
- **Spec:** `specs/estado_alerta/` (R1–R66, T1–T49, todas `[x]`; R56–R66 y T35–T49 son la ampliación, ver la sección "Ampliación").
- **Estado:** `in_progress` (reabierta para la ampliación), lista para el reviewer. No se marcó `done`.
- **Paquetes nuevos:** ninguno (ni en `pubspec.yaml` ni en `backend/pubspec.yaml`).
- **`lib/dependencias.dart`:** sin cambios, como dice el design.

## Archivos tocados

### App (`lib/`)

| Archivo | Cambio |
|---|---|
| `lib/domain/reglas_alertas.dart` | `mensajeSinPermisoEstado` y `puedeCambiarEstado({reportadaPor, vecino})`; importa `models/vecino.dart` |
| `lib/domain/avisos_tardios.dart` | `tituloAvisoReapertura`, `tituloAvisoReaperturaTardia`, `cuerpoAvisoReapertura` |
| `lib/data/services/simulados/servidor_simulado.dart` | `_vecinoDeLaSesion` (arranca en Clara; `ingresar` y `registrar` lo fijan); `cambiarEstadoDeAlerta` valida estado ("Ese estado no existe."), existencia y permiso con `ReglasAlertas` |
| `lib/data/repositories/avisos_recibidos_repository.dart` | `horaDelServidor()` en la interfaz y en `AvisosRecibidosRepositoryLocal` (comparte `_ahoraDelServidor` con `registrarLlegada`, sin guardar nada) |
| `lib/data/services/notificaciones_service.dart` | `avisarReapertura` y `avisarReaperturaTardia` en la interfaz, `NotificacionesServiceLocales` (mismo `_mostrar`: canal, id por alerta y payload) y `NotificacionesServiceNinguno` |
| `lib/data/services/push_service.dart` | `avisoPushReabierta`, `reabiertaEnDesdeDatosPush`; `procesarAvisoPush` deriva a `_procesarReapertura` si `aviso == 'reabierta'` (sin `registrarLlegada`, clasifica con `reabierta_en` y `horaDelServidor()`) |
| `lib/ui/alerta_detalle/view_models/detalle_alerta_view_model.dart` | `mensajeErrorCambioEstado`, `avisoCambioDeEstado`, `ConfirmacionCambioEstado`, `confirmacionParaCambio`; en el VM `puedeCambiarEstado`, `puedeMarcarFalsaAlarma` (antes `puedeCerrarla`), `cambiandoEstado`, `cambiarEstado(EstadoAlerta)`; se borró `marcarResuelta` y `_cerrar` (`marcarFalsaAlarma` hace lo mismo que antes) |
| `lib/ui/alerta_detalle/widgets/confirmar_cambio_estado.dart` (nuevo) | `confirmarCambioDeEstado(context, confirmacion:, nuevo:)` con los dos diálogos del design |
| `lib/ui/alerta_detalle/widgets/detalle_alerta_screen.dart` | `_elegirEstado` (mensajero antes del `await`, confirmación según `confirmacionParaCambio`, aviso con `avisoCambioDeEstado`, el detalle no se cierra); `_ControlDeEstado` y `_ErrorDeEstado` (clases de widget); se quitó "Marcar como resuelta"; "Fue una falsa alarma" con `puedeMarcarFalsaAlarma` |
| `lib/ui/principal/vigilante_de_alertas.dart` | `_resueltas`; detecta reaperturas, publica `AlertasActualizadas` y, con avisos activos, `avisarReapertura` por cada una de otro vecino; no toca llegadas |

### Backend (`backend/`)

| Archivo | Cambio |
|---|---|
| `backend/lib/src/reglas.dart` | `ReglasAlertas.mensajeSinPermisoEstado` y `puedeCambiarEstado({reportadaPor, vecinoId, rol})` (importa `Roles` de `almacen.dart`) |
| `backend/lib/src/api.dart` | `_cambiarEstado` usa la regla con el rol del almacén (comentario "RF-05 ampliado"); guarda el estado anterior y llama a `_notificarReapertura` (con `try/catch`) solo de `resuelta` a otro estado |
| `backend/lib/src/push_service.dart` | `enviarReapertura` en `PushService`, `PushServiceNinguno` y `PushServiceFcm` (`avisoReabierta`, `_comoTexto` y `_enviar` compartidos con `enviarAlerta`); comentario "alerta nueva o reabierta" |
| `backend/README.md` | Fila de `PATCH /alertas/<id>`, fila 403 y párrafo del aviso de reapertura con `aviso` y `reabierta_en` |

### Pruebas

| Archivo | Cambio |
|---|---|
| `test/ayudas/falsos.dart` | `miembroDeLaComision`; `AlertasFalsas.errorAlCambiar` y `demoraAlCambiar`; `NotificacionesFalsas.reaperturas` y `reaperturasTardias`; `AvisosRecibidosFalsos.horaDelServidor` |
| `test/unit/dominio_test.dart` | Grupos `ReglasAlertas.puedeCambiarEstado` y `Textos del aviso de reapertura` |
| `test/unit/repositorios_test.dart` | Cambio de estado contra el simulado (por rol, reabrir, estado o alerta inexistente, sesión al reingresar); `horaDelServidor` |
| `test/unit/notificaciones_test.dart` | Grupo `Aviso push de reapertura`; pruebas de reapertura en `Vigilante de alertas` |
| `test/unit/view_models_test.dart` | Grupo `DetalleAlertaViewModel` reescrito (permisos, cambiar, confirmación, errores) |
| `test/widget_test.dart` | Grupos `Detalle: estado de la alerta` y `Estado: lista y mapa`; ayuda `pantallaAlta` |
| `test/accesibilidad_test.dart` | 4 pantallas nuevas en `pantallas` (guías y 200 %) y grupo `Estado de la alerta` |
| `backend/test/reglas_test.dart` | Grupo `ReglasAlertas.puedeCambiarEstado` |
| `backend/test/api_test.dart` | `PushServiceFalso.enviarReapertura` (`reaperturas`); `clavesDeUnaAlerta` pasa a nivel de archivo; pruebas por rol en `Alertas` (reemplazan `solo quien la reportó puede cerrarla (RF-05)`); grupo `Avisos push: reapertura` |

## Decisiones de implementación y desvíos

1. **El diálogo de confirmación lleva `semanticLabel` = título (R40).** El
   design suponía que `AlertDialog` ya nombra la ruta con el título; en
   Android (la plataforma de las pruebas) la nombra con el texto genérico
   de `alertDialogLabel` ("Alert"/"Alerta") y el título queda como un hijo
   más. Con `semanticLabel: titulo` el lector anuncia "¿Marcar la alerta
   como resuelta?" / "¿Volver a abrir la alerta?" al abrirse. El resto del
   diálogo es igual al design (y al de `confirmar_cierre_sos.dart`).
2. **`container: true` en el encabezado, el indicador y el error del
   control.** Las pruebas de accesibilidad mostraron que, como el control
   es un solo elemento del `ListView`, el encabezado "Estado de la alerta",
   el indicador "Cambiando el estado" y el error se fusionaban en un único
   nodo de semántica (y todo quedaba marcado como encabezado). Cada parte
   tiene ahora su propio nodo; las opciones ya lo tenían por `RadioListTile`.
3. **`cambiarEstado` no hace nada si ya hay un cambio en curso.** Además de
   "mismo estado" y "sin permiso" (design), devuelve `false` si
   `cambiandoEstado` es true. Evita un doble pedido si llegara un segundo
   toque antes de que se redibuje deshabilitado. La pantalla tiene el mismo
   chequeo antes de abrir el diálogo.
4. **`cambiandoEstado` comparte `_estado` con `marcarFalsaAlarma`**, como
   dice el design: durante la falsa alarma también se ve "Cambiando el
   estado" (lo que pasa de verdad: la alerta pasa a Resuelta) y las
   opciones se deshabilitan.
5. **El error de "Fue una falsa alarma"** ("No pudimos cerrar la alerta.
   Probá de nuevo.", sin cambios) se muestra en el mismo lugar que el del
   cambio de estado (debajo de las opciones). Quien ve "Fue una falsa
   alarma" es quien la reportó, que siempre ve el control.
6. **El ViewModel importa `ui/core/presentacion_alerta.dart`** para
   `avisoCambioDeEstado` (lo pide el design). Ese archivo importa
   `material.dart` por `IconData`/`Color`, pero no es un widget; es el
   único ViewModel que lo hace. Lo anoto por C3.
7. **El servidor simulado valida el estado con `EstadoAlerta.values`**
   (`_estadosValidos`), el mismo conjunto `activa`/`en_atencion`/`resuelta`
   que la API.
8. **Pruebas de widgets del detalle con una pantalla de 540 x 1200 dp**
   (`pantallaAlta`): el `ListView` del detalle no construye el control con
   la pantalla de prueba por defecto (800 x 600). Las pruebas de
   accesibilidad siguen con su `configurarPantalla` (360 dp; 200 % en 800).
9. **Backend:** el grupo nuevo se llama `Avisos push: reapertura` (al lado
   de `Avisos push`) y `clavesDeUnaAlerta` pasó a nivel de archivo para
   usarlo en los dos grupos. Las entradas de accesibilidad de los diálogos
   llevan el sufijo "(diálogo)", como las existentes.
10. **Pruebas de más** (no pedidas, cubren casos de borde): `un cambio que
    sale bien borra el error anterior`, `la comisión cambia el estado de
    una alerta ajena` (VM), `"Fue una falsa alarma" la deja resuelta como
    antes` (VM), `el simulado rechaza un estado que no existe o una alerta
    que no existe`, `al volver a ingresar la sesión vuelve a la vecina de
    ejemplo`, `reabrir a en atención también se avisa` (vigilante), `sin
    rol conocido no puede si no la reportó` (backend).

## Trazabilidad

Abreviaturas: `arq` = `test/unit/arquitectura_test.dart`, `tar` =
`test/unit/avisos_tardios_test.dart`, `dom` = `test/unit/dominio_test.dart`, `rep` =
`test/unit/repositorios_test.dart`, `not` =
`test/unit/notificaciones_test.dart`, `vm` =
`test/unit/view_models_test.dart`, `wid` = `test/widget_test.dart`, `a11y` =
`test/accesibilidad_test.dart`, `api` = `backend/test/api_test.dart`,
`reg` = `backend/test/reglas_test.dart`.

| Requisito | Prueba |
|---|---|
| R1 | `vm` › DetalleAlertaViewModel › quien la reportó puede cambiar el estado; `wid` › Detalle: estado de la alerta › quien la reportó ve "Estado de la alerta" con Activa, En atención y Resuelta en orden; `dom` › ReglasAlertas.puedeCambiarEstado › quien la reportó puede |
| R2 | `vm` › la comisión puede cambiar el estado de una alerta ajena; `wid` › la comisión ve el control en una alerta ajena; `dom` › la comisión puede aunque no la haya reportado |
| R3 | `vm` › un vecino común no puede cambiar el estado de una alerta ajena; `wid` › un vecino común ve el estado pero no el control; `dom` › un vecino común no puede si no la reportó; `dom` › sin sesión no puede |
| R4 | `wid` › un vecino común ve el estado pero no el control (`ChipEstado` con ícono y "Activa"); `wid` › la opción elegida es el estado actual (chip "En atención") |
| R5 | `wid` › la opción elegida es el estado actual |
| R6 | `vm` › una alerta resuelta se puede cambiar; `wid` › en una alerta resuelta las tres opciones están habilitadas |
| R7 | `wid` › elegir "En atención" no pide confirmación, cambia el estado de arriba y la opción, …; `vm` › cambiar a En atención pide el cambio, actualiza la alerta y devuelve true; `vm` › confirmacionParaCambio con los 9 pares de estados |
| R8 | `vm` › cambiar al estado actual no pide nada; `wid` › tocar la opción actual no pide nada |
| R9 | `vm` › mientras cambia, cambiandoEstado es true; `wid` › mientras cambia, las opciones están deshabilitadas y se ve "Cambiando el estado"; `a11y` › Estado de la alerta › el indicador se anuncia "Cambiando el estado" |
| R10 | `wid` › elegir "En atención" no pide confirmación, … y el detalle sigue abierto; `wid` › "Sí, está resuelta" cierra el diálogo, pide el cambio y muestra …; `vm` › cambiar a En atención pide el cambio, actualiza la alerta y devuelve true |
| R11 | `wid` › elegir "En atención" … muestra "Cambiaste el estado a En atención."; `vm` › avisoCambioDeEstado dice "Cambiaste el estado a En atención." |
| R12 | `wid` › Estado: lista y mapa › poner En atención "Actividad sospechosa" se ve en "Alertas cerca tuyo" |
| R13 | `wid` › Estado: lista y mapa › poner Resuelta "Moto a alta velocidad" la quita de "Alertas cerca tuyo" |
| R14 | `wid` › Estado: lista y mapa › el pin del mapa dice el estado nuevo |
| R15 | `wid` › Estado: lista y mapa › una alerta propia cambiada se ve con el estado nuevo en "Mis alertas" |
| R16 | `vm` › si la API rechaza muestra su mensaje tal cual y el estado no cambia; `wid` › si la API rechaza se ve su mensaje y el estado anterior |
| R17 | `vm` › sin conexión muestra "No pudimos cambiar el estado. Probá de nuevo." y el estado no cambia; `wid` › sin conexión se ve "No pudimos cambiar el estado. Probá de nuevo." y el estado anterior |
| R18 | `vm` › si la API rechaza …; `vm` › sin conexión …; `wid` › si la API rechaza se ve su mensaje y el estado anterior; `wid` › sin conexión se ve … y el estado anterior |
| R19 | `wid` › no está el botón "Marcar como resuelta" (los tres roles) |
| R20 | `vm` › solo quien la reportó ve "Fue una falsa alarma" y solo si no está resuelta; `vm` › "Fue una falsa alarma" la deja resuelta como antes; `wid` › "Fue una falsa alarma" sigue cerrando el detalle con "Cancelaste la alerta: falsa alarma" sin diálogo |
| R21 | `api` › Alertas › quien la reportó cambia el estado; `reg` › ReglasAlertas.puedeCambiarEstado › quien la reportó puede |
| R22 | `api` › Alertas › la comisión cambia el estado de una alerta ajena; `reg` › la comisión puede aunque no la haya reportado |
| R23 | `api` › Alertas › un vecino común no puede cambiar el estado de una alerta ajena; `reg` › un vecino común no puede si no la reportó; `reg` › el mensaje es el mismo que el de la app |
| R24 | `api` › Alertas › se puede reabrir una alerta resuelta; `rep` › el simulado reabre una alerta resuelta; `vm` › reabrir una resuelta la deja activa |
| R25 | `rep` › la comisión cambia el estado de una alerta ajena en el simulado; `rep` › quien la reportó cambia el estado en el simulado |
| R26 | `rep` › un vecino común no cambia una alerta ajena en el simulado; `dom` › ReglasAlertas.puedeCambiarEstado › el mensaje es el mismo que el del servidor |
| R27 | `a11y` › Guías de accesibilidad › Detalle de alerta, Detalle de una alerta SOS, Detalle de alerta con error de estado (`androidTapTargetGuideline`, `iOSTapTargetGuideline`) |
| R28 | `a11y` › Estado de la alerta › el control de estado tiene encabezado y cada opción se anuncia con su nombre y si está elegida |
| R29 | `a11y` › Estado de la alerta › cada opción muestra el ícono y el nombre del estado; `a11y` › Guías › Detalle de alerta (`textContrastGuideline`) |
| R30 | `a11y` › Estado de la alerta › el error de cambio de estado es una región en vivo con ícono |
| R31 | `a11y` › Texto del sistema al 200 % › Detalle de alerta, Detalle de una alerta SOS, Detalle de alerta con error de estado, Detalle de alerta de un vecino común |
| R32 | `a11y` › Estado de la alerta › el detalle se lee en orden |
| R33 | `wid` › elegir "Resuelta" muestra "¿Marcar la alerta como resuelta?" con su texto y los botones, y no pide nada mientras está abierto; `vm` › confirmacionParaCambio con los 9 pares de estados |
| R34 | `wid` › en una alerta resuelta, elegir "En atención" o "Activa" muestra "¿Volver a abrir la alerta?" con su texto; `vm` › confirmacionParaCambio con los 9 pares de estados |
| R35 | `wid` › "Sí, está resuelta" cierra el diálogo, pide el cambio y muestra "Cambiaste el estado a Resuelta."; `wid` › "Sí, volver a abrirla" pide el cambio y muestra el estado nuevo |
| R36 | `wid` › cerrar el diálogo sin confirmar no pide nada › con "No, dejarla como está" / con "No, dejarla resuelta" / tocando fuera del diálogo / con el botón Atrás |
| R37 | `wid` › cerrar el diálogo sin confirmar no pide nada (los 4 casos: opción elegida y chip siguen en el estado actual, sin `SnackBar` ni error) |
| R38 | `a11y` › Guías › Confirmar marcar como resuelta (diálogo), Confirmar volver a abrir (diálogo); `a11y` › Estado de la alerta › al 200 % los botones del diálogo se apilan y miden al menos 48 dp de alto |
| R39 | `a11y` › Texto del sistema al 200 % › Confirmar marcar como resuelta (diálogo), Confirmar volver a abrir (diálogo); `a11y` › al 200 % los botones del diálogo se apilan y miden al menos 48 dp de alto |
| R40 | `a11y` › Estado de la alerta › los diálogos de confirmación anuncian el título y cada botón por su texto |
| R41 | `api` › Avisos push: reapertura › reabrir una alerta resuelta a activa envía el aviso de reapertura; › reabrir a en_atencion también lo envía; › PushServiceFcm.enviarReapertura manda al tópico alertas con aviso "reabierta" y reabierta_en, y descarta las resueltas |
| R42 | `api` › Avisos push: reapertura › pasar entre activa y en_atencion no envía nada; › pasar a resuelta no envía nada; › elegir el mismo estado no envía nada |
| R43 | `api` › Avisos push: reapertura › un pedido rechazado no envía nada (401, 403, 400, 404) |
| R44 | `api` › Avisos push: reapertura › si el push falla al reabrir, el estado se guarda y responde 200 |
| R45 | `api` › Avisos push: reapertura › el aviso de reapertura solo trae las claves de la alerta; › PushServiceFcm.enviarReapertura … (claves de `data`) |
| R46 | `not` › Aviso push de reapertura › una reapertura a tiempo muestra el aviso de reapertura; `dom` › Textos del aviso de reapertura (título, SOS, cuerpo, sin dirección) |
| R47 | `not` › una reapertura con 30 minutos de demora muestra el aviso de reapertura tardío; `dom` › el título tardío agrega la hora de la reapertura |
| R48 | `not` › una reapertura con 3 horas de demora no muestra nada |
| R49 | `not` › Aviso push de reapertura › la reapertura de una alerta propia no se avisa |
| R50 | `not` › Aviso push de reapertura › con los avisos apagados no se avisa |
| R51 | `not` › sin reabierta_en, con reabierta_en inválido o con estado resuelta no se avisa; `not` › reabiertaEnDesdeDatosPush lee entero y texto |
| R52 | `not` › una reapertura no cambia la llegada guardada del aviso original; `rep` › Llegadas de los avisos › horaDelServidor suma el desfase y no guarda ninguna llegada; `not` › Vigilante de alertas › una reapertura no guarda llegadas |
| R53 | `not` › Vigilante de alertas › una alerta ajena que estaba resuelta y se reabrió muestra el aviso de reapertura; › reabrir a en atención también se avisa; (ampliación) › con 2 horas justas se avisa a tiempo |
| R54 | `not` › Vigilante de alertas › una reapertura publica AlertasActualizadas; › con los avisos apagados la reapertura no se avisa pero se publica AlertasActualizadas; › la reapertura de una alerta propia no se avisa (también publica); (ampliación) › con los avisos apagados la reapertura tardía no se avisa pero se publica AlertasActualizadas |
| R55 | `not` › Vigilante de alertas › la reapertura de una alerta propia no se avisa; › con los avisos apagados la reapertura no se avisa pero se publica AlertasActualizadas |
| R56 | `arq` › MVVM: los ViewModels no dependen de la vista › ningún ViewModel llega a dart:ui ni a package:flutter fuera de foundation |
| R57 | `arq` › textos_estado.dart no importa nada de Flutter |
| R58 | `vm` › Textos de los estados › etiqueta dice "Activa", "En atención" y "Resuelta"; › etiquetaFiltro dice "Activas", "En atención" y "Resueltas"; `vm` › DetalleAlertaViewModel › avisoCambioDeEstado dice "Cambiaste el estado a En atención." (sin cambios); además, las pruebas de widgets y accesibilidad que buscan esos textos pasan sin tocarlas |
| R59 | `arq` › ningún ViewModel llega a dart:ui… (la falla nombra la cadena, ver "Ampliación"); › el chequeo encuentra material.dart en presentacion_alerta.dart; › el chequeo sigue los imports indirectos (chip_estado.dart -> presentacion_alerta.dart -> material.dart); › con foundation prohibido, el chequeo también la encuentra |
| R60 | `not` › Vigilante de alertas › una reapertura encontrada después de más de 2 horas sin revisar se avisa como tardía sin hora (con título "Se reabrió una alerta: Robo" y `cuerpoAvisoTardio`); `tar` › Reapertura vista por el vigilante › 2 horas y 1 segundo es tardía; `not` › NotificacionesServiceNinguno.avisarReaperturaTardiaSinHora termina sin hacer nada |
| R61 | `not` › una reapertura encontrada después de más de 2 horas sin revisar se avisa como tardía sin hora (`reaperturas` vacía); › si la revisión del medio falla, la demora se mide desde la última que funcionó (`reaperturas` vacía) |
| R62 | `not` › con 2 horas justas se avisa a tiempo; › una revisión que funcionó reinicia la cuenta; `tar` › 2 horas justas desde la revisión anterior no es tardía; › unos segundos no es tardía; › una diferencia negativa no es tardía; y las pruebas de reapertura que ya existían del vigilante (reloj sin avanzar) |
| R63 | `not` › si la revisión del medio falla, la demora se mide desde la última que funcionó |
| R64 | `not` › la reapertura tardía de una alerta propia no se avisa; › con los avisos apagados la reapertura tardía no se avisa pero se publica AlertasActualizadas |
| R65 | `not` › una reapertura tardía no guarda llegadas |
| R66 | `not` › una alerta nueva encontrada después de más de 2 horas sin revisar se clasifica por creada_en |

Además, `not` › Vigilante › `una alerta que pasa de activa a en atención no se avisa` y `lo que ya estaba reabierto al abrir la app no se avisa` cubren los bordes de R53 (T18), y `not` › `un push sin aviso sigue el camino de siempre` cubre que el camino de alertas nuevas no cambió (T11).

## Pruebas existentes que cambiaron

- `vm` › `solo quien la reportó puede cerrarla`, `marcarla resuelta cambia su estado de verdad` y `si falla muestra un mensaje y la alerta sigue abierta` se reemplazaron por las del grupo nuevo (ver T13, T14, T16).
- `api` › `solo quien la reportó puede cerrarla (RF-05)` se reemplazó por `un vecino común no puede cambiar el estado de una alerta ajena` (con el mensaje nuevo).
- El resto de las pruebas que ya existían pasan sin cambios (incluida `rep` › `el servidor simulado devuelve el primer nombre de quien reportó`, que cambia `a1` con la sesión inicial de Clara).

## Verificación

`dart format` sobre `lib`, `test`, `backend/lib` y `backend/test` (solo
cambiaron archivos de esta feature). Sin `print`/`debugPrint` ni TODO
nuevos.

`./init.sh` completo, al final:

```
[OK]    feature_list.json válido (19 features)
[OK]    Specs presentes para las features sdd que ya no están en pending
[OK]    flutter pub get
[OK]    dart pub get en backend/
No issues found!
[OK]    flutter analyze sin avisos
No issues found!
[OK]    dart analyze sin avisos en backend/
00:50 +499: All tests passed!
[OK]    Pruebas de la app
00:00 +79: All tests passed!
[OK]    Pruebas del backend
[OK]    Entorno listo. Podés empezar a trabajar.
```

## Prueba manual

No se hizo (sin emulador en esta sesión). Recorrido sugerido para el
reviewer o el equipo: con el simulado, entrar como Clara (comisión), abrir
"Moto a alta velocidad" y pasarla a Activa (sin diálogo), después a
Resuelta (diálogo "¿Marcar la alerta como resuelta?"), volver al inicio y
ver que no está; abrir "Robo de celular" desde el mapa (filtro "Todas") y
reabrirla. Con la API (`cd backend && dart run bin/servidor.dart`), entrar
como Rosa y comprobar que en "Actividad sospechosa" (de Clara) no aparece
el control.

## Cierre

Después del APPROVED de `progress/review_estado_alerta.md` (2026-11-26):

- `feature_list.json`: la feature 19 (`estado_alerta`) pasa a `status: "done"` (las 19 features quedan en `done`).
- `progress/history.md`: nueva entrada al final con el resumen de la feature, la verificación (`./init.sh` verde, app 499, backend 79) y como pendientes que no bloquean las observaciones 1 a 3 del review, la prueba manual sin hacer y el commit de la rama.
- `progress/current.md`: vuelve a la plantilla vacía.
- Sin cambios en `lib/`, `test/` ni `backend/`. Sin commit ni push.

## Ampliación

La feature se reabrió (R56–R66, T35–T49, design puntos 10 y 11). T1–T34
no se rehicieron. Sin paquetes nuevos; `lib/dependencias.dart` y el
backend sin cambios.

### Archivos tocados

| Archivo | Cambio |
|---|---|
| `lib/ui/core/textos_estado.dart` (nuevo) | `extension TextosEstado on EstadoAlerta` con `etiqueta` y `etiquetaFiltro` (mismos textos); importa solo `../../domain/models/alerta.dart` |
| `lib/ui/core/presentacion_alerta.dart` | `PresentacionEstado` queda con `icono`, `color` y `colorSuave`; `export 'textos_estado.dart';`; comentario de la extensión actualizado |
| `lib/ui/alerta_detalle/view_models/detalle_alerta_view_model.dart` | Importa `../../core/textos_estado.dart` en vez de `presentacion_alerta.dart` (el comentario de `avisoCambioDeEstado` no nombraba `presentacion_alerta`; no hubo que tocarlo) |
| `lib/domain/avisos_tardios.dart` | `reaperturaDelVigilanteTardia({revisionAnterior, ahora})` con `demoraMaximaParaAvisar` |
| `lib/data/services/notificaciones_service.dart` | `avisarReaperturaTardiaSinHora(Alerta)` en la interfaz, en `NotificacionesServiceLocales` (`_mostrar` con `tituloAvisoReapertura` y `cuerpoAvisoTardio`, mismo id y payload) y en `NotificacionesServiceNinguno` (no hace nada) |
| `lib/ui/principal/vigilante_de_alertas.dart` | `required this._reloj` (`Reloj`) y `DateTime? _ultimaRevision`; en `revisar()`, después de `obtenerAlertas`, toma `ahora` y `anterior` y actualiza `_ultimaRevision` junto con `_conocidas` y `_resueltas`; reabiertas de otro vecino con avisos activos → `avisarReaperturaTardiaSinHora` si `anterior != null && reaperturaDelVigilanteTardia(...)`, si no `avisarReapertura`. Comentarios de la clase y de R53/R55 actualizados |
| `lib/ui/principal/widgets/principal_screen.dart` | Pasa `reloj: d.reloj` al vigilante |
| `test/ayudas/falsos.dart` | `RelojManual implements Reloj`; `NotificacionesFalsas.reaperturasTardiasSinHora` y `avisarReaperturaTardiaSinHora` |
| `test/unit/arquitectura_test.dart` (nuevo) | `importsVisuales(archivo, {permitirFoundation})` y el grupo `MVVM: los ViewModels no dependen de la vista` (5 pruebas) |
| `test/unit/view_models_test.dart` | Grupo `Textos de los estados` (importa `textos_estado.dart`, no `presentacion_alerta.dart`) |
| `test/unit/avisos_tardios_test.dart` | Grupo `Reapertura vista por el vigilante` (4 pruebas) |
| `test/unit/notificaciones_test.dart` | `crear()` del vigilante con `RelojManual` (empieza en `creada`); 8 pruebas nuevas del corte de 2 h y la de `NotificacionesServiceNinguno` |
| `docs/architecture.md` | Principio 1 (regla de R56, `arquitectura_test.dart`, textos en archivos puros de `lib/ui/core/`, íconos y colores solo en vistas); `textos_estado` en el árbol de `ui/core/`; "Qué NO hacer" |
| `CHECKPOINTS.md` | C3: casilla de los ViewModels con el texto del design (punto 10) |
| `specs/estado_alerta/tasks.md` | T35–T49 `[x]` |

### Decisiones y desvíos justificados

1. **Nombre del temporizador del vigilante.** El vigilante ya tenía un
   campo privado `Timer? _reloj` (el reloj periódico). El design pide
   `required this._reloj` de tipo `Reloj`, así que el `Timer?` pasó a
   llamarse `_temporizador`. Es un renombre privado, sin cambio de
   comportamiento (`enPrimerPlano` sigue igual y la prueba del ciclo de
   vida pasa sin cambios).
2. **T38 antes de T36.** Se escribió `arquitectura_test.dart` antes de
   cambiar el import del ViewModel para ver la falla de R59. Con el
   import viejo, la primera prueba falló con:

   ```
   Un ViewModel llega a una biblioteca visual de Flutter:
   lib/ui/alerta_detalle/view_models/detalle_alerta_view_model.dart -> lib/ui/core/presentacion_alerta.dart -> package:flutter/material.dart
   lib/ui/alerta_detalle/view_models/detalle_alerta_view_model.dart -> lib/ui/core/presentacion_alerta.dart -> lib/ui/core/tema/app_colors.dart -> package:flutter/material.dart
   ```

   Después de T36 pasa.
3. **Control de `presentacion_alerta.dart` con `contains`.** Ese archivo
   llega a `material.dart` por dos caminos (directo y por
   `tema/app_colors.dart`), así que la prueba de control verifica que la
   cadena directa esté en la lista en vez de comparar la lista entera.
4. **Prueba extra del chequeo.** `con foundation prohibido, el chequeo
   también la encuentra` confirma que `permitirFoundation: false`
   realmente prohíbe `foundation.dart` (si no, la prueba de R57 podría
   pasar en falso). No agrega requisitos.
5. **`dart:ui_*`.** Además de `dart:ui`, el chequeo trata como prohibidas
   las bibliotecas `dart:ui_…` (por ejemplo `dart:ui_web`), que son la
   misma capa visual. Hoy no hay ninguna en `lib/`.
6. **Selección de ViewModels.** `Directory('lib/ui').listSync(recursive:
   true)` filtrando rutas de la forma
   `lib/ui/<pantalla>/view_models/<x>.dart` (separador normalizado a `/`
   para Windows).

### Verificación de la ampliación

`dart format lib test` (solo cambió `arquitectura_test.dart` en su primera
versión). Sin `print`/`debugPrint` ni TODO nuevos.

`./init.sh` completo, al final:

```
[OK]    feature_list.json válido (19 features)
[OK]    Specs presentes para las features sdd que ya no están en pending
[OK]    flutter pub get
[OK]    dart pub get en backend/
No issues found!
[OK]    flutter analyze sin avisos
No issues found!
[OK]    dart analyze sin avisos en backend/
00:44 +519: All tests passed!
[OK]    Pruebas de la app
00:00 +79: All tests passed!
[OK]    Pruebas del backend
[OK]    Entorno listo. Podés empezar a trabajar.
```

App: 499 → 519 pruebas (+5 `arq`, +2 `vm`, +4 `tar`, +9 `not`). Backend:
79, sin cambios.

### Prueba manual de la ampliación

No se hizo (sin emulador). Recorrido sugerido: con la API, entrar como un
vecino común con los avisos activos y la app en primer plano, adelantar la
hora del teléfono más de 2 horas y, desde otra sesión de la comisión,
reabrir una alerta resuelta; la revisión siguiente muestra "Se reabrió una
alerta: <tipo>" con "Llegó con demora por falta de señal. Puede que ya no
esté pasando.".

### Cierre de la ampliación

Después del APPROVED de la ampliación (`progress/review_estado_alerta.md` › "Revisión de la ampliación", 2026-11-26):

- `feature_list.json`: la feature 19 (`estado_alerta`) vuelve a `status: "done"` (las 19 features quedan en `done`).
- `progress/history.md`: se actualizó la entrada existente de la feature 19 (sin duplicarla): se sumó la ampliación (MVVM estricto con `textos_estado.dart` y `test/unit/arquitectura_test.dart`; reapertura tardía del vigilante con la regla de 2 h), la verificación (app 519, backend 79), se quitaron de los pendientes el import de `presentacion_alerta.dart` en el ViewModel y el vigilante sin regla de 2 h, y se agregaron las observaciones 1 a 3 de la revisión de la ampliación.
- `progress/current.md`: vuelve a la plantilla vacía.
- Sin cambios en `lib/`, `test/` ni `backend/`. Sin commit ni push.
