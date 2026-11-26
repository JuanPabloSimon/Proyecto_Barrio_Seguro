# Review — feature 19 (estado_alerta)

**Veredicto:** APPROVED

Revisado sobre `feature/estado_alerta` (trabajo sin commitear sobre el spec
aprobado en `ef5a6d0`): `git diff` completo de `lib/`, `test/`, `backend/` y
el archivo nuevo `lib/ui/alerta_detalle/widgets/confirmar_cambio_estado.dart`.

Abreviaturas: `dom` = `test/unit/dominio_test.dart`, `rep` =
`test/unit/repositorios_test.dart`, `not` = `test/unit/notificaciones_test.dart`,
`vm` = `test/unit/view_models_test.dart`, `wid` = `test/widget_test.dart`,
`a11y` = `test/accesibilidad_test.dart`, `api` = `backend/test/api_test.dart`,
`reg` = `backend/test/reglas_test.dart`.

## Trazabilidad

Cada prueba se leyó y verifica lo que dice el requisito.

- R1: [x] `wid` › Detalle: estado de la alerta › quien la reportó ve "Estado de la alerta" con Activa, En atención y Resuelta en orden (compara la posición vertical de las tres opciones); `vm` › quien la reportó puede cambiar el estado; `dom` › quien la reportó puede
- R2: [x] `wid` › la comisión ve el control en una alerta ajena; `vm` › la comisión puede cambiar el estado de una alerta ajena; `dom` › la comisión puede aunque no la haya reportado
- R3: [x] `wid` › un vecino común ve el estado pero no el control (ningún `RadioListTile`, sin encabezado); `vm` › un vecino común no puede…; `dom` › un vecino común no puede si no la reportó / sin sesión no puede
- R4: [x] `wid` › un vecino común ve el estado pero no el control (`ChipEstado` con "Activa" e ícono `priority_high`)
- R5: [x] `wid` › la opción elegida es el estado actual (`groupValue` en `enAtencion`)
- R6: [x] `wid` › en una alerta resuelta las tres opciones están habilitadas (autora y comisión); `vm` › una alerta resuelta se puede cambiar
- R7: [x] `wid` › elegir "En atención" no pide confirmación… (sin `AlertDialog`, un solo cambio pedido); `vm` › confirmacionParaCambio con los 9 pares de estados
- R8: [x] `vm` › cambiar al estado actual no pide nada; `wid` › tocar la opción actual no pide nada
- R9: [x] `wid` › mientras cambia, las opciones están deshabilitadas y se ve "Cambiando el estado"; `vm` › mientras cambia, cambiandoEstado es true; `a11y` › el indicador se anuncia "Cambiando el estado"
- R10: [x] `wid` › elegir "En atención"… (chip y opción nuevos, "Pantalla anterior" no visible); `wid` › "Sí, está resuelta" cierra el diálogo…
- R11: [x] `wid` › elegir "En atención"… muestra "Cambiaste el estado a En atención."; `vm` › avisoCambioDeEstado…
- R12: [x] `wid` › Estado: lista y mapa › poner En atención "Actividad sospechosa" se ve en "Alertas cerca tuyo" (chip y etiqueta semántica)
- R13: [x] `wid` › poner Resuelta "Moto a alta velocidad" la quita de "Alertas cerca tuyo"
- R14: [x] `wid` › el pin del mapa dice el estado nuevo (ver observación 1)
- R15: [x] `wid` › una alerta propia cambiada se ve con el estado nuevo en "Mis alertas"
- R16: [x] `vm` › si la API rechaza muestra su mensaje tal cual…; `wid` › si la API rechaza se ve su mensaje y el estado anterior
- R17: [x] `vm` › sin conexión muestra "No pudimos cambiar el estado. Probá de nuevo."…; `wid` › sin conexión se ve…
- R18: [x] mismas cuatro pruebas (estado arriba y opción elegida siguen en Activa)
- R19: [x] `wid` › no está el botón "Marcar como resuelta" (autora, comisión y vecino común)
- R20: [x] `wid` › "Fue una falsa alarma" sigue cerrando el detalle con "Cancelaste la alerta: falsa alarma" sin diálogo; `vm` › solo quien la reportó ve "Fue una falsa alarma"…; `vm` › "Fue una falsa alarma" la deja resuelta como antes
- R21: [x] `api` › Alertas › quien la reportó cambia el estado (200, guardado en el almacén); `reg` › quien la reportó puede
- R22: [x] `api` › la comisión cambia el estado de una alerta ajena (Clara sobre a2 de Martín y a3); `reg` › la comisión puede…
- R23: [x] `api` › un vecino común no puede cambiar el estado de una alerta ajena (403, cuerpo literal, a1 sigue activa); `reg` › el mensaje es el mismo que el de la app
- R24: [x] `api` › se puede reabrir una alerta resuelta (a4 a activa, a5 a en_atencion); `rep` › el simulado reabre una alerta resuelta
- R25: [x] `rep` › la comisión cambia el estado de una alerta ajena en el simulado; `rep` › quien la reportó cambia el estado en el simulado
- R26: [x] `rep` › un vecino común no cambia una alerta ajena en el simulado (`ErrorDelServidor` con el texto literal, a1 sigue activa); `dom` › el mensaje es el mismo que el del servidor
- R27: [x] `a11y` › Guías de accesibilidad › Detalle de alerta con error de estado (y Detalle de alerta / SOS): guías de 48 dp de Android e iOS
- R28: [x] `a11y` › Estado de la alerta › el control de estado tiene encabezado… (isHeader, isInMutuallyExclusiveGroup, isChecked)
- R29: [x] `a11y` › cada opción muestra el ícono y el nombre del estado
- R30: [x] `a11y` › el error de cambio de estado es una región en vivo con ícono
- R31: [x] `a11y` › Texto del sistema al 200 % › Detalle de alerta, Detalle de una alerta SOS, Detalle de alerta con error de estado, Detalle de alerta de un vecino común
- R32: [x] `a11y` › el detalle se lee en orden (recorrido en traversalOrder)
- R33: [x] `wid` › elegir "Resuelta" muestra "¿Marcar la alerta como resuelta?" con su texto y los botones…
- R34: [x] `wid` › en una alerta resuelta, elegir "En atención" o "Activa" muestra "¿Volver a abrir la alerta?" con su texto
- R35: [x] `wid` › "Sí, está resuelta" cierra el diálogo…; `wid` › "Sí, volver a abrirla" pide el cambio…
- R36: [x] `wid` › cerrar el diálogo sin confirmar no pide nada › "No, dejarla como está" / "No, dejarla resuelta" / tocando fuera / botón Atrás (handlePopRoute)
- R37: [x] mismas cuatro pruebas (chip y opción en el estado actual, sin SnackBar ni ícono de error)
- R38: [x] `a11y` › Guías › Confirmar marcar como resuelta (diálogo), Confirmar volver a abrir (diálogo); `a11y` › al 200 % los botones del diálogo… miden al menos 48 dp
- R39: [x] `a11y` › Texto del sistema al 200 % › los dos diálogos; `a11y` › al 200 % los botones del diálogo se apilan…
- R40: [x] `a11y` › los diálogos de confirmación anuncian el título y cada botón por su texto (namesRoute y scopesRoute con la etiqueta del título; botones isButton)
- R41: [x] `api` › Avisos push: reapertura › reabrir una alerta resuelta a activa envía el aviso de reapertura (con reportada_por_nombre y reabiertaEn igual a la hora del RelojFijo); › reabrir a en_atencion también lo envía; › PushServiceFcm.enviarReapertura… (tópico alertas, aviso, reabierta_en en ms)
- R42: [x] `api` › pasar entre activa y en_atencion no envía nada; › pasar a resuelta no envía nada; › elegir el mismo estado no envía nada (incluye resuelta a resuelta)
- R43: [x] `api` › un pedido rechazado no envía nada (401, 403, 400 y 404; a4 sigue resuelta)
- R44: [x] `api` › si el push falla al reabrir, el estado se guarda y responde 200
- R45: [x] `api` › el aviso de reapertura solo trae las claves de la alerta; PushServiceFcm: data con las claves de la alerta más aviso y reabierta_en, nada más
- R46: [x] `not` › Aviso push de reapertura › una reapertura a tiempo muestra el aviso de reapertura (a los 5 min justos); `dom` › Textos del aviso de reapertura
- R47: [x] `not` › una reapertura con 30 minutos de demora muestra el aviso de reapertura tardío (título con 15:10); `dom` › el título tardío agrega la hora…
- R48: [x] `not` › una reapertura con 3 horas de demora no muestra nada
- R49: [x] `not` › la reapertura de una alerta propia no se avisa
- R50: [x] `not` › con los avisos apagados no se avisa
- R51: [x] `not` › sin reabierta_en, con reabierta_en inválido o con estado resuelta no se avisa (incluye datos incompletos); `not` › reabiertaEnDesdeDatosPush lee entero y texto
- R52: [x] `not` › una reapertura no cambia la llegada guardada del aviso original; `rep` › horaDelServidor suma el desfase y no guarda ninguna llegada; `not` › Vigilante › una reapertura no guarda llegadas
- R53: [x] `not` › Vigilante de alertas › una alerta ajena que estaba resuelta y se reabrió muestra el aviso de reapertura (y no se repite); › reabrir a en atención también se avisa
- R54: [x] `not` › una reapertura publica AlertasActualizadas; › con los avisos apagados… se publica AlertasActualizadas; › la reapertura de una alerta propia no se avisa (también publica)
- R55: [x] `not` › la reapertura de una alerta propia no se avisa; › con los avisos apagados la reapertura no se avisa…

