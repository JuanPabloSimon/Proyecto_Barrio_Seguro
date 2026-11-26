# Review — feature 15 (requiere_conexion)

**Veredicto:** APPROVED

Segunda revisión, sobre el árbol de trabajo sin commitear de
`feature/requiere_conexion` (spec en 80cc839 + R25 en c343316). La corrección
pedida en la primera vuelta (turnos en la prueba de R10) está bien hecha y R25
está implementado y probado como dice el design.

## Corrección de la primera vuelta (R10 / T20)

- [x] `test/widget_test.dart:111-187`: antes del corte comprueba
  `turnosDao.guardados` no vacío (`:148`) y que se ve "Tu próximo turno de
  patrullaje" en texto (`:160`) y en semántica (`:161-164`); ese título lo arma
  `lib/ui/inicio/view_models/inicio_view_model.dart:132` con los turnos del
  vecino. Después del corte, texto y semántica del turno en `findsNothing`
  (`:179-183`), igual que el saludo y la dirección de la alerta. Verifica la
  mitad que faltaba de R10.

## R25 (T25 / T26)

- [x] `lib/ui/conexion/widgets/atras_sin_conexion.dart`: `StatefulWidget` con
  `WidgetsBindingObserver`; `addObserver` en `initState` (`:30-33`),
  `removeObserver` en `dispose` (`:36-39`), `didPopRoute()` devuelve
  `widget.viewModel.sinConexion` (`:45`). Solo importa `widgets` y el VM.
  Igual al design.
- [x] `lib/main.dart:100-127`: `ConViewModel<ConexionViewModel>` por encima de
  `MaterialApp`, envuelto por `AtrasSinConexion`; `MaterialApp.builder` usa el
  mismo `vm` para `CompuertaDeConexion`. El VM se crea una vez (`late final`
  en el `State` de `ConViewModel`) y `MaterialApp` no se reconstruye con cada
  cambio de conexión. Comentario del orden de observadores en `:84-91`.
  `lib/dependencias.dart` sin cambios por R25.
- [x] `test/widget_test.dart:291-318` (sin conexión el botón Atrás no cierra
  el SOS tapado y al volver se ve el SOS): usa la app completa (`appDePrueba`
  arma `BarrioSeguroApp`, así prueba el armado real), abre el SOS, corta,
  `handlePopRoute()` devuelve `true`, sigue la pantalla sin conexión y al
  volver se ve "¿Enviar alerta SOS?". Sin el observador, `WidgetsApp` haría
  `maybePop` y la última aserción fallaría: la prueba distingue de verdad.
- [x] `test/widget_test.dart:320-344` (sin conexión el botón Atrás en el
  inicio no cierra la app): `atendido == true` (sin el observador la ruta de
  inicio no se cierra y `handlePopRoute` devolvería `false`) y al volver se ve
  "Hola, Clara".
- [x] `test/widget_test.dart:346-362` (control con conexión): `handlePopRoute()`
  cierra el SOS y vuelve a la principal; prueba que el observador no se mete
  con conexión y que el SOS es una ruta que Atrás sí cierra, lo que da valor
  a la prueba de `:291`.

## Trazabilidad

