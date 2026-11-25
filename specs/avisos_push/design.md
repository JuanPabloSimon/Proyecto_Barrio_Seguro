# Design — avisos_push

> Decisiones técnicas tomadas antes de escribir código. Se apoya en
> `docs/architecture.md` y `docs/conventions.md`; acá solo va lo que esta
> feature agrega o donde roza sus límites.

## Archivos a crear o cambiar

| Capa | Archivo | Cambio |
|---|---|---|
| configuración | `pubspec.yaml` | Agregar `firebase_core` y `firebase_messaging`. |
| configuración | `android/settings.gradle.kts`, `android/app/build.gradle.kts` | Agregar y aplicar el plugin `com.google.gms.google-services`. |
| plataforma | `lib/plataforma/capacidades.dart` | Agregar getter `recibeAvisosPush` (true en Android, false en web y resto). |
| data | `lib/data/services/push_service.dart` | Crear `PushService` (abstracta), `PushServiceFirebase`, `PushServiceNinguno` y las funciones `alertaDesdeDatosPush` y `procesarAvisoPush`. |
| ui | `lib/ui/perfil/view_models/perfil_view_model.dart` | Recibir `PushService`; suscribir al activar avisos y desuscribir al apagarlos o cerrar sesión. |
| ui | `lib/ui/principal/widgets/principal_screen.dart` | Pasar `d.push` a `PerfilViewModel`, sincronizar suscripción si los avisos están activos y escuchar `d.push.alertasTocadas` y `d.push.alertaQueAbrioLaApp()`. |
| armado | `lib/dependencias.dart`, `lib/main.dart` | Inyectar `PushService` en `Dependencias` (`simuladas` y `conApi`) e inicializarlo en `main.dart`. |
| backend | `backend/pubspec.yaml` | Agregar `googleapis_auth` y `http`. |
| backend | `backend/lib/src/push_service.dart`, `backend/lib/barrio_seguro_backend.dart` | Crear `PushService` del backend (`PushServiceNinguno`, `PushServiceFcm`) y exportarlo. |
| backend | `backend/lib/src/api.dart`, `backend/bin/servidor.dart`, `backend/README.md` | Inyectar `PushService` en `Api`, enviar push en `POST /alertas` (sin romper el pedido si falla) y configurar `FIREBASE_CREDENTIALS` en `servidor.dart`. |
| pruebas | `test/ayudas/falsos.dart`, `test/unit/notificaciones_test.dart`, `backend/test/api_test.dart` | Agregar `PushFalso` en la app y en el backend; pruebas de filtrado, toque de notificación, suscripción y envío desde el backend. |

## Firmas nuevas

### En la app (`lib/data/services/push_service.dart`)

```dart
abstract class PushService {
  /// Prepara el servicio de mensajería y el callback de segundo plano.
  Future<void> inicializar();

  /// Suscribe el dispositivo al tópico de alertas del barrio.
  Future<void> suscribirAlertas();

  /// Cancela la suscripción al tópico de alertas del barrio.
  Future<void> desuscribirAlertas();

  /// Id de cada alerta cuyo aviso push fue tocado por el vecino.
  Stream<String> get alertasTocadas;

  /// Id de la alerta si un aviso push abrió la app desde cero.
  Future<String?> alertaQueAbrioLaApp();
}

class PushServiceFirebase implements PushService { ... }

class PushServiceNinguno implements PushService {
  const PushServiceNinguno();
  ...
}

/// Convierte el mapa `data` de un mensaje push en una [Alerta], o devuelve
/// null si faltan datos válidos.
Alerta? alertaDesdeDatosPush(Map<String, dynamic> datos);

/// Evalúa un mensaje push recibido en segundo plano: verifica que los avisos
/// estén activos en [preferencias], que la alerta no sea del vecino con
/// sesión abierta y que no esté resuelta. Si corresponde, muestra el aviso
/// con [notificaciones] y devuelve true.
Future<bool> procesarAvisoPush(
  Map<String, dynamic> datos, {
  required Preferencias preferencias,
  required NotificacionesService notificaciones,
});
```

### En `lib/plataforma/capacidades.dart`

```dart
/// Si el dispositivo recibe avisos push con la app cerrada (FCM).
/// Configurado en Android con google-services.json.
bool get recibeAvisosPush {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android;
}
```

### En el backend (`backend/lib/src/push_service.dart`)

```dart
abstract class PushService {
  /// Envía un aviso push con los datos de [alerta] si no está resuelta.
  Future<void> enviarAlerta(Map<String, dynamic> alerta);
}

class PushServiceNinguno implements PushService {
  const PushServiceNinguno();

  @override
  Future<void> enviarAlerta(Map<String, dynamic> alerta) async {}
}

class PushServiceFcm implements PushService {
  PushServiceFcm({
    required this.projectId,
    required http.Client cliente,
  });

  final String projectId;
  ...
}
```

