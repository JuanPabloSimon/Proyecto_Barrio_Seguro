# Tasks — requiere_conexion

> Pasos en orden. El `implementer` marca `[x]` al terminar cada uno. Cada
> task dice qué `R<n>` cubre. Ver `design.md` para firmas y decisiones.

## Datos: detección de la conexión

- [x] T1 — Crear `ConexionService` en `lib/data/services/conexion_service.dart`, `ConexionServiceHttp` en `lib/data/services/http/conexion_service_http.dart` (`GET /salud` con `ClienteApi`, tope de 5 s, nunca lanza) y `ConexionServiceSimulado` en `lib/data/services/simulados/conexion_service_simulado.dart`. Cubre: R2, R3.
- [x] T2 — Pruebas en `test/unit/conexion_test.dart` con `MockClient`: `/salud con {"estado":"ok"} da conexión`; `/salud con HTML de portal de acceso da sin conexión`; `/salud con 500 da sin conexión`; `error de red da sin conexión`; `/salud que tarda más de 5 s da sin conexión`. Cubre: R2, R3.
- [x] T3 — Crear `ConexionRepository` y `ConexionRepositoryRemoto` en `lib/data/repositories/conexion_repository.dart` (`hayConexion`, `cambios` solo cuando cambia, `comprobar()` sin pedidos duplicados en vuelo). Agregar `ConexionFalsa` (servicio, con `hay` mutable y contador `comprobaciones`) y `ConexionRepositoryFalsa` en `test/ayudas/falsos.dart`. Cubre: R1, R4.
- [x] T4 — Pruebas en `test/unit/conexion_test.dart`: `dos comprobar() simultáneos hacen un solo pedido`; `cambios emite solo cuando cambia el resultado`. Cubre: R1, R4.

## Datos: quitar el envío diferido

- [x] T5 — En `lib/data/repositories/alertas_repository.dart`: quitar `estaPendiente`, `enviarPendientes`, `_pendientes`, `_tareas`, `_reloj`, `_prefijoPendiente`, `_leerPendientes`, `_guardarPendiente` y la rama pendiente de `cambiarEstado`; `crearAlerta` relanza cualquier error; recibir `ConexionRepository? conexion` y llamar `comprobar()` cuando `obtenerAlertas` o `crearAlerta` fallan por la red (no ante `ErrorDelServidor`). Actualizar los comentarios de la clase. Cubre: R4, R16, R20.
- [x] T6 — En `lib/data/repositories/turnos_repository.dart`: recibir `ConexionRepository? conexion` y llamar `comprobar()` cuando `obtenerTurnos` falla por la red. Cubre: R4, R20.
- [x] T7 — Pruebas en `test/unit/persistencia_test.dart`: `crear una alerta sin red lanza el error y no guarda nada en el teléfono`; `si falla la red al pedir alertas se comprueba la conexión`; `si falla la red al pedir turnos se comprueba la conexión`; `un ErrorDelServidor no dispara la comprobación`. Confirmar que siguen verdes las pruebas existentes de copia guardada con `sinConexion` (alertas y turnos). Cubre: R4, R16, R20.
- [x] T8 — En `lib/data/services/local/base_de_datos.dart`: `versionDelEsquema = 3`, quitar `sqlCrearPendientes`, `onCreate` sin la tabla, `onUpgrade` con `if (anterior < 3) DROP TABLE IF EXISTS alertas_pendientes`, comentario de versiones al día. Quitar `sqlCrearPendientes` de `test/ayudas/bases_de_prueba.dart`. Cubre: R18, R19.
- [x] T9 — Pruebas en `test/unit/persistencia_test.dart`: `una base nueva no tiene tabla de alertas pendientes` (consulta a `sqlite_master`); `la migración de la v2 a la v3 borra alertas_pendientes y conserva alertas y turnos`. Borrar de `test/unit/notificaciones_test.dart` la prueba de migración a la v2. Cubre: R18, R19.
- [x] T10 — Borrar `lib/data/services/local/pendientes_dao.dart`, `lib/data/services/tareas/envio_de_pendientes.dart`, `lib/data/services/tareas/tarea_de_fondo.dart` y `lib/data/services/tareas/tareas_service.dart`. Borrar en `test/unit/notificaciones_test.dart` los grupos "Alertas sin señal" y "Tarea de envío", y en `test/ayudas/falsos.dart` `TareasFalsas`, `enviosDePendientes`, `estaPendiente` y `enviarPendientes`. Cubre: R16, R18.
- [x] T11 — Quitar `correTareasEnSegundoPlano` de `lib/plataforma/capacidades.dart` y de `CapacidadesFalsas`; corregir el comentario de `tieneBaseDeDatosLocal` (caché, no "usar sin conexión"). Quitar `workmanager` de `pubspec.yaml` y correr `flutter pub get` para actualizar `pubspec.lock`. Cubre: R18.

