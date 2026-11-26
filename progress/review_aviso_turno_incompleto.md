# Review — feature 21 (aviso_turno_incompleto)

**Veredicto:** APPROVED

Revisado sobre `feature/guardia_normal_mayores`, trabajo sin commitear
encima de 819f09f (feature 20, fuera de esta revisión) y del spec aprobado
en 7c83d46. Se leyeron `git diff` de los 17 archivos modificados y los
archivos nuevos `lib/domain/turno_incompleto.dart`,
`lib/ui/turno_incompleto/view_models/turno_incompleto_view_model.dart` y
`lib/ui/turno_incompleto/widgets/tarjeta_turno_incompleto.dart`.

## Trazabilidad

D = `test/unit/dominio_test.dart`, P = `test/unit/persistencia_test.dart`,
V = `test/unit/view_models_test.dart` › `Aviso de turno incompleto` (salvo
que diga `TurnosViewModel`), W = `test/widget_test.dart` › `Aviso de turno
incompleto`, A = `test/accesibilidad_test.dart`, Q =
`test/unit/arquitectura_test.dart`. Se leyó cada prueba.

- R1: [x] D › `Personas anotadas y turno incompleto` (las 6 verifican `personasAnotadas` 0/1/1/2/2/3)
- R2: [x] D › `un patrullero solo está incompleto y no se realiza`, `un guardia de ventana solo está incompleto y no se realiza`
- R3: [x] D › `un patrullero y un guardia de ventana se realiza`, `dos patrulleros se realiza`, `dos patrulleros y un guardia de ventana: 3 personas, se realiza`; W › `con Ernesto de guardia de ventana no hay aviso a las 21:30`
- R4: [x] D › `sin nadie: 0 personas, no está incompleto ni se realiza`
- R5: [x] D › `Temprano del 9 va de 20:00 a 22:00 del 9`
- R6: [x] D › `Noche del 9 va de 22:00 del 9 a 00:00 del 10`
- R7: [x] D › `Madrugada del 9 va de 00:00 a 02:00 del 10…`, `Madrugada del 31 de octubre empieza el 1 de noviembre`, `Madrugada del 31 de diciembre empieza el 1 de enero del año siguiente`
- R8: [x] D › `los textos de horario no cambian`
- R9: [x] D › `paraAvisar devuelve el turno incompleto del vecino en ventana`; V › `patrullera sola en la Noche del 9, a las 21:30…`; W › `a las 21:29 no hay aviso y a las 21:30…`, `en la pestaña Turnos el aviso está arriba…`
- R10: [x] D › `a las 21:29 no está en ventana`, `a las 21:30 justas está en ventana` (límite incluido); V › `a las 21:29 no hay aviso`; W › `a las 21:29 no hay aviso…`
- R11: [x] D › `a las 00:00 del 10 ya no está en ventana` (límite excluido), `Madrugada del 9: 23:29 no, 23:30 sí, 01:59 sí, 02:00 no`; V › `a las 00:00 del 10 el aviso se va`; W › `a las 00:00 del 10 el aviso ya no está`
- R12: [x] V › `con otro patrullero no hay aviso`, `con un guardia de ventana no hay aviso`; D › `paraAvisar no devuelve un turno del vecino con un guardia de ventana`
- R13: [x] V › `si se anota otra persona en TurnosFalsos, el siguiente revisar saca el aviso`; W › `si Sofía se vuelve a anotar, el aviso se va al minuto siguiente`
- R14: [x] D › `paraAvisar no devuelve el turno incompleto de otro vecino`; V › `el turno incompleto de otro vecino no da aviso`
- R15: [x] V › `si la vecina sale del turno y se publica TurnosActualizados, el aviso se va`
- R16: [x] V › `si sale el otro patrullero dentro de la ventana, el siguiente revisar muestra el aviso`
- R17: [x] D › `paraAvisar ordena por inicio y no repite…`; V › `con dos turnos incompletos en ventana hay dos avisos ordenados por inicio`
- R18: [x] V › `sin sesión no hay aviso`
- R19: [x] W › `el aviso está arriba del banner de alertas activas y de "Tu próximo turno"` (posición vertical)
- R20: [x] V (testWidgets) › `con empezarRevision, al mover el reloj a 21:30 y pasar 1 minuto aparece el aviso`; W › `a las 21:29 no hay aviso y a las 21:30, sin tocar nada…`
- R21: [x] V › `dentro de la ventana de un turno propio, revisar pide con refrescar: true`
- R22: [x] V › `sin turnos propios en ventana, revisar pide con refrescar: false`
- R23: [x] D › `mesesParaAvisar` (9/10, 1/11, 1/1/2027); V › `el 1/11 a las 00:30 se piden octubre y noviembre`
- R24: [x] W › `en segundo plano no aparece y al volver a primer plano aparece sin esperar el minuto`
- R25: [x] V (testWidgets) › `después de detenerRevision, pasar minutos no pide turnos`; W › misma prueba de ciclo de vida
- R26: [x] V › `si falla el pedido de un recálculo se sigue mostrando el aviso con los últimos turnos`
- R27: [x] W › `si fallan los turnos del aviso, el inicio muestra sus alertas y Turnos su calendario` (`_TurnosSoloDeOctubre`)
- R28: [x] V › `un recálculo que no cambia nada no notifica`; `revisar a las 21:30 hace aparecer el aviso y notifica` (exactamente 1)
- R29: [x] V › `patrullera sola en la Noche del 9…` (título exacto)
- R30: [x] V › `patrullera sola en la Noche del 9…` (texto exacto)
- R31: [x] V › `patrullera sola en la Madrugada del 31/10…` ("la noche del 31 al 1", texto exacto)
- R32: [x] W › `con el aviso a la vista no se mostró ninguna notificación ni hubo suscripciones push`
- R33: [x] W › misma prueba (`push.suscripciones == 0`); el ViewModel solo recibe `TurnosRepository` y llama a `obtenerTurnos`
- R34: [x] A › `en Turnos se anuncia con la etiqueta "<título>. <texto>" y como región en vivo`
- R35: [x] A › `tiene ícono además del color` (`Icons.event_busy` a la izquierda del título)
- R36: [x] A › `al 200 % se ven el título, el texto, la indicación y "Entendido" sin desbordes, en el inicio` / `…, en Turnos`; A › `Texto del sistema al 200 %` con las dos pantallas nuevas
- R37: [x] A › `Guías de accesibilidad` › `Inicio con aviso de turno incompleto`
- R38: [x] Q › `turno.dart y turno_incompleto.dart no importan Flutter`
- R39: [x] Q › prueba de ViewModels con `contains(...turno_incompleto_view_model.dart)`
- R40: [x] W › `en la pestaña Turnos el aviso está arriba de "Todos / Mis turnos", en el calendario y en "Mis turnos"`
- R41: [x] W › `el inicio y Turnos muestran los mismos avisos`
- R42: [x] W › `tocar el aviso del inicio abre Turnos en "Todos" con el viernes 9 de octubre elegido`
- R43: [x] W › misma prueba (parte del sábado 10 en "Mis turnos"); V `TurnosViewModel` › `mostrarTurno con una fecha del mes pasa a "Todos" y elige ese día`
- R44: [x] V `TurnosViewModel` › `mostrarTurno con una fecha de otro mes no cambia el día ni la vista` (el cambio de pestaña es el mismo `_verTurno` de R42)
- R45: [x] W › `tocar el aviso en Turnos no cambia la vista ni el día` (ver observación 2)
- R46: [x] W › `a las 21:29 no hay aviso y a las 21:30…` ("Tocá para ver tus turnos" + `Icons.chevron_right`)
- R47: [x] W › misma prueba ("Entendido"); A › pruebas al 200 % en las dos pestañas
- R48: [x] V › `cerrar saca ese aviso y notifica`; W › `"Entendido" en el inicio saca el aviso del inicio y de Turnos`, `"Entendido" en Turnos saca el aviso de las dos pestañas`
- R49: [x] V › `cerrar uno de dos avisos deja el otro`
- R50: [x] V › `un ViewModel nuevo con las mismas preferencias no muestra el aviso cerrado`; P › `guardar y leer devuelve las mismas claves`
- R51: [x] V › `si se anota otra persona, el cierre se borra de las preferencias…`, `si la vecina sale del turno, el cierre se borra`
- R52: [x] V › `si se anota otra persona, el cierre se borra…, y si después sale, el aviso vuelve`
- R53: [x] V › `un cierre de otro vecino no oculta el aviso de la vecina`; D › `dos vecinos en el mismo turno tienen claves distintas`
- R54: [x] V › `a las 00:00 del 10 el cierre se borra de las preferencias`
- R55: [x] V › `si falla la primera carga sin turnos, los cierres guardados siguen`
- R56: [x] V › `guardia de ventana sola en la Noche del 9…`; W › `una guardia de ventana sola ve "Tu guardia de ventana no se va a hacer"`
- R57: [x] V › `guardia de ventana sola en la Noche del 9…` (texto exacto); W › misma prueba (Temprano, texto exacto)
- R58: [x] V › `guardia de ventana sola en la Madrugada del 9…` ("la noche del 9 al 10", texto exacto)
- R59: [x] D › `un mayor de 70 con guardia normal anotado como patrullero no es guardia de ventana en ese turno`; V › `una vecina de 75 con guardia normal, sola como patrullera, ve el texto de patrullero`
- R60: [x] A › `en el inicio se anuncia como botón con la etiqueta "<título>. <texto>. Ver turnos" y como región en vivo` (`isButton`, `isLiveRegion`, acción `tap`)
- R61: [x] A › `"Entendido" se anuncia como botón con la etiqueta "Entendido. Ocultar este aviso"` (`isButton`, acción `tap`)
- R62: [x] A › `la parte tocable del inicio y "Entendido" miden al menos 48 x 48 dp`; A › `Guías de accesibilidad` (tap targets) en las dos pantallas nuevas
- R63: [x] A › `Guías de accesibilidad` › `Turnos con aviso de turno incompleto`

