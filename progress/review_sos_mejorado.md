# Review — feature 17 (sos_mejorado)

**Veredicto:** APPROVED

Revisé `feature/sos_mejorado` con el trabajo sin commitear (`git status` /
`git diff`, más `lib/ui/core/widgets/marca_sos.dart` y
`lib/ui/sos/widgets/confirmar_cierre_sos.dart`, que no tienen seguimiento). Spec en 4d8adf2.

## Trazabilidad
- R1: [x] `test/unit/view_models_test.dart` › SosViewModel › enviar crea una alerta sos con el título "Intento de robo" (categoría `sos` y `tipo` de la alerta creada en `AlertasFalsas`)
- R2: [x] `test/unit/view_models_test.dart` › enviar manda la descripción, la dirección y quien reporta como antes (descripción literal, dirección de zona, `ubicacionesEnviadas`, `reportadaPor` = clara); `test/unit/ubicacion_test.dart` sin cambios y verde
- R3: [x] `backend/test/api_test.dart:466-490` › la alerta nueva queda a nombre de quien tiene la sesión (manda "Intento de robo"; verifica `categoria`, `tipo`, `estado` y `creada_en` del servidor)
- R4: [x] `test/unit/avisos_tardios_test.dart` › el aviso tardío de un SOS "Intento de robo" dice "SOS de Marta 15:10"
- R5: [x] `test/widget_test.dart` › SOS enviado › la pantalla del SOS enviado muestra "Volver" (verifica que está debajo de "Fue una falsa alarma")
- R6: [x] `test/widget_test.dart` › "Volver" cierra el SOS, deja la alerta activa y avisa dónde encontrarla (`activa`, `cambiosDeEstado == 0`, vuelve a la pantalla base)
- R7: [x] `test/widget_test.dart` › el botón Atrás en el SOS enviado hace lo mismo que "Volver" (`handlePopRoute`, mismo aviso, `activa`, 0 cambios)
- R8: [x] las dos pruebas anteriores (`cerradoConAviso(avisoSigueActiva)`)
- R9: [x] `test/widget_test.dart` › "Ya estoy a salvo" pide confirmación con los textos acordados
- R10: [x] `test/widget_test.dart` › confirmar "Sí, estoy a salvo" resuelve la alerta y cierra con aviso
- R11: [x] ídem (aviso "Marcaste la alerta como resuelta" y no aparece el de "sigue activa")
- R12: [x] `test/widget_test.dart` › "Seguir con la alerta" en "Ya estoy a salvo" no cambia nada; Atrás en el diálogo de "Ya estoy a salvo" no cambia nada (`activa`, `cambiosDeEstado == 0`, sigue "Alerta enviada")
- R13: [x] `test/widget_test.dart` › "Fue una falsa alarma" pide confirmación con los textos acordados
- R14: [x] `test/widget_test.dart` › confirmar "Sí, fue una falsa alarma" resuelve la alerta y cierra con aviso
- R15: [x] ídem (aviso "Cancelaste la alerta: fue una falsa alarma")
- R16: [x] `test/widget_test.dart` › "Seguir con la alerta" en "Fue una falsa alarma" no cambia nada; tocar fuera del diálogo de "Fue una falsa alarma" no cambia nada
- R17: [x] `test/widget_test.dart` › si falla el cierre se avisa que se haga desde "Mis alertas"; `test/unit/view_models_test.dart` › si falla cerrarAlerta devuelve false y la alerta sigue activa
- R18: [x] `test/accesibilidad_test.dart` › Guías de accesibilidad › SOS: alerta enviada / SOS: confirmar "Ya estoy a salvo" (diálogo) / SOS: confirmar "Fue una falsa alarma" (diálogo) (las 4 guías, `test/accesibilidad_test.dart:122-125`)
- R19: [x] `test/accesibilidad_test.dart` › Texto del sistema al 200 % › las mismas tres entradas (con `mostrar` hasta "Volver" y hasta el botón de confirmar)
- R20: [x] `test/widget_test.dart` › las dos pruebas "pide confirmación…" (`OutlinedButton` para "Seguir con la alerta" y `FilledButton` para confirmar, con `find.widgetWithText`)
- R21: [x] `test/accesibilidad_test.dart` › SOS enviado › el botón "Volver" y los botones de los diálogos se anuncian con su texto (etiqueta exacta + acción tap; título de cada diálogo)
- R22: [x] `test/widget_test.dart` › SOS y robo con el mismo título › la tarjeta del SOS lleva la marca SOS y la de robo no; "Mis alertas reportadas" muestra la marca SOS en la alerta enviada
- R23: [x] `test/widget_test.dart` › el pin del SOS se anuncia "Alerta SOS: Intento de robo, …" y su resumen muestra la marca…
- R24: [x] `test/widget_test.dart` › el detalle del SOS muestra la marca y lee "SOS: Intento de robo"
- R25: [x] tarjeta, resumen y detalle de `a3` sin marca (las mismas tres pruebas)
- R26: [x] `test/widget_test.dart` › la tarjeta del SOS se anuncia "Alerta SOS: intento de robo, …" y la de robo como antes (etiqueta completa exacta)
- R27: [x] `test/widget_test.dart` › el pin del SOS se anuncia… (etiqueta completa exacta)
- R28: [x] el resumen y el detalle se buscan por la etiqueta "SOS: Intento de robo"; `test/unit/dominio_test.dart` › tituloConCategoria antepone "SOS: " solo a las alertas sos
- R29: [x] etiquetas exactas de la tarjeta y el pin de `a3`; título "Intento de robo" en el resumen y el detalle de `a3`; prueba de dominio de `tituloConCategoria`
- R30: [x] `test/widget_test.dart` › la marca SOS no se anuncia aparte (Inicio, detalle y resumen) + `ExcludeSemantics` en `lib/ui/core/widgets/marca_sos.dart:15`
- R31: [x] `test/accesibilidad_test.dart` › Inicio con una alerta SOS / Resumen de una alerta SOS en el mapa / Detalle de una alerta SOS (guías y 200 %); Colores › Los pares de la marca SOS están en AppColors + Todos los pares de AppColors cumplen el contraste mínimo
- R32: [x] `test/unit/dominio_test.dart` › Informe de alertas › cuenta todos los SOS en una sola fila "SOS"; un robo titulado "SOS" no se suma a la fila de los SOS
- R33: [x] ídem (filas "SOS (Robo):1" y "sos (Robo):1", "Pedido de ayuda (SOS)" de robo tal cual) + pruebas de la feature 14 sin cambios
- R34: [x] `test/unit/dominio_test.dart` › el CSV trae una sola fila de los SOS (`Por tipo,SOS,2` y ninguna `Por tipo,SOS: `)