## ViewModels existentes

- [x] T12 — En `lib/ui/principal/vigilante_de_alertas.dart`: quitar `enviarPendientes()` de `revisar()` y la mención en el comentario. Borrar en `test/unit/notificaciones_test.dart` la prueba `cada revisión intenta mandar las alertas pendientes`; las demás del vigilante quedan. Cubre: R16.
- [x] T13 — En `lib/ui/sos/view_models/sos_view_model.dart`: quitar `pendiente` y el comentario duplicado de `enviar()`. En `lib/ui/sos/widgets/sos_screen.dart`: quitar `pendiente` de `_VistaSosEnviada` y los textos "Alerta guardada" y "No hay señal. La alerta se va a enviar sola…". Cubre: R16, R17.
- [x] T14 — Pruebas: en `test/unit/view_models_test.dart`, `el SOS sin red queda en error y no se guarda`; en `test/widget_test.dart`, `el SOS sin red muestra "No pudimos enviar la alerta. Probá de nuevo o llamá al 911."`. Cubre: R16, R17.

## ViewModel de conexión

- [x] T15 — Crear `EstadoConexion` y `ConexionViewModel` en `lib/ui/conexion/view_models/conexion_view_model.dart` (`empezar`, `alPasarASegundoPlano`, `alVolverAPrimerPlano`, reloj de 30 s con conexión y de 5 s sin conexión, escucha `cambios`, publica `AlertasActualizadas` y `TurnosActualizados` al volver la conexión, `dispose` cancela todo). Cubre: R1, R4, R5, R6, R7, R8, R15.
- [x] T16 — Pruebas en `test/unit/conexion_test.dart` (con `testWidgets` y `tester.pump` para el tiempo): `al empezar comprueba la conexión`; `con conexión vuelve a comprobar a los 30 s`; `sin conexión vuelve a comprobar a los 5 s`; `en segundo plano no comprueba`; `al volver a primer plano comprueba en el momento`; `si un repositorio dispara una comprobación sin conexión el estado pasa a sinConexion`; `al volver la conexión publica AlertasActualizadas y TurnosActualizados`; `dispose cancela el reloj y la suscripción`. Cubre: R1, R4, R5, R6, R7, R8, R15.

## Pantalla sin conexión y compuerta