## API y datos

- **Rutas nuevas o cambiadas:**
  - No se agregan rutas HTTP nuevas a la API del barrio.
  - `POST /alertas` en `backend/lib/src/api.dart` mantiene el mismo contrato (`201` con el JSON de la alerta) y, luego de persistir la alerta, invoca a `_push.enviarAlerta(alerta)` dentro de un bloque `try / catch` para que un error de red contra FCM nunca impida reportar una alerta.
- **Formato del mensaje FCM HTTP v1 (`POST https://fcm.googleapis.com/v1/projects/<projectId>/messages:send`):**
  - El backend envía un **mensaje de datos (`data`)** al tópico `alertas` con prioridad alta en Android:
    ```json
    {
      "message": {
        "topic": "alertas",
        "data": {
          "id": "alerta-1",
          "categoria": "sos",
          "tipo": "Pedido de ayuda (SOS)",
          "descripcion": "",
          "direccion": "Calle Plantamura",
          "creada_en": "1759320000000",
          "estado": "activa",
          "latitud": "-32.877264",
          "longitud": "-68.868785",
          "reportada_por": "rosa"
        },
        "android": {
          "priority": "HIGH"
        }
      }
    }
    ```
  - Al llegar como mensaje `data`, Android despierta el callback de segundo plano (`FirebaseMessaging.onBackgroundMessage`), el cual ejecuta `procesarAvisoPush`. Este lee `Preferencias` (con `SharedPreferencesAsync`), descarta la alerta si `reportada_por` coincide con el vecino en sesión (`R6`), si `estado == 'resuelta'` (`R7`) o si los avisos están apagados (`R8`), y muestra la notificación mediante `NotificacionesServiceLocales.avisarAlerta(alerta)` (`R4`).
  - Como la notificación la muestra `NotificacionesServiceLocales` con el payload `alerta:<id>` (y además `PushServiceFirebase` reenvía cualquier apertura directa de FCM con `data['id']`), al tocar la notificación `PrincipalScreen` abre `DetalleAlertaScreen` (`R5`).
- **Cambios en el JSON de los modelos:** Ninguno.
- **Cambios en sqflite:** Ninguno.

## Plataforma

- `Capacidades.recibeAvisosPush` devuelve `true` solo en Android (`defaultTargetPlatform == TargetPlatform.android` y `!kIsWeb`), donde está presente `android/app/google-services.json`. En el resto de las plataformas se inyecta `PushServiceNinguno`.

## Accesibilidad

- No agrega pantallas ni controles nuevos. El interruptor existente `"Avisarme de alertas nuevas"` en `PerfilScreen` conserva sus dimensiones, etiquetas y textos en voseo.

## Paquetes nuevos

Aprobados por el equipo y registrados en `progress/history.md` (entrada `2026-11-25`):

- En `pubspec.yaml`:
  - `firebase_core`
  - `firebase_messaging`
  - Plugin Gradle `com.google.gms.google-services` en `android/settings.gradle.kts` y `android/app/build.gradle.kts`.
- En `backend/pubspec.yaml`:
  - `googleapis_auth`
  - `http`

## Alternativa descartada

**Enviar un payload `notification` estándar de FCM al tópico `alertas` o gestionar una tabla de tokens FCM por vecino en el backend.**
Se descarta porque:
1. Con un payload `notification` estándar al tópico `alertas`, el sistema operativo muestra el aviso directamente sin ejecutar código de la app cuando está cerrada, lo que haría que el vecino que reportó la alerta reciba su propio aviso (incumpliendo R6).
2. Guardar tokens FCM por dispositivo en `Almacen` obligaría a crear endpoints nuevos (`POST /dispositivos`, `DELETE /dispositivos`), manejar rotación y caducidad de tokens para las 40 familias y requerir conexión al servidor para apagar los avisos desde el perfil. Con un mensaje `data` al tópico `alertas`, el backend hace un único envío por alerta y cada teléfono filtra localmente según su sesión y preferencias en `SharedPreferencesAsync`.

## Riesgos y notas

- Si el servidor se ejecuta en desarrollo sin la variable `FIREBASE_CREDENTIALS` (o si el archivo JSON de cuenta de servicio no existe), `bin/servidor.dart` usa `PushServiceNinguno` para que el backend funcione sin configuración extra.
- El callback de `FirebaseMessaging.onBackgroundMessage` debe ser una función de nivel superior (top-level) anotada con `@pragma('vm:entry-point')`.
