# Bitácora histórica (solo se agrega al final)

> Cada sesión cerrada deja su resumen acá. No se editan entradas anteriores.

---

## Hasta 2026-11-12 — Features 1 a 11 (antes del arnés)

- **Quién:** equipo (Leandro Olarte, Carla Méndez, Francisco Villanueva, Juan Pablo Simón).
- **Resultado:** vistas, accesibilidad, mapa real, MVVM, capacidades y políticas,
  persistencia local, backend en Dart, conexión HTTP, GPS, avisos locales con
  envío sin señal y preparación para publicar. Integrado en `develop`
  (PR #20).
- **Nota:** se hicieron sin SDD; no tienen carpeta en `specs/`.

## <fecha> — Adopción del arnés SDD

- **Quién:** <nombre>
- **Cambios:** `AGENTS.md`, `CLAUDE.md`, `CHECKPOINTS.md`, `init.sh`,
  `tool/validar_harness.dart`, `feature_list.json`, `docs/`, `specs/_plantilla/`,
  `progress/`, `.claude/`.
- **Verificación:** `./init.sh` <verde / resultado>.
- **Próximo:** spec de la primera feature `pending` que el equipo elija.

## 2026-11-25 — Decisión de paquetes nuevos para feature 12 (`avisos_push`)

- **Quién:** equipo (Juan Pablo Simón).
- **Decisión:** Se aprueba incorporar los paquetes necesarios para notificaciones push con Firebase Cloud Messaging (FCM HTTP v1):
  - App (`pubspec.yaml`): `firebase_core` y `firebase_messaging` (más el plugin Gradle `com.google.gms.google-services` en `android/`).
  - Backend (`backend/pubspec.yaml`): `googleapis_auth` y `http` para autenticar con cuenta de servicio de Firebase y enviar mensajes a la API FCM HTTP v1.
- **Motivo:** Cumplir la precondición de `avisos_push` (regla de `AGENTS.md` §3, `docs/architecture.md` principio 10 y `CHECKPOINTS.md` C3) antes de redactar el spec.
- **Próximo:** redactar `specs/avisos_push/{requirements,design,tasks}.md` con `spec_author`.

## 2026-11-25 — Feature 12 (`avisos_push`): Avisos con la app cerrada (FCM)

- **Quién:** equipo (Juan Pablo Simón) + agentes SDD (`spec_author`, `implementer`, `reviewer`).
- **Resultado:** Spec completo en `specs/avisos_push/` (`requirements.md`, `design.md`, `tasks.md`). Implementación de `PushService` en la app (`PushServiceFirebase`, `PushServiceNinguno`, `procesarAvisoPush` en segundo plano filtrando alertas propias, resueltas o con avisos apagados, y apertura de detalle al tocar la notificación) y en el backend (`PushServiceFcm` por FCM HTTP v1 al tópico `alertas` al crear alertas en `POST /alertas`).
- **Verificación:** `./init.sh` verde (`flutter analyze` y `dart analyze` sin avisos, 156 pruebas en la app y 28 en el backend pasando). Review aprobado en `progress/review_avisos_push.md`.
- **Próximo:** Feature 13 (`rol_comision`).

## 2026-11-25 — Feature 13 (`rol_comision`): Rol de miembro de la comisión

- **Quién:** equipo + agentes SDD (`spec_author`, `implementer`, `reviewer`).
- **Resultado:** Spec en `specs/rol_comision/` (T1–T25). En la app: `RolVecino` (`vecino`/`comision`) y `esComision` en `Vecino`, el rol se guarda y restaura con la sesión (una sesión vieja sin rol queda como `vecino`), no se manda en el `PUT` de datos y no se guarda en la copia local de los turnos; el servidor simulado fuerza `vecino` al registrarse y rechaza cambios de rol. En el backend: `Roles` y normalización del rol al leer, Clara como `comision` en los datos de ejemplo, 403 al intentar cambiarse el rol, middleware `soloComision` y rutas montadas en `/comision/` (401 sin sesión, 403 a vecinos comunes), turnos sin `rol` y README actualizado.
- **Verificación:** `./init.sh` verde (`flutter analyze` y `dart analyze` sin avisos, 172 pruebas en la app y 42 en el backend). Review aprobado en segunda vuelta en `progress/review_rol_comision.md` (la primera pidió cubrir completo R12 y R20).
- **Próximo:** feature 14 (`informe_alertas`).

## 2026-11-25 — Etapa 1 de devolución: Segundo plano funcional (`workmanager`)

- **Quién:** equipo (Juan Pablo Simón) + implementer.
- **Resultado:** En `lib/data/services/tareas/tarea_de_fondo.dart` se inicializa `WidgetsFlutterBinding.ensureInitialized()` en el isolate de fondo y se extrae `ejecutarTareaDeFondo` para procesar alertas pendientes tanto contra `API_URL` como contra servidor simulado, actualizando `AlertasDao`. En `lib/data/repositories/alertas_repository.dart` se invalida la caché de `pendiente-` cuando el worker de segundo plano ya vació la cola en SQLite.
- **Verificación:** `flutter analyze` sin avisos y 21 pruebas en `test/unit/notificaciones_test.dart` en verde.
- **Próximo:** Etapa 2 (`Future` con estado en repositorios).

## 2026-11-25 — Etapa 2 de devolución: `Future` con estado en repositorios (`B2` y `C1`)

- **Quién:** equipo (Juan Pablo Simón) + implementer.
- **Resultado:** Creado `FuturoConEstado<T>` y `EstadoFuturo` (`inicial`, `cargando`, `exito`, `error`) en `lib/data/repositories/futuro_con_estado.dart`. Integrado en `AlertasRepositoryRemoto` y `TurnosRepositoryRemoto` para exponer el estado del `Future`, reutilizar el mismo `Future` en vuelo ante pedidos concurrentes y gestionar la caché.
- **Verificación:** `flutter analyze` sin avisos y pruebas nuevas en `test/unit/repositorios_test.dart` pasando en verde.
- **Próximo:** Etapa 3 (composición de widgets y eventos del sistema) o Features SDD #13 y #14.

## 2026-11-25 — Etapa 3 de devolución: Composición de widgets (`B1`) y Eventos del sistema (`E3`)

- **Quién:** equipo (Juan Pablo Simón) + implementer.
- **Resultado:** Refactorizados los métodos de construcción de vista a clases `StatelessWidget` privadas en `SosScreen` (`_VistaConfirmarSos`, `_VistaSosEnviada`), `DetalleAlertaScreen` (`_CuerpoDetalleAlerta`), `InicioScreen` (`_ContenidoInicio`), `MapaScreen` (`_ContenidoMapa`, `_PastillaFiltro`), `TurnosScreen` (`_ContenidoTurnos`, `_VistaCalendarioTurnos`, `_VistaListaMisTurnos`), `MisAlertasScreen` (`_ListaMisAlertas`) y `PerfilScreen` (`_CuerpoPerfil`). Mejorado `VigilanteDeAlertas` con `AppLifecycleListener` (`onPause` y `onResume`) y agregada prueba del ciclo de vida del sistema en `test/unit/notificaciones_test.dart`.
- **Verificación:** `flutter analyze` y `dart analyze` sin avisos; todas las pruebas de la app (162) y del backend (28) pasando en verde.
- **Próximo:** Features SDD #13 (`rol_comision`) y #14 (`informe_alertas`).

## 2026-11-25 — Feature 14 (`informe_alertas`): Informe de alertas para la comisión (con descarga CSV)

- **Quién:** equipo (Juan Pablo Simón) + agentes SDD (`spec_author`, `implementer`, `reviewer`).
- **Resultado:** Spec en `specs/informe_alertas/` (R1–R13, T1–T9). Implementados `InformeAlertas.delMes`, `nombreArchivoCsv` y `toCsv()` en `lib/domain/informe_alertas.dart`; `DescargaCsvService` (`DescargaCsvServiceLocal` y `DescargaCsvFalsa`) en `lib/data/services/descarga_csv_service.dart`; `InformeAlertasViewModel` y `InformeAlertasScreen` (resumen mensual por calle, por tipo y por franja horaria, selector de mes, descarga de CSV y estado vacío sin tablas ni botón de descarga); entrada `"Informe mensual de alertas"` en `PerfilScreen` visible solo para miembros de la comisión (`esComision`).
- **Verificación:** `./init.sh` verde (`flutter analyze` y `dart analyze` sin avisos, 192 pruebas en la app y 42 en el backend pasando). Review aprobado en `progress/review_informe_alertas.md`.
- **Próximo:** Todas las features (1 a 14) de `feature_list.json` están en `done`.

## 2026-11-25 — Nota de dependencias (feature 15 `requiere_conexion`)

- **Se quitó el paquete `workmanager`** de `pubspec.yaml` (y `pubspec.lock` actualizado con `flutter pub get`). Lo autoriza el design de `specs/requiere_conexion/` aprobado por el equipo: la feature 15 quita el envío diferido de alertas (feature 10) "y lo que quede sin uso", y `workmanager` solo servía para eso. Paquetes nuevos: ninguno.

## 2026-11-25 — Feature 15 (`requiere_conexion`): La app requiere conexión

- **Quién:** equipo + agentes SDD (`spec_author`, `implementer`, `reviewer`).
- **Resultado:** Spec en `specs/requiere_conexion/` (T1–T26, R1–R25). Detección de conexión con `ConexionService` (`ConexionServiceHttp` con `GET /salud` y 5 s de límite, y `ConexionServiceSimulado`) y `ConexionRepositoryRemoto` (un solo pedido en vuelo, avisa solo los cambios). `ConexionViewModel` comprueba cada 30 s con conexión y cada 5 s sin ella, y al volver publica `AlertasActualizadas` y `TurnosActualizados`. `CompuertaDeConexion` (en `MaterialApp.builder`) tapa la app con `SinConexionScreen` (título anunciado, Llamar al 911 de 64 dp, desplazable al 200 %) y `AtrasSinConexion` hace que Atrás no cierre lo tapado. Se quitó el envío diferido: `PendientesDao`, `tareas/`, `correTareasEnSegundoPlano`, la tabla `alertas_pendientes` (base v3) y los textos de "Alerta guardada"; el SOS sin red queda en error. La copia local de alertas y turnos queda solo como caché. `docs/architecture.md` con el principio 7.
- **Verificación:** `./init.sh` verde (`flutter analyze` y `dart analyze` sin avisos, 211 pruebas en la app y 42 en el backend). Review aprobado en `progress/review_requiere_conexion.md`.
- **Pendientes (no bloquean):**
  - Si se activa `android:enableOnBackInvokedCallback` (atrás predictivo), revisar R25 (`AtrasSinConexion`), como anota el design.
  - `ConexionRepositoryRemoto.cerrar()` no se llama en la app; hoy no se pierde nada porque `Dependencias` vive lo mismo que la app.
  - Falta commitear el trabajo de la rama `feature/requiere_conexion`.
- **Próximo:** feature 16 (`avisos_tardios`).

## 2026-11-25 — Feature 16 (`avisos_tardios`): Avisos de alertas que llegaron con demora

- **Quién:** equipo + agentes SDD (`spec_author`, `implementer`, `reviewer`).
- **Resultado:** Spec en `specs/avisos_tardios/` (T1–T35, R1–R35). Clasificación de la demora en `lib/domain/avisos_tardios.dart` (a tiempo hasta 5 min, tardía hasta 2 h, más de 2 h sin notificación), con título "<tipo> de <nombre> <HH:mm>" ("de un vecino" si no hay nombre) y el cuerpo acordado. `Alerta.reportadaPorNombre` (base local v4 con migración). `AvisosRecibidosRepository` guarda la primera llegada de cada alerta con la hora del teléfono corregida por el desfase que mide `GET /salud` (que ahora devuelve `ahora`) y borra las de más de 30 días. El push y el `VigilanteDeAlertas` avisan a tiempo igual que antes, tardías con `avisarAlertaTardia` o no avisan. `MarcaTardia` (ícono y texto) en la tarjeta, el detalle, el pin y la leyenda del mapa. Backend: `/salud` con `ahora` y `reportada_por_nombre` (solo el primer nombre, sin guardarlo) en las alertas y el push.
- **Verificación:** `./init.sh` verde (`flutter analyze` y `dart analyze` sin avisos, 295 pruebas en la app y 48 en el backend). Review aprobado en `progress/review_avisos_tardios.md`.
- **Pendientes (no bloquean):**
  - Llevar al equipo, como feature aparte, el layout del mapa con texto al 200 %: el ítem nuevo de la leyenda achica el mapa en 360 × 800 y el SOS tapa el pin de Arrebato (la prueba de accesibilidad pasó a `activarConLector`).
  - Si falla `registrarLlegada` (`push_service.dart`, `vigilante_de_alertas.dart`) no se muestra ningún aviso, ni siquiera un SOS a tiempo, y el vigilante no reintenta. Se podría avisar como a tiempo cuando no se puede guardar la llegada.
  - `push_service.dart` importa un repositorio desde la capa de servicios (lo pide el design); si se repite, anotarlo en `docs/architecture.md`.
  - `_cerrado` en `detalle_alerta_view_model.dart` podría llamarse `_estaCerrado`.
  - Falta commitear el trabajo de la rama `feature/avisos_tardios`.
- **Próximo:** feature 17 (`quitar_arrebato`).
