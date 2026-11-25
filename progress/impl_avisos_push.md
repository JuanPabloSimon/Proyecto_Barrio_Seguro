# Implementación — feature 12 (`avisos_push`)

## Archivos creados o modificados

- `pubspec.yaml` y `pubspec.lock`: agregados `firebase_core` y `firebase_messaging`.
- `android/settings.gradle.kts` y `android/app/build.gradle.kts`: agregado el plugin `com.google.gms.google-services`.
- `lib/plataforma/capacidades.dart`: agregado `recibeAvisosPush`.
- `lib/data/services/push_service.dart`: creados `PushService`, `PushServiceFirebase`, `PushServiceNinguno`, `alertaDesdeDatosPush`, `procesarAvisoPush` y `manejarMensajePushEnSegundoPlano`.
- `lib/dependencias.dart` y `lib/main.dart`: inyección e inicialización de `PushService`.
- `lib/ui/perfil/view_models/perfil_view_model.dart`: suscripción y desuscripción al tópico de alertas push al activar/desactivar avisos o cerrar sesión.
- `lib/ui/principal/widgets/principal_screen.dart`: sincronización de suscripción push y apertura de `DetalleAlertaScreen` al tocar un aviso push.
- `backend/pubspec.yaml` y `backend/pubspec.lock`: agregados `googleapis_auth` y `http`.
- `backend/lib/src/push_service.dart` y `backend/lib/barrio_seguro_backend.dart`: creados y exportados `PushService`, `PushServiceNinguno` y `PushServiceFcm`.
- `backend/lib/src/api.dart`, `backend/bin/servidor.dart` y `backend/README.md`: envío de aviso push en `POST /alertas` y lectura opcional de `FIREBASE_CREDENTIALS`.
- `test/ayudas/falsos.dart`, `test/ayudas/app_de_prueba.dart`, `test/unit/plataforma_test.dart`, `test/capacidades_politicas_test.dart`, `test/unit/notificaciones_test.dart` y `backend/test/api_test.dart`: servicio `PushFalso` y pruebas de todos los requisitos.

## Trazabilidad

| Requisito | Prueba |
|---|---|
| R1 | `test/unit/notificaciones_test.dart` › `Avisos push con la app cerrada › activar avisos suscribe al push y apagarlos o cerrar sesión desuscribe` y `test/capacidades_politicas_test.dart` › `Avisos de alertas nuevas › activar y apagar los avisos suscribe y desuscribe del push` |
| R2 | `test/unit/notificaciones_test.dart` › `Avisos push con la app cerrada › activar avisos suscribe al push y apagarlos o cerrar sesión desuscribe` |
| R3 | `backend/test/api_test.dart` › `Avisos push › crear una alerta activa envía el aviso push con sus datos` y `Avisos push › PushServiceFcm envía el mensaje de datos al tópico alertas y descarta las resueltas` |
| R4 | `test/unit/notificaciones_test.dart` › `Avisos push con la app cerrada › con la app cerrada, cuando otro vecino crea una alerta, muestra una notificación` |
| R5 | `test/capacidades_politicas_test.dart` › `Avisos de alertas nuevas › tocar la notificación de un aviso push abre el detalle de esa alerta` y `Avisos de alertas nuevas › si un aviso push abrió la app con la app cerrada, entra al detalle` |
| R6 | `test/unit/notificaciones_test.dart` › `Avisos push con la app cerrada › el vecino que creó la alerta no recibe su propio aviso` |
| R7 | `test/unit/notificaciones_test.dart` › `Avisos push con la app cerrada › si la alerta ya está resuelta cuando se va a mostrar el aviso, no se avisa` y `backend/test/api_test.dart` › `Avisos push › si la alerta ya está resuelta cuando se va a enviar el aviso, no se avisa` |
| R8 | `test/unit/notificaciones_test.dart` › `Avisos push con la app cerrada › sin el permiso de notificaciones o si el push falla la app sigue funcionando igual` y `backend/test/api_test.dart` › `Avisos push › si el servicio de push falla, la alerta se crea igual` |

## Salida de `./init.sh`

```text
[OK]    feature_list.json válido (14 features)
[OK]    Specs presentes para las features sdd que ya no están en pending
[OK]    flutter pub get
[OK]    dart pub get en backend/
[OK]    flutter analyze sin avisos
[OK]    dart analyze sin avisos en backend/
00:44 +156: All tests passed!
[OK]    Pruebas de la app
00:00 +28: All tests passed!
[OK]    Pruebas del backend
[OK]    Entorno listo. Podés empezar a trabajar.
```
