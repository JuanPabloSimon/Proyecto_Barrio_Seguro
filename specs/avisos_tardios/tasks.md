# Tasks — avisos_tardios

> Pasos en orden. El `implementer` marca `[x]` al terminar cada uno. Cada
> task dice qué `R<n>` cubre.

## Dominio

- [x] T1 — Crear `lib/domain/avisos_tardios.dart` con `demoraParaTardia`, `demoraMaximaParaAvisar`, `PuntualidadAviso`, `clasificarAviso` y `esTardia`. Cubre: R1.
- [x] T2 — Pruebas en `test/unit/avisos_tardios_test.dart`: `4:59 y 5:00 de demora llegan a tiempo`, `5:01 de demora es tardío`, `2 horas exactas es tardío`, `2 horas y 1 segundo es demasiado tardío`, `una demora negativa llega a tiempo`. Cubre: R1.
- [x] T3 — Agregar `nombreCorto` (`String?`, `null` para arrebato), `tipoParaAviso`, `horaYMinutos`, `tituloAvisoTardio` y `cuerpoAvisoTardio` en `lib/domain/avisos_tardios.dart`. Cubre: R14, R16, R17, R18.
- [x] T4 — Pruebas en `test/unit/avisos_tardios_test.dart`: `nombre corto de sos, robo, actividad sospechosa, vehículo y ruidos`, `arrebato no tiene nombre corto y el título usa el tipo de la alerta ("Arrebato de Marta 15:10")`, `título "SOS de Marta 15:10"`, `título "Robo de Marta 15:10"`, `la hora va con dos dígitos en 24 horas ("09:05", "23:50")`, `una alerta de las 23:50 recibida a las 00:30 dice solo "23:50"`, `sin nombre dice "de un vecino"`, `el cuerpo es el texto acordado`. Cubre: R14, R16, R17, R18.
- [x] T5 — Agregar `reportadaPorNombre` a `Alerta` (`fromJson`/`toJson`, `''` si falta) en `lib/domain/models/alerta.dart`. Cubre: R11.
- [x] T6 — Pruebas en `test/unit/dominio_test.dart`: `reportada_por_nombre viaja en el JSON` y `una alerta sin reportada_por_nombre lo toma vacío`. Cubre: R11.

## Datos

