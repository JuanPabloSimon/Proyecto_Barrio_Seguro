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