Feature 14 (`specs/informe_alertas/`): las pruebas que ya había en el grupo `Informe de alertas` no cambiaron (el helper `crearAlerta` solo sumó `categoria`, con `robo` por defecto, que antes era el valor fijo) y siguen verdes junto con la prueba de widgets del informe. R3 de esa feature (orden por cantidad y después alfabético) se mantiene: `_ordenar` y `toCsv()` no cambiaron (`lib/domain/informe_alertas.dart`). R10 (CSV) queda cubierto como antes.

## Tasks
- T1 a T21: [x] todas marcadas en `specs/sos_mejorado/tasks.md` y hechas como dicen (lo verifiqué en el diff).

## Arquitectura y convenciones
- [x] Dominio puro: `lib/domain/models/alerta.dart` (`prefijoSos`, `tituloConCategoria`) y `lib/domain/informe_alertas.dart` (importa `avisos_tardios.dart`, también Dart puro) no usan Flutter.
- [x] `SosViewModel` sigue sin `BuildContext` ni widgets; solo cambió el título vía `tipoAlertaSos` (`lib/ui/sos/view_models/sos_view_model.dart:15,63`).
- [x] La pantalla solo habla con su ViewModel; los diálogos (`lib/ui/sos/widgets/confirmar_cierre_sos.dart`) son UI pura y devuelven un booleano (sin respuesta cuenta como no confirmado).
- [x] Cancelar no cambia nada: `_confirmarYCerrar` sale antes de `cerrarAlerta` si el vecino no confirmó (`lib/ui/sos/widgets/sos_screen.dart:66-67`); `_volver` no llama al ViewModel (`sos_screen.dart:51-60`). Las pruebas verifican `cambiosDeEstado == 0`.
- [x] `PopScope` con `canPop` falso solo en el paso `enviada`, dentro de un `ListenableBuilder` (`sos_screen.dart:84-92`); `context.mounted` después de cada `await`.
- [x] No hay piezas nuevas que armar en `lib/dependencias.dart` (ni servicios ni repositorios nuevos).
- [x] Sin `Platform.isX` y sin paquetes nuevos (`pubspec.yaml`, `pubspec.lock` y `backend/pubspec.yaml` sin cambios); el backend no cambió de código (solo `backend/test/api_test.dart`).
- [x] Features 18 y 19 sin tocar: `feature_list.json` sin cambios (18 y 19 en `pending`), y nada cambió en Arrebato, el inicio, los datos de ejemplo ni el control de estado del detalle.
- [x] Textos en voseo y con los literales del spec; nombres y sufijos según `docs/conventions.md`; el formateador no deja cambios pendientes.
- [x] Accesibilidad: los diálogos, "Volver" y la marca SOS en tarjeta, resumen y detalle están en la lista `pantallas` de `test/accesibilidad_test.dart` (4 guías + 200 %); el estado no se comunica solo con color (la marca lleva ícono + texto; confirmar va con relleno y cancelar con contorno).
- [x] Las etiquetas de las alertas que no son SOS quedan idénticas a las de antes (`lib/ui/core/widgets/tarjeta_alerta.dart:32-39`, `lib/ui/core/widgets/mapa_barrio.dart:93-100`), verificadas con las etiquetas exactas de `a3`.