- [x] T17 — Crear `SinConexionScreen` en `lib/ui/conexion/widgets/sin_conexion_screen.dart` (título con `header` y `liveRegion`, texto de ayuda, ícono excluido de la semántica, botón "Llamar al 911" de 64 dp con `mostrarDialogo911`, desplazable). Cubre: R11, R12, R13, R21, R22, R23, R24.
- [x] T18 — Crear `CompuertaDeConexion` en `lib/ui/conexion/widgets/compuerta_de_conexion.dart` (`AppLifecycleListener` → ViewModel; `Offstage` + `TickerMode` del `child`; `Navigator` propio con `SinConexionScreen` mientras `sinConexion`). Cubre: R7, R8, R9, R10, R14.
- [x] T19 — Armado: `ConexionRepository conexion` en `Dependencias`; `ConexionService? conexion` en `Dependencias.simuladas`; `ConexionServiceHttp(api)` en `Dependencias.conApi`; `_armar` crea el repositorio de conexión antes que alertas y turnos y se lo pasa; quitar `tareas` y `pendientesDao` de las tres fábricas (`lib/dependencias.dart`). En `lib/main.dart`: quitar `workmanager`, `PendientesDao`, `TareasService` y `callbackDispatcher`, y armar la compuerta en `MaterialApp.builder` con `ConViewModel`. Agregar `ConexionService? conexion` a `appDePrueba` (`test/ayudas/app_de_prueba.dart`). Cubre: R1, R9.
- [x] T20 — Pruebas en `test/widget_test.dart` con `appDePrueba(conexion: ConexionServiceSimulado(conectado: false))` o `ConexionFalsa`: `sin conexión el login muestra "Necesitás conexión a internet para usar la app"`; `sin conexión con sesión abierta se tapa la principal y no se ven alertas ni turnos guardados` (con DAO con datos; también sin nodos de semántica de esas alertas); `si se corta la conexión con el SOS abierto aparece la pantalla sin conexión`; `al volver la conexión se ve el SOS como estaba` y `el texto escrito en el login sigue al volver`; `"Llamar al 911" sin conexión abre el teléfono con el 911` (`TelefonoFalso.marcados == ['911']`); `sin poder llamar muestra "Llamá al 911 desde un teléfono"`. Cubre: R9, R10, R11, R12, R13, R14.
- [x] T21 — Pruebas en `test/accesibilidad_test.dart` para `SinConexionScreen`: guías `androidTapTargetGuideline`, `iOSTapTargetGuideline`, `labeledTapTargetGuideline` y `textContrastGuideline`; `el título se anuncia como encabezado` (`SemanticsFlag.isHeader` y `isLiveRegion`); `al 200 % no desborda y "Llamar al 911" se alcanza desplazando`. Cubre: R21, R22, R23, R24.

## Documentación

- [x] T22 — `docs/architecture.md`: reemplazar el principio 7 por "Requiere conexión" (compuerta + copia local solo como caché), sacar `tareas/` del árbol y agregar `ui/conexion/`. Actualizar el comentario de `workmanager` que pudiera quedar en `AGENTS.md` o `docs/`. Cubre: R16, R18.

## Backend

Sin cambios: `GET /salud` ya existe (`backend/lib/src/api.dart`) y tiene su prueba.

## Botón Atrás sin conexión (R25, agregado después de la revisión)

- [ ] T25 — Crear `AtrasSinConexion` en `lib/ui/conexion/widgets/atras_sin_conexion.dart` (`StatefulWidget` con `WidgetsBindingObserver`: `addObserver` en `initState`, `removeObserver` en `dispose`, `didPopRoute()` devuelve `viewModel.sinConexion`). En `lib/main.dart`, subir el `ConViewModel<ConexionViewModel>` por encima de `MaterialApp` y envolver `MaterialApp` con `AtrasSinConexion`; `MaterialApp.builder` usa el mismo `vm` para `CompuertaDeConexion`. Comentario en `BarrioSeguroApp` de por qué el observador va por encima de `MaterialApp` (orden de los observadores). Cubre: R25.
- [ ] T26 — Pruebas en `test/widget_test.dart` con `tester.binding.handlePopRoute()`: `sin conexión el botón Atrás no cierra el SOS tapado y al volver se ve el SOS` (devuelve `true`, sigue la pantalla sin conexión y al volver se ve "¿Enviar alerta SOS?"); `sin conexión el botón Atrás en el inicio no cierra la app` (devuelve `true` y al volver se ve la principal); `con conexión el botón Atrás cierra el SOS como siempre` (control). Confirmar que siguen verdes las pruebas existentes de la compuerta y de accesibilidad. Cubre: R25.

## Cierre

- [ ] T23 — Trazabilidad `R<n>` → prueba en `progress/impl_requiere_conexion.md` (sumar R25), y nota en `progress/history.md` de que se quitó el paquete `workmanager`.
- [ ] T24 — `./init.sh` verde.