## Tasks

- T1–T26: [x] todas marcadas en `specs/aviso_turno_incompleto/tasks.md`.
- Desvíos 1–10 de `progress/impl_aviso_turno_incompleto.md`: justificados.
  El 1 (`onTap: onCerrar` en el `Semantics` de "Entendido") es necesario:
  con `excludeSemantics` y sin `onTap` el lector no podría activar el
  botón; la prueba de R61 verifica la acción `tap`. El 7 (vecina de 76
  registrada en vez de Clara) es la alternativa prevista en T21.

## Arquitectura y convenciones

- [x] Regla de incompleto: `lib/domain/turno_incompleto.dart:16` (`personasAnotadas == 1`), con `Turno.personasAnotadas` = patrulleros + guardia de ventana (`lib/domain/models/turno.dart:103`).
- [x] Madrugada D+1 00:00 con `DateTime` desbordado, sin sumar `Duration` (`lib/domain/models/turno.dart:34-47`); la Noche termina en `DateTime(a, m, d, 24)`.
- [x] Ventana [inicio − 30 min, fin): `lib/domain/turno_incompleto.dart:22-24` (`!isBefore` / `isBefore`).
- [x] Dominio sin Flutter: `turno_incompleto.dart` solo importa `models/turno.dart` y `models/vecino.dart`.
- [x] ViewModel: solo `dart:async` y `foundation.dart`; usa `ui/core/formato.dart` (Dart puro). `arquitectura_test.dart` verde y lo incluye.
- [x] Reloj inyectado, `Timer.periodic` en el ViewModel, arrancado por `empezarRevision()` y no en el constructor; `dispose` cancela temporizador y suscripción al bus (`turno_incompleto_view_model.dart:237-243`).
- [x] Refresco solo con un turno propio en ventana (`turno_incompleto_view_model.dart:114-134`); `_revisando` evita solapes de `revisar()`.
- [x] Cierres: conjunto de claves vecino|fecha|franja, intersección con los candidatos y guardado en `Preferencias` (`turno_incompleto_view_model.dart:185-193`); sin turnos obtenidos o sin sesión no se recorta (`:175-178`).
- [x] Notifica solo si cambia la lista (`_publicar`, `:202-208`).
- [x] Textos exactos de patrullero y de guardia de ventana, elegidos por el lugar en el turno y no por edad ni preferencia (`turno_incompleto_view_model.dart:35-49`), con voseo ("Sos", "salgas", "vigiles", "Tocá").
- [x] `PrincipalScreen` crea un solo ViewModel compartido, `AppLifecycleListener` (`onPause` → `detenerRevision`, `onResume` → `revisar` + `empezarRevision`), `_verTurno` y libera todo en `dispose` (`principal_screen.dart:93-109`, `:167-168`, `:176-179`). Los ViewModels se arman ahí como el resto; `lib/dependencias.dart` no necesitó cambios (todo lo que usa ya está en `d`).
- [x] Tarjeta: `Semantics` con `liveRegion`; en el inicio `button` + `onTap`, `ConstrainedBox(minHeight: 48)` e indicación con flecha; ícono `event_busy`; par de contraste "Texto sobre superficie" (`tarjeta_turno_incompleto.dart`).
- [x] Inicio: tarjetas primero, después de `AvisoSinConexion` (`inicio_screen.dart:105-122`). Turnos: antes del `SegmentedButton`, sin `onTap` (`turnos_screen.dart:100-116`).
- [x] Sin cambios en `backend/`, `pubspec.yaml`, `backend/pubspec.yaml`, `lib/dependencias.dart`, `inicio_view_model.dart` ni `reglas_turnos.dart` (`git diff --stat 819f09f`). La regla no la aplica el servidor: no corresponde duplicarla (design, punto 1).
- [x] Sin decisiones de plataforma (`Capacidades` / `Politicas` no aplican).
- [x] Sin `print` ni `debugPrint`.