Observaciones que no bloquean (fuera de los requisitos, para el leader):
- `lib/ui/sos/widgets/sos_screen.dart:68`: mientras `cerrarAlerta()` está en curso después de confirmar, "Volver" y Atrás siguen habilitados. Con una red lenta, el vecino podría salir con el aviso "sigue activa" y que la alerta quede resuelta igual. Pasaba antes de esta feature (doble toque) y el spec no lo pide; queda como candidato a un ajuste futuro.
- En el detalle y el resumen de un SOS, el lector también lee la descripción "Un vecino pidió ayuda con el botón SOS." (R2 la deja fija). R30 se cumple porque la marca no se anuncia aparte.
- Las pruebas de R12 cubren Atrás en "Ya estoy a salvo" y las de R16 cubren tocar fuera en "Fue una falsa alarma" (reparto acordado en T10/T11; los dos diálogos salen de la misma función `confirmarCierreSos`).

## Checkpoints
- C1: [x] archivos del arnés presentes; `./init.sh` termina con código 0.
- C2: [x] una sola feature en `in_progress` (17); `progress/current.md` describe la sesión activa.
- C3: [x] capas, constructor, plataforma y paquetes en regla; no se tocaron reglas de turnos.
- C4: [x] `flutter analyze` y `dart analyze` sin avisos; 333 pruebas de la app y 48 del backend en verde; las pruebas usan falsos y `appDePrueba`, sin hora real ni internet.
- C5: [x] 48 dp, etiquetas, 200 % y estado no solo por color, todo con pruebas.
- C6: [x] sin `print` ni archivos temporales; la feature está en `in_progress`, que es lo correcto hasta el cierre; la entrada de `progress/history.md` de esta sesión la agrega el leader al cerrar (la última sesión cerrada, feature 16, tiene la suya).
- C7: [x] `specs/sos_mejorado/` completo, en EARS, con las tasks en `[x]` y cada requisito con su prueba.

## Salida de init.sh

    No issues found! (ran in 3.3s)
    [OK]    flutter analyze sin avisos
    No issues found!
    [OK]    dart analyze sin avisos en backend/
    ── 5. Pruebas ──
    00:36 +333: All tests passed!
    [OK]    Pruebas de la app
    00:00 +48: All tests passed!
    [OK]    Pruebas del backend
    ── 6. Resumen ──
    [OK]    Entorno listo. Podés empezar a trabajar.
    EXIT=0

## Cambios requeridos
Ninguno.
