# Exploración: modelo de turnos (para la feature 21 `aviso_turno_incompleto`)

> Escrito por el leader con el informe del explorador (que no podía escribir archivos).

Criterios de aceptación: feature_list.json:243-256.

## 1. Cómo se representa un turno, y la hora de inicio

**En la app**
- `enum Franja` (lib/domain/models/turno.dart:6-22) tiene solo un texto para mostrar, no horas: `temprano('20:00 - 22:00')`, `noche('22:00 - 00:00')`, `madrugada('00:00 - 02:00')`.
- No hay un `DateTime` de inicio ni de fin: para calcular "1 hora antes" hay que agregar las horas (por ejemplo, `horaInicio` en `Franja`).
- `Turno` (turno.dart:26-89): `fecha` (solo el día), `franja`, `patrulleros` (`Vecino`) y `guardiaVentana` (nullable). Métodos `vacio` (:66), `incluye` (:68), `companierosDe` (:72). `fromJson` (:34) parsea "2026-10-09" a medianoche local; `toMap` (:77-86) guarda "yyyy-MM-dd".
- Zona horaria: ninguna explícita; hora local del teléfono o del servidor. `horaYMinutos` (lib/domain/avisos_tardios.dart:53-58) usa la zona del teléfono.
- **Duda abierta:** `madrugada` "00:00 - 02:00" ¿de qué día? No hay regla en código ni specs. Cambia el día del aviso de la hora antes (23:00 del día anterior o del mismo día).

**En el backend**
- Turnos como mapas en `Almacen.turnos`, clave `"fecha|franja"` (backend/lib/src/almacen.dart:55-56, :65). Forma: `{fecha, franja, patrulleros: [ids], guardia_ventana: id | null}` (ejemplos en backend/lib/src/datos_de_ejemplo.dart:98-128).
- Franjas válidas solo por nombre: `ReglasTurnos.franjas` (backend/lib/src/reglas.dart:15). El backend no conoce horarios.
- `Reloj` (backend/lib/src/reloj.dart): `RelojDelSistema` (`DateTime.now()` local) y `RelojFijo` (pruebas); se crea en backend/bin/servidor.dart:18.
- No hay ningún temporizador, `Timer` ni planificador en el backend.

## 2. Quiénes cuentan como "personas anotadas"

- Dos roles por turno (turno.dart:24-25): patrulla, hasta `cupoPatrulla = 2` (lib/domain/reglas_turnos.dart:13; backend reglas.dart:12), y guardia de ventana, un vecino de 70 o más (`edadGuardiaVentana = 70`, reglas_turnos.dart:16).
- El rol se decide por edad: app `vecino.esGuardiaVentanaEn(hoy)` (lib/domain/models/vecino.dart:63); backend `ReglasTurnos.esGuardiaVentana` (reglas.dart:26), usado en backend/lib/src/api.dart:395-399. La feature 20 permitiría que un mayor de 70 patrulle.
- No existe el concepto de "turno incompleto". Lo más cercano: la tarjeta cuenta lugares libres con `patrulleros.length` (lib/ui/turnos/widgets/turnos_screen.dart:363-373) y `detalleDe` muestra "Sin compañero todavía".
- **Inferencia a confirmar:** "una sola persona" se refiere a los patrulleros; la guardia de ventana no reemplaza al segundo patrullero. 1 patrullero + 1 guardia de ventana = incompleto.
- Casos a definir: 0 patrulleros + 1 guardia de ventana; si la guardia de ventana también recibe "no se hace"; turnos con 0 personas no son "una sola persona".

## 3. Endpoints, almacén y reglas en el backend

- Rutas (api.dart:61-63), todas con sesión:
  - `GET /turnos?anio=&mes=` → `_turnos` (:349-357), con vecinos adentro (`_turnoCompleto`, :451-462, sin `rol`).
  - `PUT /turnos/<fecha>/<franja>/vecinos/<vecinoId>` → `_anotarse` (:359-404): solo el mismo vecino (`_soloElMismoVecino`, :488-494, 403); `_validarTurno` (:427-435); `ReglasTurnos.motivoNoDisponible` (409); agrega como guardia de ventana o patrullero según la edad (:393-399); `_almacen.guardar()`. Idempotente.
  - `DELETE` misma ruta → `_salir` (:406-425): saca al vecino; 404 si no existe; el turno queda aunque esté vacío.
  - `_turnosDelMes` (:437-442), `_cantidadEnElMes` (:444-448).
