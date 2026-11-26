# Implementación — requiere_conexion (feature 15)

- **Rama:** `feature/requiere_conexion` (sin commitear, como pidió el leader).
- **Fecha:** 2026-11-25
- **Spec:** `specs/requiere_conexion/` — tasks T1–T26 marcadas `[x]` (T25 y T26 por R25, agregado después de la revisión).
- **Paquetes nuevos:** ninguno. **Se quitó `workmanager`** (autorizado por el design); `pubspec.lock` actualizado con `flutter pub get` (−48 líneas). Nota en `progress/history.md`.
- **Backend:** sin cambios (`GET /salud` ya existía).
- **Estado en `feature_list.json`:** sigue `in_progress` (espera al reviewer).

## Archivos tocados

### App (`lib/`)

| Archivo | Cambio | Tasks |
|---|---|---|
| `lib/data/services/conexion_service.dart` | **Nuevo.** `abstract class ConexionService { Future<bool> hayConexion(); }`. | T1 |
| `lib/data/services/http/conexion_service_http.dart` | **Nuevo.** `ConexionServiceHttp(ClienteApi, {espera = 5 s})`: `GET /salud` con `.timeout(espera)`; `true` solo si es un `Map` con `estado == 'ok'`; cualquier excepción da `false`. | T1 |
| `lib/data/services/simulados/conexion_service_simulado.dart` | **Nuevo.** `ConexionServiceSimulado({conectado = true})`. | T1 |
| `lib/data/repositories/conexion_repository.dart` | **Nuevo.** `ConexionRepository` (`hayConexion`, `cambios`, `comprobar()`) y `ConexionRepositoryRemoto` (un solo pedido en vuelo, `cambios` solo cuando cambia, `cerrar()`). | T3 |
| `lib/data/repositories/alertas_repository.dart` | Fuera `estaPendiente`, `enviarPendientes`, `_pendientes`, `_tareas`, `_reloj`, `_prefijoPendiente`, `_leerPendientes`, `_guardarPendiente` y la rama pendiente de `cambiarEstado`. `crearAlerta` relanza todo. Nuevo parámetro `conexion`; `unawaited(comprobar())` ante errores que no son `ErrorDelServidor` en `obtenerAlertas` y `crearAlerta`. Comentarios al día (caché). | T5 |
| `lib/data/repositories/turnos_repository.dart` | Nuevo parámetro `conexion`; comprueba ante fallas de red en `obtenerTurnos`. Comentarios al día. | T6 |
| `lib/data/services/local/base_de_datos.dart` | `versionDelEsquema = 3`; sin `sqlCrearPendientes`; `onCreate` sin la tabla; `onUpgrade`: `if (anterior < 3) DROP TABLE IF EXISTS alertas_pendientes`; comentario de versiones. | T8 |
| `lib/data/services/local/pendientes_dao.dart` | **Borrado.** | T10 |
| `lib/data/services/tareas/` (`envio_de_pendientes.dart`, `tarea_de_fondo.dart`, `tareas_service.dart`) | **Borrados** (y la carpeta). | T10 |
| `lib/plataforma/capacidades.dart` | Fuera `correTareasEnSegundoPlano`; comentario de `tieneBaseDeDatosLocal` como caché. | T11 |
| `lib/ui/principal/vigilante_de_alertas.dart` | Fuera `enviarPendientes()` y su mención en el comentario. | T12 |
| `lib/ui/sos/view_models/sos_view_model.dart` | Fuera `pendiente`/`_pendiente` y el comentario duplicado de `enviar()`. | T13 |
| `lib/ui/sos/widgets/sos_screen.dart` | `_VistaSosEnviada` sin `pendiente`: fuera "Alerta guardada" y "No hay señal. La alerta se va a enviar sola…". | T13 |
| `lib/ui/conexion/view_models/conexion_view_model.dart` | **Nuevo.** `EstadoConexion` y `ConexionViewModel` (`empezar`, `alPasarASegundoPlano`, `alVolverAPrimerPlano`, un `Timer.periodic` que se reprograma con 30 s o 5 s según el estado, escucha `cambios`, publica `AlertasActualizadas` y `TurnosActualizados` al pasar de `sinConexion` a `conectado`, `dispose` cancela reloj y suscripción). | T15 |
| `lib/ui/conexion/widgets/sin_conexion_screen.dart` | **Nuevo.** `SinConexionScreen` (ícono en `ExcludeSemantics`, título con `header` + `liveRegion`, texto de ayuda, `FilledButton.icon` "Llamar al 911" de 64 dp con `mostrarDialogo911`, `SingleChildScrollView`). | T17 |
| `lib/ui/conexion/widgets/compuerta_de_conexion.dart` | **Nuevo.** `CompuertaDeConexion`: `AppLifecycleListener` → VM; `Stack` con `Offstage` + `TickerMode` del `child` y, sin conexión, un `Navigator` propio con `SinConexionScreen` dentro de `HeroControllerScope.none` (ver "Notas"). | T18 |
| `lib/dependencias.dart` | `Dependencias.conexion`; `ConexionService? conexion` en `simuladas` (por defecto `ConexionServiceSimulado()`); `ConexionServiceHttp(api)` en `conApi` con el mismo `ClienteApi`; `_armar` crea `ConexionRepositoryRemoto` antes que alertas y turnos y se lo pasa. Fuera `tareas` y `pendientesDao` de las tres fábricas. | T10, T19 |
| `lib/main.dart` | Fuera `workmanager`, `PendientesDao`, `TareasService` y `callbackDispatcher`. `ConViewModel(ConexionViewModel..empezar())` por encima de `MaterialApp`, envuelto con `AtrasSinConexion`; `MaterialApp.builder` usa el mismo `vm` para `CompuertaDeConexion`. Comentario en `BarrioSeguroApp` del orden de los observadores (R25). | T10, T19, T25 |
| `lib/ui/conexion/widgets/atras_sin_conexion.dart` | **Nuevo (R25).** `AtrasSinConexion`: `StatefulWidget` con `WidgetsBindingObserver` (`addObserver` en `initState`, `removeObserver` en `dispose`); `didPopRoute()` devuelve `viewModel.sinConexion`. | T25 |
| `pubspec.yaml` / `pubspec.lock` | Fuera `workmanager: ^0.10.3` y su comentario. | T11 |