### Observaciones (no bloquean)

1. `test/accesibilidad_test.dart`, prueba `la parte tocable del inicio y "Entendido" miden al menos 48 x 48 dp`: usa `find.descendant(of: tarjeta, matching: find.byType(InkWell)).first`, el antipatrón de `docs/verification.md`. El `OutlinedButton` también tiene un `InkWell`; hoy el primero es el de la parte tocable por el orden del árbol, pero sería más firme buscar el `InkWell` ancestro de `find.text(tituloAvisoTurno)`.
2. `test/widget_test.dart`, prueba `tocar el aviso en Turnos no cambia la vista ni el día`: verifica pestaña y vista pero no el día elegido. Por construcción no puede cambiar (la tarjeta de Turnos no tiene `onTap`), pero una aserción del día completaría R45.
3. `lib/ui/turno_incompleto/view_models/turno_incompleto_view_model.dart:153`: el conjunto se arma tomando `_cerrados` antes del `await` de la lectura; un `cerrar()` durante esa lectura se perdería en memoria. Solo puede pasar en el primer instante de la app (antes de que haya una tarjeta para tocar): es teórico.
4. `cargar()` (por el bus) y `revisar()` pueden correr a la vez y la respuesta más vieja pisar a la más nueva en `_turnosDelAviso`; se corrige en el recálculo siguiente.
5. Prueba manual sin hacer (sin dispositivo); el recorrido con reloj, ciclo de vida y las dos pestañas está cubierto por W.