## Tasks

- T1 a T34: [x] todas marcadas. Los desvíos están justificados en
  `progress/impl_estado_alerta.md` (Decisiones de implementación y desvíos,
  puntos 1 a 10) y ninguno contradice el spec.

## Arquitectura y convenciones

- [x] La regla de permiso es la misma en los tres lados: `lib/domain/reglas_alertas.dart` (puedeCambiarEstado y mensajeSinPermisoEstado), el servidor simulado (`lib/data/services/simulados/servidor_simulado.dart:251`) y el backend (`backend/lib/src/reglas.dart` y `backend/lib/src/api.dart:317`, con el rol leído del almacén y no del pedido). Los dos mensajeSinPermisoEstado tienen el mismo texto literal, con prueba de cada lado. 403 al resto.
- [x] Las confirmaciones aparecen solo al resolver y al reabrir: confirmacionParaCambio (ViewModel) cubre los 9 pares y la pantalla abre el diálogo solo si no es null.
- [x] El push de reapertura sale solo de resuelta hacia otro estado (`backend/lib/src/api.dart:331-333`). `_notificarReapertura` (`api.dart:339`) tiene try/catch y el estado ya está guardado antes de avisar. Las claves son las de la alerta más aviso y reabierta_en, sin datos de quien la reabrió.
- [x] En la app, `_procesarReapertura` (`lib/data/services/push_service.dart`) descarta: avisos apagados, alerta propia, estado resuelta, reabierta_en inválido y más de 2 h (clasificarAviso con horaDelServidor). No llama a registrarLlegada.
- [x] Capas: la pantalla habla solo con su ViewModel; el ViewModel no recibe BuildContext; el diálogo vive en `widgets/`. `lib/dependencias.dart` sin cambios (no hacía falta armar nada nuevo).
- [x] El ScaffoldMessenger se toma antes del await y se chequea context.mounted después del diálogo.
- [x] El build está partido en clases (`_ControlDeEstado`, `_ErrorDeEstado`), sin métodos `_buildX()`.
- [x] Textos en voseo (Cambiaste, Probá, podés). Sin print ni debugPrint.
- [x] Sin paquetes nuevos: `pubspec.yaml`, `pubspec.lock` y `backend/pubspec.yaml` sin cambios.
- [x] La pantalla cambiada tiene pruebas de widgets y en `test/accesibilidad_test.dart` (4 entradas nuevas en `pantallas`, con guías y 200 %).
- [x] No cambia ninguna regla de turnos.

