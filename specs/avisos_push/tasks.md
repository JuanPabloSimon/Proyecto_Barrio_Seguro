# Tasks — avisos_push

> Pasos en orden. El `implementer` marca `[x]` al terminar cada uno. Cada
> task dice qué `R<n>` cubre.

## Dominio, plataforma y datos (App)

- [x] T1 — Agregar `firebase_core` y `firebase_messaging` en `pubspec.yaml` y el plugin `com.google.gms.google-services` en `android/settings.gradle.kts` y `android/app/build.gradle.kts`. Cubre: R1, R4.
- [x] T2 — Agregar `recibeAvisosPush` en `lib/plataforma/capacidades.dart` y en `CapacidadesFalsas` (`test/ayudas/falsos.dart`), con su prueba en `test/capacidades_politicas_test.dart`. Cubre: R1, R8.
- [x] T3 — Crear `lib/data/services/push_service.dart` con `PushService`, `PushServiceNinguno`, `PushServiceFirebase`, `alertaDesdeDatosPush` y `procesarAvisoPush`, más `PushFalso` en `test/ayudas/falsos.dart`. Cubre: R1, R2, R4, R5, R6, R7, R8.
- [x] T4 — Pruebas unitarias de `alertaDesdeDatosPush` y `procesarAvisoPush` (avisa alerta de otro vecino, ignora alerta propia, ignora alerta resuelta, ignora si avisos están apagados) en `test/unit/notificaciones_test.dart`. Cubre: R4, R6, R7, R8.

## ViewModel, pantalla principal y armado (App)

- [x] T5 — Inyectar `PushService` en `lib/dependencias.dart`, inicializarlo en `lib/main.dart` y conectarlo en `PerfilViewModel` (`lib/ui/perfil/view_models/perfil_view_model.dart`) y `PrincipalScreen` (`lib/ui/principal/widgets/principal_screen.dart`) para suscribir/desuscribir y abrir `DetalleAlertaScreen` al tocar un aviso push. Cubre: R1, R2, R5, R8.
- [x] T6 — Pruebas de suscripción/desuscripción en `PerfilViewModel`, tolerancia sin permiso y apertura de `DetalleAlertaScreen` al tocar un aviso de `PushFalso` en `test/unit/notificaciones_test.dart`. Cubre: R1, R2, R5, R8.

## Backend

- [x] T7 — Agregar `googleapis_auth` y `http` en `backend/pubspec.yaml` y crear `backend/lib/src/push_service.dart` (`PushService`, `PushServiceNinguno`, `PushServiceFcm`), exportándolo en `backend/lib/barrio_seguro_backend.dart`. Cubre: R3, R7, R8.
- [x] T8 — Integrar `PushService` en `backend/lib/src/api.dart` (envío en `POST /alertas` si la alerta no está resuelta, aislando errores de envío) y configurar la lectura opcional de `FIREBASE_CREDENTIALS` en `backend/bin/servidor.dart` y `backend/README.md`. Cubre: R3, R7, R8.
- [x] T9 — Pruebas en `backend/test/api_test.dart` con servicio de push falso y `MockClient`: envío al crear alerta, no envío si la alerta está resuelta y resiliencia de `POST /alertas` si el push falla. Cubre: R3, R7, R8.

## Cierre

- [x] T10 — Trazabilidad `R<n>` → prueba en `progress/impl_avisos_push.md`.
- [x] T11 — `./init.sh` verde.