- [x] T7 — Claves y métodos `avisosRecibidos`/`guardarAvisosRecibidos` y `desfaseReloj`/`guardarDesfaseReloj` en `lib/data/services/local/preferencias.dart` (en `todasLasClaves`). Cubre: R4, R5.
- [x] T8 — Crear `lib/data/repositories/avisos_recibidos_repository.dart` (`AvisosRecibidosRepository` + `AvisosRecibidosRepositoryLocal`, con borrado de llegadas de más de 30 días). Agregar `AvisosRecibidosFalsos` en `test/ayudas/falsos.dart`. Cubre: R4, R5, R6.
- [x] T9 — Pruebas en `test/unit/repositorios_test.dart`: `la llegada es la hora del teléfono más el desfase guardado`, `sin desfase guardado la llegada es la hora del teléfono`, `la segunda llegada de la misma alerta conserva la primera`, `las llegadas de más de 30 días se borran al registrar`. Cubre: R4, R5, R6.
- [x] T10 — `ConexionService.desfase`; `ConexionServiceHttp` con `Reloj` que mide el desfase con `ahora` de `/salud`; `ConexionServiceSimulado.desfase`; `ConexionRepositoryRemoto` con `avisos` que guarda el desfase. Cubre: R3.
- [x] T11 — Pruebas en `test/unit/conexion_test.dart`: `/salud con ahora mide el desfase en el punto medio del pedido`, `/salud sin ahora no cambia el desfase y sigue dando conexión`, `una comprobación buena guarda el desfase en el teléfono`. Cubre: R3.
- [x] T12 — Columna `reportada_por_nombre` en `sqlCrearAlertas`, `versionDelEsquema = 4` y migración `anterior < 4` en `lib/data/services/local/base_de_datos.dart`. Cubre: R11, R12.
- [x] T13 — Pruebas en `test/unit/persistencia_test.dart`: `migración v3 → v4 agrega reportada_por_nombre sin perder alertas` y `la copia local guarda y lee reportada_por_nombre`. Cubre: R11, R12.
- [x] T14 — `avisarAlertaTardia` en `NotificacionesService`, `NotificacionesServiceLocales`, `NotificacionesServiceNinguno` y `NotificacionesFalsas` (lista `tardias`). `alertaDesdeDatosPush` lee `reportada_por_nombre`. `procesarAvisoPush` recibe `avisos`, registra la llegada y elige aviso normal, tardío o ninguno; el handler de segundo plano arma su `AvisosRecibidosRepositoryLocal`. Actualizar las pruebas push existentes con `AvisosRecibidosFalsos` y una llegada cercana a `creada_en`. Cubre: R5, R11, R13, R14, R15.
- [x] T15 — Pruebas en `test/unit/notificaciones_test.dart` (grupo "Avisos push con la app cerrada"): `un push a tiempo se avisa igual que antes`, `un push con más de 5 minutos de demora muestra el aviso tardío con título y cuerpo`, `un push con más de 2 horas de demora no muestra notificación pero guarda la llegada`, `con los avisos apagados no se guarda la llegada`, `un push propio o resuelto no guarda la llegada`, `los datos del push traen reportada_por_nombre`. Cubre: R5, R7, R11, R13, R14, R15.
- [x] T16 — `reportada_por_nombre` en las alertas que devuelve `lib/data/services/simulados/servidor_simulado.dart`. Prueba `el servidor simulado devuelve el primer nombre de quien reportó` en `test/unit/repositorios_test.dart`. Cubre: R8, R11.

## Vigilante, ViewModels y pantallas

