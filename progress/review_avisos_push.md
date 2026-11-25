# Review — feature 12 (avisos_push)

**Veredicto:** APPROVED

## Trazabilidad
- R1: [x] `test/unit/notificaciones_test.dart` › `Avisos push con la app cerrada › activar avisos suscribe al push y apagarlos o cerrar sesión desuscribe` y `test/capacidades_politicas_test.dart` › `Avisos de alertas nuevas › activar y apagar los avisos suscribe y desuscribe del push`
- R2: [x] `test/unit/notificaciones_test.dart` › `Avisos push con la app cerrada › activar avisos suscribe al push y apagarlos o cerrar sesión desuscribe`
- R3: [x] `backend/test/api_test.dart` › `Avisos push › crear una alerta activa envía el aviso push con sus datos` y `Avisos push › PushServiceFcm envía el mensaje de datos al tópico alertas y descarta las resueltas`
- R4: [x] `test/unit/notificaciones_test.dart` › `Avisos push con la app cerrada › con la app cerrada, cuando otro vecino crea una alerta, muestra una notificación`
- R5: [x] `test/capacidades_politicas_test.dart` › `Avisos de alertas nuevas › tocar la notificación de un aviso push abre el detalle de esa alerta` y `Avisos de alertas nuevas › si un aviso push abrió la app con la app cerrada, entra al detalle`
- R6: [x] `test/unit/notificaciones_test.dart` › `Avisos push con la app cerrada › el vecino que creó la alerta no recibe su propio aviso`
- R7: [x] `test/unit/notificaciones_test.dart` › `Avisos push con la app cerrada › si la alerta ya está resuelta cuando se va a mostrar el aviso, no se avisa` y `backend/test/api_test.dart` › `Avisos push › si la alerta ya está resuelta cuando se va a enviar el aviso, no se avisa`
- R8: [x] `test/unit/notificaciones_test.dart` › `Avisos push con la app cerrada › sin el permiso de notificaciones o si el push falla la app sigue funcionando igual` y `backend/test/api_test.dart` › `Avisos push › si el servicio de push falla, la alerta se crea igual`

## Tasks
- T1: [x]
- T2: [x]
- T3: [x]
- T4: [x]
- T5: [x]
- T6: [x]
- T7: [x]
- T8: [x]
- T9: [x]
- T10: [x]
- T11: [x]

## Arquitectura y convenciones
- [x] Respeta las capas (`ui` → `data` / servicios inyectados, dominio sin Flutter).
- [x] `PushService` se arma en `lib/dependencias.dart` y llega por constructor a `PerfilViewModel` y `PrincipalScreen`.
- [x] La decisión por plataforma pasa por `Capacidades.recibeAvisosPush` (usa `defaultTargetPlatform` y `kIsWeb`, sin `Platform.isX`).
- [x] Idioma español y convenciones de nombres (`PushService`, `PushServiceFirebase`, `PushServiceNinguno`, `PushFalso`, `PushServiceFcm`).
- [x] Los paquetes nuevos (`firebase_core`, `firebase_messaging`, `googleapis_auth`, `http`) están autorizados en `specs/avisos_push/design.md` y registrados en `progress/history.md`.

## Checkpoints
- C1: [x] El arnés está completo y `./init.sh` termina con código 0.
- C2: [x] Estado coherente, todas las pruebas pasan y `progress/current.md` limpio al cerrar.
- C3: [x] El código respeta la arquitectura y la decisión de paquetes nuevos figura en `progress/history.md`.
- C4: [x] `flutter analyze` y `dart analyze` sin avisos; `flutter test` (156 pruebas) y `dart test` en `backend/` (28 pruebas) en verde, usando falsos y `RelojFijo`.
- C5: [x] Las pruebas de accesibilidad (`test/accesibilidad_test.dart`) pasan en todas las pantallas.
- C6: [x] Sin archivos temporales ni `print`/`debugPrint` de depuración.
- C7: [x] `specs/avisos_push/` completo con EARS estricto, todas las tasks en `[x]` y cada `R<n>` cubierto por pruebas concretas.

## Salida de init.sh
```text
[OK]    flutter analyze sin avisos
[OK]    dart analyze sin avisos en backend/
00:44 +156: All tests passed!
[OK]    Pruebas de la app
00:00 +28: All tests passed!
[OK]    Pruebas del backend
[OK]    Entorno listo. Podés empezar a trabajar.
```

## Cambios requeridos
Ninguno.