## Checkpoints

- C1: [x] arnés completo; `./init.sh` sale con 0.
- C2: [x] una sola feature en `in_progress` (la 21); `progress/current.md` describe esta sesión; ninguna feature nueva en `done`.
- C3: [x] capas respetadas, dominio sin Flutter, ViewModel sin Flutter visual, todo por constructor, sin `Platform.isX`, sin paquetes nuevos; no cambió ninguna regla de `ReglasTurnos`.
- C4: [x] `flutter analyze` y `dart analyze` sin avisos; 661 pruebas de la app y 99 del backend en verde; ViewModel nuevo probado con falsos (`TurnosFalsos`, `SesionFalsa`, `RelojManual`, `preferenciasEnMemoria`); pantalla con pruebas de widgets y de accesibilidad; sin hora real ni internet.
- C5: [x] 48 dp, etiquetas, 200 % e ícono además del color, probados.
- C6: [x] sin temporales ni `print`. La entrada de `progress/history.md` se escribe al cerrar la feature (sigue en `in_progress` hasta esta aprobación).
- C7: [x] `specs/aviso_turno_incompleto/` completo, EARS, tasks en `[x]`, R1–R63 con prueba.

## Salida de init.sh

```
[OK]    feature_list.json válido (21 features)
[OK]    Specs presentes para las features sdd que ya no están en pending
[OK]    flutter analyze sin avisos
[OK]    dart analyze sin avisos en backend/
01:08 +661: All tests passed!
[OK]    Pruebas de la app
00:00 +99: All tests passed!
[OK]    Pruebas del backend
[OK]    Entorno listo. Podés empezar a trabajar.
(código de salida 0)
```

## Cambios requeridos

Ninguno. Las observaciones 1 a 4 pueden quedar como pendientes en
`progress/history.md` al cerrar la feature.