### Pruebas (`test/`)

| Archivo | Cambio | Tasks |
|---|---|---|
| `test/unit/conexion_test.dart` | **Nuevo.** Grupos `ConexionServiceHttp` (8), `ConexionRepositoryRemoto` (3) y `ConexionViewModel` (9). | T2, T4, T16 |
| `test/unit/persistencia_test.dart` | Grupos nuevos `Sin envío diferido` (5) y `Esquema de la base` (3); helpers `TurnosServiceQueRechaza` y `tablasDe`. | T7, T9 |
| `test/unit/notificaciones_test.dart` | Borrados los grupos "Alertas sin señal" y "Tarea de envío", la migración a la v2, "cada revisión intenta mandar las alertas pendientes", `AlertasServiceDePrueba`, `_ServicioQueRechazaLaPrimera` y el `expect` de `enviosDePendientes` en la prueba del ciclo de vida (usaba el campo quitado). Quedan vigilante y push. | T9, T10, T12 |
| `test/unit/view_models_test.dart` | `el SOS sin red queda en error y no se guarda`. | T14 |
| `test/widget_test.dart` | `el SOS sin red muestra "No pudimos enviar…"` y grupo `Sin conexión` (6 + 3 del botón Atrás con `tester.binding.handlePopRoute()`). | T14, T20, T26 |
| `test/accesibilidad_test.dart` | `Sin conexión` en la lista de pantallas (guías y 200 %) y grupo `Pantalla sin conexión` (3). | T21 |
| `test/ayudas/falsos.dart` | `ConexionFalsa`, `ConexionRepositoryFalsa`, `AlertasServiceQueFalla`, `AlertasDaoEnMemoria`, `TurnosDaoEnMemoria`; fuera `TareasFalsas`, `enviosDePendientes`, `estaPendiente`, `enviarPendientes` y `correTareasEnSegundoPlano`. | T3, T10, T11, T14, T20 |
| `test/ayudas/bases_de_prueba.dart` | `baseEnMemoria()` sin `sqlCrearPendientes`. | T8 |
| `test/ayudas/app_de_prueba.dart` | Parámetro `ConexionService? conexion`. | T19 |

`test/unit/plataforma_test.dart` y `test/capacidades_politicas_test.dart` no usaban `correTareasEnSegundoPlano`: sin cambios.

### Docs

| Archivo | Cambio | Tasks |
|---|---|---|
| `docs/architecture.md` | Principio 7 "Requiere conexión"; sin `tareas/` en el árbol; `ui/conexion/` agregado. En `AGENTS.md` y el resto de `docs/` no había menciones de `workmanager`. | T22 |
| `progress/history.md` | Nota de que se quitó `workmanager`. | T23 |

## Trazabilidad

