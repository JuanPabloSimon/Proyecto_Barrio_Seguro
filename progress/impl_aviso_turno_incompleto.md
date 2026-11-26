# Implementación — aviso_turno_incompleto (feature #21)

- **Rama:** `feature/guardia_normal_mayores` (a partir de 819f09f, con la
  feature 20 ya integrada).
- **Spec:** `specs/aviso_turno_incompleto/` (aprobado, 7c83d46).
- **Estado:** listo para revisión. No se marcó `done`, no hubo commit ni push.

## Archivos tocados

| Capa | Archivo | Cambio |
|---|---|---|
| domain | `lib/domain/models/turno.dart` | `Franja.horaInicio`, `empiezaAlDiaSiguiente`, `duracionEnHoras`, `inicioEn`, `finEn`; `Turno.personasAnotadas`, `inicio`, `fin`. `horario` y `desdeNombre` sin cambios. |
| domain | `lib/domain/turno_incompleto.dart` (nuevo) | `ReglasTurnoIncompleto` con las firmas del design. Solo importa `models/turno.dart` y `models/vecino.dart`. |
| data | `lib/data/services/local/preferencias.dart` | `claveAvisosTurnoCerrados` (en `todasLasClaves`), `avisosTurnoCerrados()`, `guardarAvisosTurnoCerrados()`. |
| ui | `lib/ui/turno_incompleto/view_models/turno_incompleto_view_model.dart` (nuevo) | `AvisoTurnoIncompleto` y `TurnoIncompletoViewModel`. |
| ui | `lib/ui/turno_incompleto/widgets/tarjeta_turno_incompleto.dart` (nuevo) | `TarjetaTurnoIncompleto`. |
| ui | `lib/ui/inicio/widgets/inicio_screen.dart` | Parámetros `turnoIncompleto` y `onVerTurno`; tarjetas primero en `_ContenidoInicio` (después de "Sin conexión"). |
| ui | `lib/ui/turnos/view_models/turnos_view_model.dart` | `mostrarTurno(fecha)`. |
| ui | `lib/ui/turnos/widgets/turnos_screen.dart` | Parámetro opcional `turnoIncompleto`; tarjetas sin `onTap` antes del `SegmentedButton`. |
| armado | `lib/ui/principal/widgets/principal_screen.dart` | Crea el ViewModel compartido (`..cargar()..empezarRevision()`), `AppLifecycleListener`, `_verTurno`, `dispose`. |
| pruebas | `test/ayudas/falsos.dart` | `TurnosFalsos.pedidos`. |
| pruebas | `test/ayudas/app_de_prueba.dart` | `appDePrueba({Reloj? reloj})`. |
| pruebas | `test/unit/dominio_test.dart` | Grupos `Horarios de las franjas`, `Personas anotadas y turno incompleto`, `Ventana de aviso de turno incompleto`, `Lugar en el turno y clave de cierre`. |
| pruebas | `test/unit/persistencia_test.dart` | Grupo `Avisos de turno cerrados`. |
| pruebas | `test/unit/view_models_test.dart` | Grupo `Aviso de turno incompleto` y dos pruebas de `mostrarTurno` en `TurnosViewModel`. |
| pruebas | `test/widget_test.dart` | Grupo `Aviso de turno incompleto` y el falso `_TurnosSoloDeOctubre`. |
| pruebas | `test/accesibilidad_test.dart` | Dos `Pantalla` nuevas y grupo `Aviso de turno incompleto`. |
| pruebas | `test/unit/arquitectura_test.dart` | Dominio sin Flutter y el ViewModel nuevo en la lista. |
| progreso | `specs/aviso_turno_incompleto/tasks.md`, `progress/current.md` | Tasks marcadas y bitácora. |

Sin cambios en `backend/`, `lib/dependencias.dart`,
`inicio_view_model.dart`, `reglas_turnos.dart` ni `pubspec.yaml` (ningún
paquete nuevo).

## Decisiones y desvíos (justificados)

1. **`Semantics(onTap: onCerrar)` en "Entendido".** El design pide
   `Semantics(button: true, label: ..., excludeSemantics: true)` sobre el
   `OutlinedButton`. Con `excludeSemantics` se pierde la acción del botón
   de adentro y el lector de pantalla no podría activarlo; por eso el
   `Semantics` lleva también `onTap: onCerrar` (y `container: true`), igual
   que la parte tocable del inicio en el design. La prueba de R61 verifica
   `isButton` y la acción `tap`.
2. **Si falla uno de los meses del aviso**, se descarta ese pedido entero
   y se sigue con los últimos turnos completos (R26): no se mezcla un mes
   nuevo con uno viejo.