- `Almacen` (almacen.dart:24-205): memoria + archivo JSON (`guardar`, :135-151, temporal y renombre); turnos en `_leer` (:167).
- Reglas duplicadas: backend reglas.dart:10-53 (`motivoNoDisponible` :30-52) y app lib/domain/reglas_turnos.dart:6-42. Orden: ya anotado → null; máximo `maxTurnosPorMes = 2`; guardia de ventana ocupada; patrulla completa. Sin reglas de anticipación.
- Push backend (backend/lib/src/push_service.dart): `PushService` (:8-19) con `enviarAlerta` y `enviarReapertura`; `PushServiceFcm` manda mensajes de datos al tópico fijo `alertas` (:77, :111-133). **No hay tokens por dispositivo ni por vecino**: se puede avisar a todos, no a uno. Para el aviso de 30 min: guardar tokens FCM por vecino, o mandar al tópico con el id del vecino y que la app filtre.
- Inyección en `Api` (api.dart:19-31) y servidor.dart:20-25; los fallos de push se ignoran (api.dart:298-303, :339-343).

## 4. Turnos en la app

- `TurnosService` (lib/data/services/turnos_service.dart:2-21): HTTP (lib/data/services/http/turnos_service_http.dart) y simulado (lib/data/services/simulados/turnos_service_simulado.dart, lógica en servidor_simulado.dart:109-199, repite las reglas).
- `TurnosRepositoryRemoto` (lib/data/repositories/turnos_repository.dart:32-151): memoria por mes (`FuturoConEstado`, :45); sin conexión usa la copia (`_cargarTurnos`, :68-89); `anotarse`/`salir` (:110-128) actualizan memoria y copia (`_actualizarCache`, :132-150).
- Mes del prototipo fijo: `DateTime(2026, 10)` (lib/dependencias.dart:210-211).
- SQLite `turnos` (lib/data/services/local/base_de_datos.dart:42-51), PK `(fecha, franja)`, esquema v4 (:19); DAO turnos_dao.dart (`delMes` :18, `reemplazarMes` :30, `guardar` :46).
- `TurnosViewModel` (lib/ui/turnos/view_models/turnos_view_model.dart:19-204): `misTurnos` (:66-78), `turno` (:101-106), `marcaDe` (:108-114), `motivoNoDisponible` (:117-126), `detalleDe` (:129-147, "Sin compañero todavía" en :143), `anotarse`/`salir` (:167-197) publican `TurnosActualizados` (lib/domain/evento_de_app.dart:7-9).
- `InicioViewModel`: `ResumenTurno` (:18), `_resumir` (:136-170).
- Pantallas: turnos_screen.dart (`_VistaCalendarioTurnos` :118, `_VistaListaMisTurnos` :190, `_TarjetaFranja` :338+); inicio_screen.dart.

**Preferencia de avisos**
- Local: `Preferencias.notificaciones()` (lib/data/services/local/preferencias.dart:44-48), arranca apagada; perfil (lib/ui/perfil/view_models/perfil_view_model.dart:92-93, :145-165) suscribe/desuscribe del tópico (:163, :165).
- `procesarAvisoPush` (lib/data/services/push_service.dart:112-146) revisa la preferencia (:130, :163) y distingue por `aviso` (:118; hoy solo `reabierta`). Un aviso de turno necesitaría otro valor (p. ej. `turno_incompleto`).
- Suscripción: push_service.dart:186-224; principal_screen.dart:111-116.
- `vigilante_de_alertas.dart:52-90`: `Timer.periodic` solo en primer plano. No hay `zonedSchedule` ni WorkManager.

## Huecos para diseñar

1. Hora de inicio de cada franja y de qué día es `madrugada`.
2. Qué cuenta como "una sola persona".
3. Planificador en el backend (`Timer` con `Reloj`, probable con `RelojFijo`) o avisos programados en el teléfono.
4. Envío a un solo vecino (hoy solo tópico, sin tokens por vecino).
5. No duplicar avisos (marcar en el turno) y no mandarlos si alguien se anota antes.
6. Reglas y franjas en tres lugares: app, backend y servidor simulado.