- R1: [x] `test/unit/conexion_test.dart` › ConexionViewModel › al empezar comprueba la conexión; `test/widget_test.dart:96` › al arrancar comprueba la conexión… (`comprobaciones == 1`)
- R2: [x] `test/unit/conexion_test.dart` › ConexionServiceHttp › /salud con {"estado":"ok"} da conexión; › responde en menos de 5 s; › espera 5 s como máximo
- R3: [x] `test/unit/conexion_test.dart` › ConexionServiceHttp › HTML de portal; › JSON distinto; › 500; › error de red; › tarda más de 5 s
- R4: [x] `test/unit/persistencia_test.dart` › Sin envío diferido › fallas de red en alertas y turnos comprueban; › ErrorDelServidor no comprueba; `test/unit/conexion_test.dart` › ConexionViewModel › si un repositorio dispara una comprobación sin conexión el estado pasa a sinConexion
- R5: [x] `test/unit/conexion_test.dart` › ConexionViewModel › con conexión vuelve a comprobar a los 30 s
- R6: [x] `test/unit/conexion_test.dart` › ConexionViewModel › sin conexión vuelve a comprobar a los 5 s
- R7: [x] `test/unit/conexion_test.dart` › ConexionViewModel › en segundo plano no comprueba
- R8: [x] `test/unit/conexion_test.dart` › ConexionViewModel › al volver a primer plano comprueba en el momento
- R9: [x] `test/widget_test.dart:96`, `:111`, `:189`
- R10: [x] `test/widget_test.dart:111` › sin conexión con sesión abierta se tapa la principal y no se ven alertas ni turnos guardados (alertas y turnos, texto y semántica, antes y después del corte)
- R11: [x] `test/widget_test.dart:96` (Llamar al 911 visible); `:250`
- R12: [x] `test/widget_test.dart:250` (`marcados == ['911']`); `test/accesibilidad_test.dart` › Pantalla sin conexión › al 200 % no desborda y Llamar al 911 se alcanza desplazando
- R13: [x] `test/widget_test.dart:271`
- R14: [x] `test/widget_test.dart:189` (confirmación y Alerta enviada); `:228` (texto del login)
- R15: [x] `test/unit/conexion_test.dart` › ConexionViewModel › al volver la conexión publica AlertasActualizadas y TurnosActualizados; › con conexión desde el arranque no publica eventos
- R16: [x] `test/unit/persistencia_test.dart` › Sin envío diferido › crear una alerta sin red lanza el error y no guarda nada; `test/unit/view_models_test.dart` › el SOS sin red queda en error y no se guarda
- R17: [x] `test/widget_test.dart:55`
- R18: [x] `test/unit/persistencia_test.dart` › Esquema de la base › una base nueva no tiene tabla de alertas pendientes
- R19: [x] `test/unit/persistencia_test.dart` › Esquema de la base › migración v2 a v3; › migración v1 a v3
- R20: [x] `test/unit/persistencia_test.dart` › Sin conexión › alertas guardadas sin conexión; › turnos guardados sin conexión; › al volver deja de mostrar el aviso
- R21: [x] `test/accesibilidad_test.dart` › Guías › Sin conexión (tap targets y etiquetas); › Pantalla sin conexión › Llamar al 911 con etiqueta y 48 x 48 dp
- R22: [x] `test/accesibilidad_test.dart` › Pantalla sin conexión › el título se anuncia como encabezado (`isHeader`, `isLiveRegion`)
- R23: [x] `test/accesibilidad_test.dart` › Texto del sistema al 200 % › Sin conexión; › Pantalla sin conexión › al 200 % no desborda
- R24: [x] `test/accesibilidad_test.dart` › Guías › Sin conexión (`textContrastGuideline`); estado en texto (título y ayuda)
- R25: [x] `test/widget_test.dart:291` › sin conexión el botón Atrás no cierra el SOS tapado y al volver se ve el SOS; `:320` › sin conexión el botón Atrás en el inicio no cierra la app; control `:346` › con conexión el botón Atrás cierra el SOS como siempre

## Tasks

- T1 a T26: [x] todas marcadas en `specs/requiere_conexion/tasks.md` (ninguna sin marcar). El adelanto de parte de T19 dentro de T10 está justificado en `progress/impl_requiere_conexion.md`.

## Arquitectura y convenciones

- [x] Capas y dirección de dependencias como en la primera vuelta; `AtrasSinConexion` vive en `lib/ui/conexion/widgets/` y recibe el VM por constructor.
- [x] Armado en `lib/dependencias.dart` sin cambios por R25; nada global ni `static` con estado.
- [x] Plataforma: sin `Platform.isX` en `lib/ui/conexion/` ni en `lib/main.dart`; el 911 sigue por `Capacidades`.
- [x] Paquetes: ninguno nuevo; solo se quitó `workmanager`, anotado en `progress/history.md`.
- [x] Convenciones: español y voseo; `dart format` sin cambios (106 archivos, 0 cambiados); sin `print` ni `debugPrint`.
- [x] Accesibilidad: R25 no cambia lo que se ve ni se anuncia; `SinConexionScreen` sigue en `test/accesibilidad_test.dart`.
- [x] Reglas de turnos: no cambiaron; `backend/` sin tocar.

## Checkpoints

- C1: [x] arnés completo; `./init.sh` sale con 0.
- C2: [x] una sola feature `in_progress` (15); `progress/current.md` describe la sesión activa.
- C3: [x] capas, armado por constructor, plataforma por `Capacidades`, sin paquetes nuevos, sin cambios de reglas de turnos.
- C4: [x] analyze sin avisos (app y backend); 211 pruebas de la app y 42 del backend en verde; falsos y tiempo falso, sin red ni hora real.
- C5: [x] 48 dp, etiquetas, 200 %, estado en texto.
- C6: [x] sin temporales ni `print`; `progress/history.md` con la entrada de la sesión; la feature sigue en `in_progress` (la cierra el leader).
- C7: [x] specs completos, EARS correcto (R25 incluido), todas las tasks en `[x]` y cada R1 a R25 con prueba concreta.

## Salida de init.sh

```
[OK]    feature_list.json válido (16 features)
[OK]    Specs presentes para las features sdd que ya no están en pending
[OK]    flutter pub get
[OK]    dart pub get en backend/
No issues found! (ran in 3.1s)
[OK]    flutter analyze sin avisos
No issues found!
[OK]    dart analyze sin avisos en backend/
00:20 +211: All tests passed!
[OK]    Pruebas de la app
00:00 +42: All tests passed!
[OK]    Pruebas del backend
[OK]    Entorno listo. Podés empezar a trabajar.
EXIT=0
```

## Cambios requeridos

Ninguno.

## Notas (no bloquean)

- `ConexionRepositoryRemoto.cerrar()` sigue sin llamarse en la app; como `Dependencias` vive lo mismo que la app, no se pierde nada.
- Si algún día se activa `android:enableOnBackInvokedCallback` (atrás predictivo), hay que revisar R25, como anota el design.
- El trabajo sigue sin commitear: falta el commit antes de cerrar la feature.