3. **`_publicar` compara clave + título + texto**, no solo las claves
   (design punto 7). Es un superconjunto: con la misma clave el texto no
   cambia en la práctica, y si cambiara (lugar en el turno) se redibuja.
   R28 se sigue cumpliendo ("un recálculo que no cambia nada no notifica").
4. **Sin sesión no se piden turnos** (además de dejar la lista vacía,
   R18): ahorra pedidos y no recorta cierres.
5. **Constructor del ViewModel:** `sesion`, `reloj` y `preferencias` se
   reciben con `required this._x` (estilo del repo y regla
   `prefer_initializing_formals`); desde afuera los nombres son los del
   design (`sesion:`, `reloj:`, `preferencias:`).
6. **Pruebas con el servidor simulado.** La nota del design ("lanzar el
   pedido, `await tester.pump()` y después esperar") no alcanza: un
   `pump()` sin duración no dispara el `Future.delayed(Duration.zero)` del
   simulado y la prueba se cuelga (lo comprobé). Las ayudas hacen
   `pump(1 ms)` hasta que el pedido termina (`enElServidor` en
   `widget_test.dart`; un `pump(1 ms)` en `abrirConAvisoDeTurno` de
   `accesibilidad_test.dart`).
7. **"Clara como guardia de ventana sola" (T21).** Clara tiene 45 años y
   el simulado la anota como patrullera. La prueba registra con
   `dependencias.sesion.registrar` a una vecina de 76 (queda con la sesión
   abierta), la anota con `dependencias.turnos.anotarse` en la Temprano
   del 9/10 (vacía: queda como guardia de ventana sola) y abre la app a
   las 19:30. Es la opción "armar el turno con `dependencias.turnos`" que
   prevé la task.
8. **R27 (falla solo el aviso).** La prueba arma la app con un
   `TurnosRepository` que envuelve al real y falla para cualquier mes que
   no sea octubre de 2026 (`_TurnosSoloDeOctubre`), con el reloj el 1/11 a
   las 00:30: el aviso pide noviembre (falla) y octubre; el inicio y
   Turnos piden solo octubre y se ven completos.
9. **"Los mismos avisos" en las dos pestañas (R41).** El `IndexedStack` no
   construye la lista de la pestaña oculta, así que cada lista se lee con
   su pestaña a la vista.
10. **P6 y P8:** se implementaron con la opción asumida (recálculo cada 1
    minuto, refrescando solo dentro de la ventana de un turno propio; "Tu
    próximo turno" y la tarjeta de la franja no cambian).

Ningún requisito quedó sin implementar y no se tocó nada fuera de lo que
lista el design.

## Trazabilidad R → pruebas

D = `test/unit/dominio_test.dart`, P = `test/unit/persistencia_test.dart`,
V = `test/unit/view_models_test.dart` (grupo `Aviso de turno incompleto`
salvo que diga otra cosa), W = `test/widget_test.dart` (grupo `Aviso de
turno incompleto`), A = `test/accesibilidad_test.dart`, Q =
`test/unit/arquitectura_test.dart`.

| R | Pruebas |
|---|---|
| R1 | D `Personas anotadas y turno incompleto` (las 6, `personasAnotadas` 0/1/1/2/2/3) |
| R2 | D `un patrullero solo está incompleto…`, `un guardia de ventana solo está incompleto…`; V `patrullera sola en la Noche del 9…` |
| R3 | D `un patrullero y un guardia de ventana se realiza`, `dos patrulleros se realiza`, `dos patrulleros y un guardia de ventana…`; V `con un guardia de ventana no hay aviso`; W `con Ernesto de guardia de ventana no hay aviso a las 21:30` |
| R4 | D `sin nadie: 0 personas, no está incompleto ni se realiza` |
| R5 | D `Temprano del 9 va de 20:00 a 22:00 del 9` |
| R6 | D `Noche del 9 va de 22:00 del 9 a 00:00 del 10` |
| R7 | D `Madrugada del 9 va de 00:00 a 02:00 del 10…`, `Madrugada del 31 de octubre empieza el 1 de noviembre`, `Madrugada del 31 de diciembre empieza el 1 de enero…` |
| R8 | D `los textos de horario no cambian`, `un turno leído del JSON calcula inicio y fin…` |
| R9 | D `paraAvisar devuelve el turno incompleto del vecino en ventana`; V `patrullera sola en la Noche del 9, a las 21:30…`; W `a las 21:29 no hay aviso y a las 21:30…`, `en la pestaña Turnos el aviso está arriba…` |
| R10 | D `a las 21:29 no está en ventana`, `a las 21:30 justas está en ventana`, `paraAvisar no devuelve un turno incompleto fuera de ventana`; V `a las 21:29 no hay aviso`; W `a las 21:29 no hay aviso…` |
| R11 | D `a las 23:59 está en ventana`, `a las 00:00 del 10 ya no está en ventana`, `Madrugada del 9: …`; V `a las 00:00 del 10 el aviso se va`; W `a las 00:00 del 10 el aviso ya no está` |
| R12 | D `paraAvisar no devuelve un turno del vecino con un guardia de ventana`; V `con otro patrullero no hay aviso`, `con un guardia de ventana no hay aviso`; W `con Ernesto…` |
| R13 | V `si se anota otra persona en TurnosFalsos, el siguiente revisar saca el aviso`; W `si Sofía se vuelve a anotar, el aviso se va al minuto siguiente` |
| R14 | D `paraAvisar no devuelve el turno incompleto de otro vecino`; V `el turno incompleto de otro vecino no da aviso` |
| R15 | V `si la vecina sale del turno y se publica TurnosActualizados, el aviso se va` |
| R16 | V `si sale el otro patrullero dentro de la ventana, el siguiente revisar muestra el aviso` |
| R17 | D `paraAvisar ordena por inicio y no repite…`; V `con dos turnos incompletos en ventana hay dos avisos ordenados por inicio` |
| R18 | V `sin sesión no hay aviso` |
| R19 | W `el aviso está arriba del banner de alertas activas y de "Tu próximo turno"` |
| R20 | V (testWidgets) `con empezarRevision, al mover el reloj a 21:30 y pasar 1 minuto aparece el aviso`; W `a las 21:29 no hay aviso y a las 21:30, sin tocar nada…` |
| R21 | V `dentro de la ventana de un turno propio, revisar pide con refrescar: true` |
| R22 | V `sin turnos propios en ventana, revisar pide con refrescar: false` |
| R23 | D `mesesParaAvisar el 9/10…`, `…el 1/11 a las 00:30…`, `…el 1/1/2027…`; V `el 1/11 a las 00:30 se piden octubre y noviembre`, `patrullera sola en la Madrugada del 31/10…` |
| R24 | W `en segundo plano no aparece y al volver a primer plano aparece sin esperar el minuto` |
| R25 | V (testWidgets) `después de detenerRevision, pasar minutos no pide turnos`, `dispose cancela el temporizador`; W `en segundo plano no aparece…` |
| R26 | V `si falla el pedido de un recálculo se sigue mostrando el aviso con los últimos turnos` |
| R27 | W `si fallan los turnos del aviso, el inicio muestra sus alertas y Turnos su calendario` |
| R28 | V `un recálculo que no cambia nada no notifica`; `revisar a las 21:30 hace aparecer el aviso y notifica` (una sola vez) |
| R29 | V `patrullera sola en la Noche del 9, a las 21:30…` (título); W `a las 21:29 no hay aviso y a las 21:30…` |
| R30 | V `patrullera sola en la Noche del 9, a las 21:30…` (texto exacto) |
| R31 | V `patrullera sola en la Madrugada del 31/10…` (texto exacto, "la noche del 31 al 1") |
| R32 | W `con el aviso a la vista no se mostró ninguna notificación ni hubo suscripciones push` (todas las listas de `NotificacionesFalsas` vacías) |
| R33 | W misma prueba (`PushFalso.suscripciones == 0`); por construcción el ViewModel no recibe `NotificacionesService` ni `PushService` y solo llama a `obtenerTurnos` |
| R34 | A `en Turnos se anuncia con la etiqueta "<título>. <texto>" y como región en vivo` |
| R35 | A `tiene ícono además del color` |
| R36 | A `al 200 % se ven el título, el texto, la indicación y "Entendido" sin desbordes, en el inicio` y `…, en Turnos`; A `Texto del sistema al 200 %` → las dos pantallas nuevas |
| R37 | A `Guías de accesibilidad` → `Inicio con aviso de turno incompleto` |
| R38 | Q `turno.dart y turno_incompleto.dart no importan Flutter` |
| R39 | Q `ningún ViewModel llega a dart:ui ni a package:flutter fuera de foundation` (con `contains` del ViewModel nuevo) |
| R40 | W `en la pestaña Turnos el aviso está arriba de "Todos / Mis turnos", en el calendario y en "Mis turnos"` |
| R41 | W `el inicio y Turnos muestran los mismos avisos` |
| R42 | W `tocar el aviso del inicio abre Turnos en "Todos" con el viernes 9 de octubre elegido` |
| R43 | W misma prueba (parte de "Mis turnos" y del sábado 10); V (`TurnosViewModel`) `mostrarTurno con una fecha del mes pasa a "Todos" y elige ese día` |
| R44 | V (`TurnosViewModel`) `mostrarTurno con una fecha de otro mes no cambia el día ni la vista` |
| R45 | W `tocar el aviso en Turnos no cambia la vista ni el día` |
| R46 | W `a las 21:29 no hay aviso y a las 21:30…` ("Tocá para ver tus turnos" y `Icons.chevron_right` en la tarjeta); A `al 200 % … en el inicio` (en Turnos no aparece) |
| R47 | W `a las 21:29 no hay aviso y a las 21:30…` ("Entendido"); A `al 200 % …` en las dos pestañas |
| R48 | V `cerrar saca ese aviso y notifica`; W `"Entendido" en el inicio saca el aviso del inicio y de Turnos`, `"Entendido" en Turnos saca el aviso de las dos pestañas` |
| R49 | V `cerrar uno de dos avisos deja el otro` |
| R50 | P `guardar y leer devuelve las mismas claves`, `olvidarTodo borra los cierres`; V `un ViewModel nuevo con las mismas preferencias no muestra el aviso cerrado`, `el cierre queda guardado con la clave…` |
| R51 | V `si se anota otra persona, el cierre se borra de las preferencias…`, `si la vecina sale del turno, el cierre se borra` |
| R52 | V `si se anota otra persona, el cierre se borra…, y si después sale, el aviso vuelve` |
| R53 | D `dos vecinos en el mismo turno tienen claves distintas`, `claveDeCierre da…`; V `un cierre de otro vecino no oculta el aviso de la vecina` |
| R54 | V `a las 00:00 del 10 el cierre se borra de las preferencias` |
| R55 | V `si falla la primera carga sin turnos, los cierres guardados siguen`; P `un dato que no se puede leer da un conjunto vacío` |
| R56 | V `guardia de ventana sola en la Noche del 9…` (título); W `una guardia de ventana sola ve "Tu guardia de ventana no se va a hacer"` |
| R57 | V `guardia de ventana sola en la Noche del 9…` (texto); W misma prueba (Temprano, texto exacto) |
| R58 | V `guardia de ventana sola en la Madrugada del 9…` |
| R59 | D `esGuardiaVentanaEn es true para la guardia de ventana…`, `un mayor de 70 con guardia normal anotado como patrullero…`; V `una vecina de 75 con guardia normal, sola como patrullera, ve el texto de patrullero` |
| R60 | A `en el inicio se anuncia como botón con la etiqueta "<título>. <texto>. Ver turnos" y como región en vivo` |
| R61 | A `"Entendido" se anuncia como botón con la etiqueta "Entendido. Ocultar este aviso"` |
| R62 | A `la parte tocable del inicio y "Entendido" miden al menos 48 x 48 dp`; A `Guías de accesibilidad` (las dos pantallas nuevas) |
| R63 | A `Guías de accesibilidad` → `Turnos con aviso de turno incompleto` |

## `./init.sh`

Completo, verde:

```
[OK]    feature_list.json válido (21 features)
[OK]    flutter analyze sin avisos
[OK]    dart analyze sin avisos en backend/
00:52 +661: All tests passed!
[OK]    Pruebas de la app
00:00 +99: All tests passed!
[OK]    Pruebas del backend
[OK]    Entorno listo. Podés empezar a trabajar.
```

`dart format` sobre `lib/` y `test/`: sin cambios pendientes. Después de
esa corrida solo se agregaron cuatro `expect` a la prueba de R32 en
`widget_test.dart` (más listas de `NotificacionesFalsas`), que se corrió
sola y pasó.

## Prueba manual

No se hizo en un dispositivo. El comportamiento con la app entera (reloj
que avanza, segundo plano, las dos pestañas, "Entendido") está cubierto
por el grupo de `widget_test.dart` con `RelojManual` y el servidor
simulado.

## Cierre

- 2026-11-26: el reviewer aprobó (`progress/review_aviso_turno_incompleto.md`, APPROVED).
- `feature_list.json`: feature 21 pasa de `in_progress` a `done`.
- `progress/history.md`: entrada de la feature 21 con el resumen y los pendientes que no bloquean (observaciones 1 a 5 del review).
- `progress/current.md`: vuelto a la plantilla vacía.
- No se tocó `lib/`, `test/`, `backend/` ni `specs/`; sin commit ni push.
