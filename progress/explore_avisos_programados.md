# Exploración: avisos programados por hora (feature 21 `aviso_turno_incompleto`)

> Escrito por el leader con el informe del explorador (que no podía escribir archivos).

Criterios: `feature_list.json:244-256`.

## 1. Backend

**Sin tareas periódicas.** No hay `Timer`, cron ni planificador en `backend/lib` ni `backend/bin` (único `Duration`: datos de ejemplo, `almacen.dart:197`). Los push salen solo como reacción a un pedido: crear alerta (`api.dart:277` → `notificarAlerta`, `:298-303`) y reabrir (`api.dart:331-333` → `_notificarReapertura`, `:339-343`), ambos con `catch (_) {}`. `bin/servidor.dart:16-46` arma `Api` y `serve()`; una tarea periódica arrancaría ahí con `Timer.periodic` de `dart:async` (sin paquetes nuevos).

- Turnos en `Almacen.turnos` (`almacen.dart:56`), clave `'$fecha|$franja'` (`:65`), forma `{fecha, franja, patrulleros, guardia_ventana}` (`api.dart:374-379`), persistidos en `datos/barrio.json`. Anotarse `api.dart:359-404`, salir `:406-425`; ninguno avisa hoy.
- El backend no conoce horarios: solo `ReglasTurnos.franjas` (`backend/lib/src/reglas.dart:15`). Los horarios viven como texto en `lib/domain/models/turno.dart:6-9`. Habría que duplicarlos (regla de duplicación a propósito, `docs/architecture.md:71-74`).
- **Ambigüedad:** `madrugada` de la fecha D, ¿00:00 de D o de D+1 (después de `noche` de D)? Lo define el spec.

**`PushService` (`backend/lib/src/push_service.dart`).** Interfaz `:8-19` (`enviarAlerta`, `enviarReapertura`); `PushServiceNinguno` `:23-34`; `PushServiceFcm` `:38-134` con FCM HTTP v1 (`googleapis_auth`, `http` ya están), cliente inyectable (`conCliente`, `:43-51`). `_enviar` (`:111-133`) manda siempre al tópico fijo `alertas` (`:77`) mensajes de solo datos (`_comoTexto`, `:105-108`), con `aviso` para distinguir (`avisoReabierta`, `:81`).

- **No hay tokens FCM por vecino**: el almacén no los guarda (`api.dart:138-148`) y la app solo hace `subscribeToTopic('alertas')` (`lib/data/services/push_service.dart:216-219`).
- Opciones para avisar a un vecino puntual sin paquetes nuevos:
  1. **Tópico por vecino** (`vecino_<id>`): la app se suscribe al ingresar y se desuscribe al salir o apagar avisos; en el backend se parametriza el `topic`.
  2. Tópico `alertas` con `vecino_id` y filtro en el teléfono: simple, pero expone el id y el turno a todos (choca con privacidad, `docs/architecture.md:84-86`).
  3. Tokens por vecino: ruta nueva, `getToken`, renovación. El cambio más grande.
- Para avisar a todos basta el tópico `alertas` con un `aviso` nuevo (p. ej. `turno_incompleto`). Ojo: `_idDeMensaje` (`lib/data/services/push_service.dart:236-239`) toma `data['id']` como id de alerta.

**Reloj.** `backend/lib/src/reloj.dart:3-21` (`RelojFijo.hora` mutable). Se inyecta en `Api(reloj:)` (`api.dart:19-27`) y `Almacen.abrir(reloj:)` (`almacen.dart:29`); `servidor.dart:18` usa `RelojDelSistema`. Conviene un método puro tipo `revisarTurnos()` que el `Timer.periodic` llame y las pruebas llamen a mano con `RelojFijo` y `PushServiceFalso` (`backend/test/api_test.dart:13-38`). Para no repetir avisos tras un reinicio, marcar en el turno qué aviso salió. La zona horaria es la local de la máquina del servidor.

## 2. App