## Checkpoints

- C1: [x] archivos del arnés presentes; `./init.sh` sale con 0.
- C2: [x] una sola feature in_progress (#19); `progress/current.md` describe la sesión activa.
- C3: [x] capas, constructor, sin Platform.isX, sin paquetes nuevos (ver observación 2).
- C4: [x] analizadores sin avisos; 499 pruebas de la app y 79 del backend en verde; todo con RelojFijo y falsos, sin internet.
- C5: [x] 48 dp, etiquetas, 200 % y estado con ícono y texto (guías y pruebas propias).
- C6: [x] sin temporales ni print. La entrada de `progress/history.md` de esta feature la escribe el leader al cerrar (ver observación 4).
- C7: [x] `specs/estado_alerta/` completo, en EARS, tasks en [x], cada R con prueba.

## Salida de init.sh

```
[OK]    feature_list.json válido (19 features)
[OK]    Specs presentes para las features sdd que ya no están en pending
[OK]    flutter pub get
[OK]    dart pub get en backend/
No issues found! (ran in 4.7s)
[OK]    flutter analyze sin avisos
No issues found!
[OK]    dart analyze sin avisos en backend/
+499: All tests passed!
[OK]    Pruebas de la app
+79: All tests passed!
[OK]    Pruebas del backend
[OK]    Entorno listo. Podés empezar a trabajar.
(código de salida 0)
```

## Observaciones (no bloquean)

1. `test/widget_test.dart:2514` (R14): la prueba del pin verifica la etiqueta
   semántica con el estado nuevo, pero no el ícono. Es lo que pedía T24 y el
   ícono sale del mismo EstadoAlerta. Si se quiere más fuerza, se puede sumar
   la búsqueda del ícono de Resuelta dentro del pin.
2. `lib/ui/alerta_detalle/view_models/detalle_alerta_view_model.dart:15`
   importa `ui/core/presentacion_alerta.dart`, que a su vez importa
   `material.dart` (por IconData y Color). No es un widget y lo autoriza el
   design (para avisoCambioDeEstado), pero es el único ViewModel que lo hace.
   Está anotado en el desvío 6 del impl.
3. `lib/ui/principal/vigilante_de_alertas.dart:137`: con la app abierta el
   vigilante avisa la reapertura siempre "a tiempo" (no conoce
   reabierta_en), así que no aplica la regla de 2 horas. Es lo que dice R53 y
   el riesgo está aceptado en el design; queda a la vista por si se quiere
   revisar más adelante.
4. Pendiente al cerrar: entrada en `progress/history.md`, prueba manual (no
   se hizo, sin emulador) y commit de la rama.

## Cambios requeridos

Ninguno.

---

# Revisión de la ampliación (R56–R66, T35–T49)

**Veredicto:** APPROVED

Revisado sobre `feature/estado_alerta` (sin commitear), contra
`specs/estado_alerta/` (requirements R56–R66, design puntos 10 y 11, tasks
T35–T49), `progress/impl_estado_alerta.md` › Ampliación, `docs/` y
`CHECKPOINTS.md`.

## Trazabilidad

- R56: [x] `test/unit/arquitectura_test.dart` › MVVM: los ViewModels no dependen de la vista › ningún ViewModel llega a dart:ui ni a package:flutter fuera de foundation (recorre los 13 ViewModels; exige que la lista no esté vacía y que tenga `detalle_alerta_view_model.dart`).
- R57: [x] `arquitectura_test.dart` › textos_estado.dart no importa nada de Flutter (`permitirFoundation: false`); › con foundation prohibido, el chequeo también la encuentra (control de que la opción realmente prohíbe `foundation.dart`).
- R58: [x] `test/unit/view_models_test.dart:45-57` › Textos de los estados (las 6 cadenas); `avisoCambioDeEstado` sin cambios; las pruebas de widgets y accesibilidad que buscan "Activa", "En atención", "Resuelta", "Activas", "Resueltas" siguen pasando sin tocarlas.
- R59: [x] `arquitectura_test.dart` › la prueba de R56 falla con `reason` que lista cada cadena; › el chequeo encuentra material.dart en presentacion_alerta.dart; › el chequeo sigue los imports indirectos (chip_estado -> presentacion_alerta -> material).
- R60: [x] `test/unit/notificaciones_test.dart:333` › una reapertura encontrada después de más de 2 horas sin revisar se avisa como tardía sin hora (2 h 1 min; título "Se reabrió una alerta: Robo" y `cuerpoAvisoTardio`); `test/unit/avisos_tardios_test.dart:161` › 2 horas y 1 segundo es tardía; `notificaciones_test.dart:461` › NotificacionesServiceNinguno.avisarReaperturaTardiaSinHora termina sin hacer nada.
- R61: [x] `notificaciones_test.dart:333` y `:365` (`reaperturas` vacía en los dos).
- R62: [x] `notificaciones_test.dart:355` › con 2 horas justas se avisa a tiempo; `:382` › una revisión que funcionó reinicia la cuenta; `avisos_tardios_test.dart:151,171,181` (2 h justas, segundos, diferencia negativa); pruebas previas del vigilante con `RelojManual` quieto.
- R63: [x] `notificaciones_test.dart:365` › si la revisión del medio falla, la demora se mide desde la última que funcionó (falla en +1 h, buena en +2 h 30 min -> tardía).
- R64: [x] `notificaciones_test.dart:404` › la reapertura tardía de una alerta propia no se avisa; `:414` › con los avisos apagados la reapertura tardía no se avisa pero se publica AlertasActualizadas (ninguna de las dos listas).
- R65: [x] `notificaciones_test.dart:430` › una reapertura tardía no guarda llegadas.
- R66: [x] `notificaciones_test.dart:440` › una alerta nueva encontrada después de más de 2 horas sin revisar se clasifica por creada_en (en `avisadas`, `tardias` vacía).
- R54 (suma): [x] `notificaciones_test.dart:414`.

## Tasks

- T35–T49: [x] todas marcadas en `specs/estado_alerta/tasks.md:77-97` y verificadas en el código.

## Verificaciones propias

- **MVVM, de forma independiente a la prueba del proyecto.** Escribí un
  chequeo aparte (cierre transitivo de todos los `import`/`export` de
  `lib/`, con otra expresión regular) sobre los 13 ViewModels de
  `lib/ui/*/view_models/`: ninguno llega a `dart:ui` ni a
  `package:flutter/` fuera de `foundation.dart` (el de detalle recorre 26
  archivos). En `lib/` no hay imports condicionales, `part` ni
  `package:barrio_seguro/`, así que el recorrido no deja huecos hoy.
  `lib/ui/core/textos_estado.dart` importa solo `../../domain/models/alerta.dart`.
- **La prueba falla si vuelve el import viejo.** Sobre una copia de `lib/`
  fuera del repo, con `detalle_alerta_view_model.dart:15` volviendo a
  `../../core/presentacion_alerta.dart`, la misma `importsVisuales` de
  `test/unit/arquitectura_test.dart` devuelve
  `lib/ui/alerta_detalle/view_models/detalle_alerta_view_model.dart -> lib/ui/core/presentacion_alerta.dart -> package:flutter/material.dart`
  y la variante por `tema/app_colors.dart`; con eso `expect(prohibidos, isEmpty)`
  falla y el `reason` nombra el ViewModel y la cadena (R59). Con el código
  actual devuelve la lista vacía. El razonamiento sobre el código
  coincide: `Uri.parse(actual).resolve(ruta).path` resuelve las rutas
  relativas desde la raíz y `visitados` evita ciclos.
- **Textos iguales.** `lib/ui/core/textos_estado.dart` tiene exactamente
  los mismos `switch` que se quitaron de `PresentacionEstado`
  (`git diff lib/ui/core/presentacion_alerta.dart`); el `export` mantiene a
  las vistas con un solo import y el analizador no marca extensiones
  ambiguas.
- **Regla de 2 h del vigilante** (`lib/ui/principal/vigilante_de_alertas.dart:103-160`,
  `lib/domain/avisos_tardios.dart:96-99`): comparación estricta `>` contra
  `demoraMaximaParaAvisar` (2 h justas = a tiempo; diferencia negativa = a
  tiempo); `_ultimaRevision` se actualiza solo después de que
  `obtenerAlertas` responde, junto con `_conocidas` y `_resueltas` (una
  revisión fallida no mueve la cuenta); el filtro de propias
  (`reportadaPor != yo`) y `conAvisos` van antes de elegir el tipo de
  aviso; no se llama a `registrarLlegada` para reaperturas;
  `AlertasActualizadas` se publica en el mismo lugar; las alertas nuevas
  siguen con `clasificarAviso`. Igual al design, punto 11.
- `NotificacionesServiceLocales.avisarReaperturaTardiaSinHora`
  (`lib/data/services/notificaciones_service.dart:149-153`) usa
  `tituloAvisoReapertura` + `cuerpoAvisoTardio` con el mismo `_mostrar`.
- Armado: `PrincipalScreen` pasa `reloj: d.reloj`
  (`lib/ui/principal/widgets/principal_screen.dart:92`);
  `lib/dependencias.dart` sin cambios, como dice el design.
- Sin paquetes nuevos: `pubspec.yaml`, `pubspec.lock` y
  `backend/pubspec.yaml` sin diff. Backend sin cambios en la ampliación
  (79 pruebas).

## Arquitectura y convenciones

- [x] Capas y dirección de dependencias: la regla pura en `domain/`, el
  servicio en `data/services/`, el vigilante en `ui/principal/`.
- [x] Desvíos justificados en el impl: renombre privado del `Timer`
  (`_reloj` -> `_temporizador`); T38 antes de T36 con la falla anotada;
  `contains` en la prueba de control; prueba extra con `foundation`
  prohibido; `dart:ui_*`. Ninguno contradice el spec.
- [x] Docs: `docs/architecture.md` (principio 1, árbol de `ui/core/`, "Qué
  NO hacer") y `CHECKPOINTS.md` C3 actualizados como pide T39.
- [x] Voseo y español en comentarios y nombres.

## Checkpoints

- C1: [x] spec ampliado con R56–R66 y T35–T49, trazabilidad completa.
- C2: [x] cada R con prueba concreta (arriba).
- C3: [x] capas, ViewModels sin Flutter visual (verificado aparte),
  armado sin globales, sin decisiones de plataforma nuevas.
- C4: [x] sin pantallas nuevas; la accesibilidad de lo aprobado sigue verde.
- C5: [x] no toca reglas de turnos ni la API.
- C6: [x] sin paquetes nuevos.
- C7: [x] `./init.sh` verde, analizador sin avisos.

## Salida de init.sh

```
[OK]    flutter pub get
[OK]    dart pub get en backend/
No issues found! (ran in 7.8s)
[OK]    flutter analyze sin avisos
No issues found!
[OK]    dart analyze sin avisos en backend/
01:01 +519: All tests passed!
[OK]    Pruebas de la app
00:00 +79: All tests passed!
[OK]    Pruebas del backend
[OK]    Entorno listo. Podés empezar a trabajar.
```

Lo aprobado antes (R1–R55) sigue verde: 519 pruebas de la app (499 + 20
nuevas) y 79 del backend, sin fallas. Además corrí por separado
`test/unit/arquitectura_test.dart` (5/5) y, juntos,
`arquitectura_test.dart`, `avisos_tardios_test.dart` y
`notificaciones_test.dart` (73/73).

## Observaciones (no bloquean)

1. `progress/impl_estado_alerta.md`, desvío 6 de la parte original, y la
   observación 2 de esta review siguen diciendo que el ViewModel importa
   `presentacion_alerta.dart`; la ampliación lo dejó sin efecto. Conviene
   marcarlos como superados.
2. `test/unit/arquitectura_test.dart:12-15`: la expresión regular toma
   solo la primera URI de cada directiva y exige que empiece la línea. Si
   algún día aparece un import condicional (con `if (dart.library...)`),
   la rama alternativa no se recorre. Hoy no hay ninguno en `lib/`.
3. R62 con el reloj hacia atrás está probado en la regla pura
   (`test/unit/avisos_tardios_test.dart:181`), no a través del vigilante.
   El vigilante usa esa misma función, así que alcanza.
4. Pendiente al cerrar: entrada en `progress/history.md`, prueba manual de
   la ampliación (no se hizo, sin emulador) y commit de la rama.

## Cambios requeridos

Ninguno.