- [x] T17 — `VigilanteDeAlertas` con `avisos`: guarda llegadas (solo con avisos activos), publica `AlertasActualizadas`, después avisa según la clasificación; devuelve las avisadas. Pasarle `d.avisos` en `principal_screen.dart`. Cubre: R5, R6, R7, R19.
- [x] T18 — Pruebas en `test/unit/notificaciones_test.dart` (grupo "Vigilante de alertas"): `una alerta nueva a tiempo se avisa igual que antes`, `una alerta nueva con 10 minutos de demora se avisa como tardía`, `una alerta nueva con 3 horas de demora no se avisa`, `si el push ya guardó una llegada a tiempo, el vigilante avisa a tiempo`, `con los avisos apagados no guarda llegadas`. Cubre: R6, R7, R13, R19.
- [x] T19 — `marcaTardia` en `lib/ui/core/formato.dart`. Cubre: R20, R21.
- [x] T20 — Pruebas en `test/unit/dominio_test.dart` (o donde estén las de `formato.dart`): `marca de una alerta de hoy: "Llegó con demora. Alerta de las 15:10"` y `marca de una alerta de otro día: "Llegó con demora. Alerta del 24/11 a las 23:50"`. Cubre: R20, R21.
- [x] T21 — `InicioViewModel`, `MapaViewModel` y `DetalleAlertaViewModel` con `avisos`: cargan llegadas, `tardia(...)`/`tardias`/`cargarLlegada()`. `DetalleAlertaViewModel.reportadaPor` ("Vos", el nombre o "Un vecino"). Pasar `d.avisos` en `principal_screen.dart` y `DetalleAlertaScreen.abrir`. Cubre: R20, R24, R25, R26, R32, R33, R34.
- [x] T22 — Pruebas en `test/unit/view_models_test.dart`: `inicio marca como tardía una alerta con llegada tardía`, `inicio no marca una alerta con llegada a tiempo ni una sin llegada`, `una alerta demasiado tardía aparece en el inicio y en el mapa con marca`, `mapa expone las marcas por id`, `detalle carga la marca de su alerta`, `si leer las llegadas falla no hay marcas y la lista se ve`, `detalle de una alerta ajena con nombre: reportadaPor es el nombre`, `detalle de una alerta ajena sin nombre: reportadaPor es "Un vecino"`, `detalle de una alerta propia: reportadaPor es "Vos" aunque traiga nombre`. Cubre: R20, R24, R25, R26, R32, R33, R34.
- [x] T23 — Crear `lib/ui/core/widgets/marca_tardia.dart`; pares de contraste en `app_colors.dart`. Cubre: R27, R30.
- [x] T24 — `TarjetaAlerta` con `tardia` (marca + etiqueta) y uso en `inicio_screen.dart`. Cubre: R20, R28.
- [x] T25 — `PinAlerta(tardia:)`, `MapaBarrio(tardias:)` con etiqueta, uso en inicio y mapa; marca en el resumen del mapa; ítem de la leyenda. Cubre: R22, R23, R28, R31.
- [x] T26 — `MarcaTardia` en el detalle. "Reportada por" muestra `viewModel.reportadaPor` (deja de decir "Un vecino de la zona") dentro de `MergeSemantics`. Cubre: R24, R32, R33, R34, R35.
- [x] T27 — Pruebas en `test/widget_test.dart`: `el inicio muestra "Llegó con demora. Alerta de las …" en la tarjeta de una alerta tardía`, `una alerta a tiempo no muestra la marca`, `el pin de una alerta tardía tiene el reloj y el resumen muestra la marca`, `el detalle de una alerta tardía muestra la marca`, `la leyenda muestra "Llegó con demora"`, `la marca tiene ícono de reloj y texto`, `el detalle de una alerta ajena muestra el nombre de quien la reportó`, `el detalle de una alerta ajena sin nombre muestra "Un vecino"`, `el detalle de una alerta propia muestra "Vos"`, `la tarjeta y el resumen del mapa no muestran quién reportó`. Cubre: R20, R22, R23, R24, R25, R26, R27, R31, R32, R33, R34.
- [x] T28 — Pruebas en `test/accesibilidad_test.dart`: `la etiqueta de la tarjeta y del pin incluyen la marca`, guías (`androidTapTargetGuideline`, `iOSTapTargetGuideline`, `labeledTapTargetGuideline`, `textContrastGuideline`) con alerta tardía en inicio, resumen del mapa y detalle, `texto al 200 % sin desbordes con la marca`, y los pares de la marca en la prueba de `paresDeContraste`. `el lector lee "Reportada por" y el nombre en una sola etiqueta` y `"Reportada por" con nombre al 200 % sin desbordes` en el detalle. Cubre: R28, R29, R30, R35.

## Backend

- [x] T29 — `GET /salud` con `ahora` (del `Reloj` del backend) en `backend/lib/src/api.dart`. Cubre: R2.
- [x] T30 — Prueba `GET /salud devuelve estado ok y la hora del servidor` en `backend/test/api_test.dart`. Cubre: R2.
- [x] T31 — `_conNombre(alerta)` en `GET /alertas`, `POST /alertas`, `PATCH /alertas/<id>` y en la llamada a `notificarAlerta`, sin guardarlo en el almacén. Cubre: R8, R9, R10.
- [x] T32 — Pruebas en `backend/test/api_test.dart`: `las alertas traen el primer nombre de quien las reportó` (las tres rutas), `el push de una alerta nueva trae reportada_por_nombre`, `ni la alerta ni el push traen otros datos de quien reportó` (conjunto exacto de claves), `reportada_por_nombre no se guarda en el almacén`. Cubre: R8, R9, R10.
- [x] T33 — Actualizar `backend/README.md`: `/salud` con `ahora` y `reportada_por_nombre` en las alertas y el push. Cubre: R2, R8, R9.

## Cierre

- [x] T34 — Trazabilidad `R<n>` → prueba en `progress/impl_avisos_tardios.md`.
- [x] T35 — `./init.sh` verde.