| Requisito | Prueba |
|---|---|
| R1 | `test/unit/conexion_test.dart` › ConexionViewModel › al empezar comprueba la conexión; `test/widget_test.dart` › Sin conexión › al arrancar comprueba la conexión y sin conexión el login muestra "Necesitás conexión a internet para usar la app" |
| R2 | `test/unit/conexion_test.dart` › ConexionServiceHttp › /salud con {"estado":"ok"} da conexión; › /salud que responde en menos de 5 s da conexión; › espera 5 s como máximo |
| R3 | `test/unit/conexion_test.dart` › ConexionServiceHttp › /salud con HTML de portal de acceso da sin conexión; › /salud con un JSON distinto de {"estado":"ok"} da sin conexión; › /salud con 500 da sin conexión; › error de red da sin conexión; › /salud que tarda más de 5 s da sin conexión |
| R4 | `test/unit/persistencia_test.dart` › Sin envío diferido › si falla la red al pedir alertas se comprueba la conexión; › si falla la red al pedir turnos se comprueba la conexión; › crear una alerta sin red lanza el error y no guarda nada en el teléfono; › un ErrorDelServidor no dispara la comprobación; `test/unit/conexion_test.dart` › ConexionRepositoryRemoto › dos comprobar() simultáneos hacen un solo pedido; › cambios emite solo cuando cambia el resultado; › ConexionViewModel › si un repositorio dispara una comprobación sin conexión el estado pasa a sinConexion |
| R5 | `test/unit/conexion_test.dart` › ConexionViewModel › con conexión vuelve a comprobar a los 30 s |
| R6 | `test/unit/conexion_test.dart` › ConexionViewModel › sin conexión vuelve a comprobar a los 5 s |
| R7 | `test/unit/conexion_test.dart` › ConexionViewModel › en segundo plano no comprueba |
| R8 | `test/unit/conexion_test.dart` › ConexionViewModel › al volver a primer plano comprueba en el momento |
| R9 | `test/widget_test.dart` › Sin conexión › al arrancar comprueba la conexión y sin conexión el login muestra "…"; › sin conexión con sesión abierta se tapa la principal y no se ven alertas ni turnos guardados; › si se corta la conexión con el SOS abierto aparece la pantalla sin conexión y al volver se ve el SOS como estaba |
| R10 | `test/widget_test.dart` › Sin conexión › sin conexión con sesión abierta se tapa la principal y no se ven alertas ni turnos guardados (DAOs en memoria con datos; antes del corte se ven la dirección de una alerta guardada y la tarjeta "Tu próximo turno de patrullaje" del inicio, en texto y semántica; después del corte, ni texto ni nodos de semántica del saludo, de la alerta ni del turno). Corregido tras el CHANGES_REQUESTED: se agregó la verificación de turnos |
| R11 | `test/widget_test.dart` › Sin conexión › al arrancar comprueba la conexión… (`Llamar al 911` visible); › "Llamar al 911" sin conexión abre el teléfono con el 911 |
| R12 | `test/widget_test.dart` › Sin conexión › "Llamar al 911" sin conexión abre el teléfono con el 911 (`TelefonoFalso.marcados == ['911']`); `test/accesibilidad_test.dart` › Pantalla sin conexión › al 200 % no desborda y "Llamar al 911" se alcanza desplazando |
| R13 | `test/widget_test.dart` › Sin conexión › sin poder llamar muestra "Llamá al 911 desde un teléfono" |
| R14 | `test/widget_test.dart` › Sin conexión › si se corta la conexión con el SOS abierto aparece la pantalla sin conexión y al volver se ve el SOS como estaba (confirmación y "Alerta enviada"); › el texto escrito en el login sigue al volver |
| R15 | `test/unit/conexion_test.dart` › ConexionViewModel › al volver la conexión publica AlertasActualizadas y TurnosActualizados; › con conexión desde el arranque no publica eventos |
| R16 | `test/unit/persistencia_test.dart` › Sin envío diferido › crear una alerta sin red lanza el error y no guarda nada en el teléfono; `test/unit/view_models_test.dart` › SosViewModel › el SOS sin red queda en error y no se guarda |
| R17 | `test/widget_test.dart` › el SOS sin red muestra "No pudimos enviar la alerta. Probá de nuevo o llamá al 911." |
| R18 | `test/unit/persistencia_test.dart` › Esquema de la base › una base nueva no tiene tabla de alertas pendientes |
| R19 | `test/unit/persistencia_test.dart` › Esquema de la base › la migración de la v2 a la v3 borra alertas_pendientes y conserva alertas y turnos; › la migración de la v1 a la v3 conserva las alertas |
| R20 | `test/unit/persistencia_test.dart` › Sin conexión › las alertas guardadas se ven al abrir la app sin conexión; › los turnos guardados se ven sin conexión; › al volver la conexión deja de mostrar el aviso (pruebas existentes, siguen verdes) |
| R21 | `test/accesibilidad_test.dart` › Guías de accesibilidad › Sin conexión (`androidTapTargetGuideline`, `iOSTapTargetGuideline`, `labeledTapTargetGuideline`); › Pantalla sin conexión › "Llamar al 911" tiene etiqueta y mide al menos 48 x 48 dp |
| R22 | `test/accesibilidad_test.dart` › Pantalla sin conexión › el título se anuncia como encabezado (`isHeader` e `isLiveRegion`); `test/widget_test.dart` › Sin conexión › sin conexión con sesión abierta… (`find.semantics.byLabel(título)`) |
| R23 | `test/accesibilidad_test.dart` › Texto del sistema al 200 % › Sin conexión; › Pantalla sin conexión › al 200 % no desborda y "Llamar al 911" se alcanza desplazando |
| R24 | `test/accesibilidad_test.dart` › Guías de accesibilidad › Sin conexión (`textContrastGuideline`); el estado va en texto (título y ayuda), verificado por las pruebas de R9 que buscan el texto |
| R25 | `test/widget_test.dart` › Sin conexión › sin conexión el botón Atrás no cierra el SOS tapado y al volver se ve el SOS; › sin conexión el botón Atrás en el inicio no cierra la app; control: › con conexión el botón Atrás cierra el SOS como siempre |