- `manejarMensajePushEnSegundoPlano` (`lib/data/services/push_service.dart:26-45`, isolate aparte) → `procesarAvisoPush` (`:112-146`), que separa por `datos['aviso']` (`'reabierta'` → `_procesarReapertura`, `:152-179`; si no, alerta nueva con `alertaDesdeDatosPush`, `:49-85`, que descarta lo que no es alerta). Respeta la preferencia (`:130`) y las propias (`:132-133`). Un push de turno necesita su propia rama.
- No se escucha `FirebaseMessaging.onMessage`: `inicializar` (`:206-213`) solo registra `onBackgroundMessage` y `onMessageOpenedApp`. **Con la app abierta un push de turno no se vería** sin `onMessage` o un vigilante de turnos.
- `VigilanteDeAlertas` (`lib/ui/principal/vigilante_de_alertas.dart:30-194`): `Timer.periodic` 45 s solo en primer plano; solo alertas.
- `NotificacionesService` (`lib/data/services/notificaciones_service.dart:9-45`): solo alertas; `_mostrar` (`:155-168`) con id `alerta.id.hashCode` y payload `alerta:<id>` (`:57`); `_idDeAlerta` (`:180-183`) ignora otros prefijos; un canal `'alertas'` (`:61-71`). Turnos necesita métodos nuevos, payload `turno:` y quizá canal "Turnos"; también `NotificacionesServiceNinguno` (`:187-219`).

**Notificaciones locales programadas.** `flutter_local_notifications ^22.3.2` tiene `zonedSchedule`, pero:
- `timezone` es solo transitiva (`pubspec.lock:880-883`); importarla desde `lib/` exige declararla (paquete nuevo); para la zona del teléfono se suele usar `flutter_timezone` (tampoco está).
- Nada configurado (`zonedSchedule`, `initializeTimeZones`, `cancel`).
- `AndroidManifest.xml` sin `SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM`, `RECEIVE_BOOT_COMPLETED` ni los receivers del plugin; sin alarmas exactas, `inexactAllowWhileIdle` puede atrasarse minutos.
- Capacidades: `muestraNotificaciones` Android e iOS; `recibeAvisosPush` solo Android (`lib/plataforma/capacidades.dart:47-59`, `lib/main.dart:33-41`).

Paquetes presentes: `flutter_local_notifications`, `firebase_core`, `firebase_messaging`, `shared_preferences`, `sqflite`, `http`. Ausentes: `timezone` directo, `flutter_timezone`, `workmanager`, `android_alarm_manager`.

Por defecto la app usa el servidor simulado (`main.dart:43-60`), que no manda push. Reloj de la app: `lib/data/services/reloj.dart:2-21`; `AvisosRecibidosRepository.horaDelServidor()` corrige el desfase.

## 3. Preferencia de avisos

Solo en el teléfono: `Preferencias.claveNotificaciones` (`lib/data/services/local/preferencias.dart:21`, `:44-48`), arranca en `false`. `PerfilViewModel.activarAvisos()` (`perfil_view_model.dart:148-156`) y `cambiarNotificaciones` (`:158-167`) suscriben o desuscriben del tópico; cerrar sesión desuscribe (`:176-179`); `principal_screen.dart:111-119` resuscribe. Se respeta por la suscripción, en `procesarAvisoPush` (`:130`, `:163`) y en el vigilante (`:137`, `:147`). El servidor no la conoce.

## 4. Enfoques

**A. Temporizador en el servidor + push FCM.** A favor: el servidor es la fuente de verdad (si alguien se anota antes, no sale), sin paquetes nuevos, funciona con la app cerrada, encaja con "requiere conexión", fácil de probar. Riesgos: solo Android (`recibeAvisosPush`); en primer plano no se ve sin `onMessage` o vigilante; aviso puntual necesita tópico por vecino; persistir qué aviso salió; qué hacer si el servidor estuvo caído; zona horaria del servidor y horarios duplicados; regla de avisos tardíos no pensada para turnos; el servidor simulado no manda push; sin credenciales FCM no sale nada.

**B. Notificaciones locales programadas (`zonedSchedule`).** Paquetes nuevos (`timezone`, probablemente `flutter_timezone`) → `blocked` hasta aprobación; cambios en el manifiesto y permisos de alarmas exactas; con la app cerrada no puede cancelar el aviso si alguien se anota (rompe el criterio 3) salvo con `workmanager` (otro paquete); cada teléfono programaría todos los turnos desde la caché, que no es fuente de verdad. A favor: iOS sin FCM y avisa sin red.

**Combinación propuesta.** Servidor como fuente de verdad: `Timer.periodic` en `servidor.dart` que llama a un método testeable con `Reloj`; FCM al tópico `alertas` con `aviso: 'turno_incompleto'` para todos y tópico por vecino para el aviso de 30 min. En la app: rama nueva en `procesarAvisoPush` que respeta la preferencia, métodos nuevos en `NotificacionesService` con payload `turno:`, y `onMessage` o vigilante para el primer plano. Sin paquetes. A definir: fecha de `madrugada`, zona horaria, persistencia de avisos enviados, política si el servidor estuvo caído o el aviso llega tarde.