## `./init.sh` completo

```
[OK]    Flutter 3.47.5 • channel stable
[OK]    Dart SDK version: 3.13.4 (stable)
[OK]    Existe … (11 archivos del arnés)
[OK]    feature_list.json válido (16 features)
[OK]    Specs presentes para las features sdd que ya no están en pending
[OK]    flutter pub get
[OK]    dart pub get en backend/
[OK]    flutter analyze sin avisos            (No issues found!)
[OK]    dart analyze sin avisos en backend/   (No issues found!)
[OK]    Pruebas de la app                     (00:20 +208: All tests passed!)
[OK]    Pruebas del backend                   (00:00 +42: All tests passed!)
[OK]    Entorno listo. Podés empezar a trabajar.
```

Antes de la feature había 178 pruebas en la app; ahora son 208. Se borraron las de envío diferido, que ya no aplican.

`dart format` corrido sobre todo lo tocado.

Tras el CHANGES_REQUESTED (verificación de turnos en la prueba de R10) se volvió a correr `./init.sh` completo: misma salida, 208 pruebas de la app y 42 del backend en verde, analyze sin avisos, salida 0.

Tras el agregado de R25 (T25, T26) se volvió a correr `./init.sh` completo: `flutter analyze` y `dart analyze` sin avisos, `00:20 +211: All tests passed!` en la app (208 + 3 del botón Atrás) y `+42` en el backend, salida 0.

## Prueba manual

No se hizo prueba en el emulador. El recorrido está cubierto con pruebas de widgets sobre la app completa (`appDePrueba` y `Dependencias.simuladas`).

## Notas para el reviewer

- **Error encontrado y arreglado (T18):** el `Navigator` propio de la compuerta tomaba el `HeroController` de `MaterialApp`, y Flutter no deja compartirlo entre dos `Navigator` ("A HeroController can not be shared by multiple Navigators"). Por eso va dentro de `HeroControllerScope.none`. No cambia el diseño: es un detalle para que el `Navigator` que pide el design ande.
- **Orden de las tasks:** al quitar parámetros de `AlertasRepositoryRemoto` (T5) dejaron de compilar `dependencias.dart` y `main.dart`. Por eso, junto con T10, ya se sacaron de ahí `tareas`, `pendientesDao` y `workmanager`, y en ese momento también se conectó `ConexionRepository` en `Dependencias`. La compuerta en `main.dart` se armó en T19, como dice el spec.
- **Ayudas de prueba agregadas** (no las nombra el design): `AlertasServiceQueFalla` (falla con el error que se le pase), y `AlertasDaoEnMemoria` y `TurnosDaoEnMemoria`. Hicieron falta porque SQLite hace I/O real, que no avanza con el tiempo falso de `testWidgets`, y la prueba de R10 necesita DAOs con datos. Las pruebas de widgets de T20 arman `Dependencias.simuladas` a mano cuando necesitan DAOs, así `appDePrueba` queda con el único parámetro nuevo que pide el design (`conexion`).
- **Pruebas de `ConexionViewModel`:** cada una llama a `vm.dispose()` al final, porque `flutter_test` revisa que no queden timers vivos antes de correr los `addTearDown`.
- **Botón Atrás sin conexión (R25, resuelto):** lo que antes quedaba fuera del spec (Atrás sin conexión cerraba la ruta tapada) el equipo lo sumó como R25 (commit c343316). Se implementó tal cual el design: `AtrasSinConexion` por encima de `MaterialApp`, cuyo observador queda registrado antes que el de `_WidgetsAppState`. Se comprobó que las dos pruebas de R25 fallan si `didPopRoute` devuelve `false` (cambio temporal, ya revertido), así que prueban el orden de los observadores del armado real. `CompuertaDeConexion`, `SinConexionScreen` y `dependencias.dart` no cambiaron.
