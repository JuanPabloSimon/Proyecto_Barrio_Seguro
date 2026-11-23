# CHECKPOINTS — Evaluación del estado final

> No se evalúa el camino, se evalúa el destino. Son los criterios objetivos
> con los que una persona o el `reviewer` deciden si el proyecto está sano.

## C1 — El arnés está completo

- [ ] Existen `AGENTS.md`, `CLAUDE.md`, `init.sh`, `feature_list.json`,
      `progress/current.md` y `progress/history.md`.
- [ ] Existen `docs/architecture.md`, `docs/conventions.md`, `docs/specs.md`
      y `docs/verification.md`.
- [ ] `./init.sh` termina con código de salida 0.

## C2 — El estado es coherente

- [ ] Como mucho una feature en `in_progress`.
- [ ] Toda feature `done` tiene pruebas que pasan.
- [ ] `progress/current.md` está en plantilla o describe la sesión activa
      (sin restos de sesiones anteriores).

## C3 — El código respeta la arquitectura

- [ ] Las dependencias entre capas siguen `docs/architecture.md`
      (UI → repositorios → servicios; el dominio no importa Flutter).
- [ ] Ningún ViewModel recibe `BuildContext` ni importa widgets.
- [ ] Toda pieza nueva se arma en `lib/dependencias.dart` y llega por
      constructor (nada de instancias globales).
- [ ] Las decisiones por plataforma pasan por `Capacidades` o `Politicas`
      (sin `Platform.isX` sueltos en pantallas).
- [ ] No hay paquetes nuevos en `pubspec.yaml` ni en `backend/pubspec.yaml`
      sin una decisión anotada en `progress/history.md`.
- [ ] Si cambió una regla de turnos, cambió en la app **y** en el backend.

## C4 — La verificación es real

- [ ] `flutter analyze` sin avisos.
- [ ] `flutter test` y `cd backend && dart test` en verde.
- [ ] Cada ViewModel o repositorio nuevo tiene pruebas con los falsos de
      `test/ayudas/falsos.dart`; cada pantalla nueva, prueba de widgets y de
      accesibilidad.
- [ ] Las pruebas no dependen de la hora real (usan `RelojFijo`) ni de
      internet.

## C5 — Accesibilidad (la usan personas mayores)

- [ ] Todo elemento tocable mide al menos 48 x 48 dp.
- [ ] Todo ícono o botón sin texto tiene etiqueta para lector de pantalla.
- [ ] La pantalla nueva se ve bien con el texto al 200 %.
- [ ] El estado no se comunica solo con color.

## C6 — La sesión se cerró bien

- [ ] Sin archivos temporales ni `print`/`debugPrint` de depuración.
- [ ] `progress/history.md` tiene una entrada por la última sesión.
- [ ] La última feature trabajada está en su estado correcto.

## C7 — Spec Driven Development

- [ ] Toda feature `"sdd": true` en `spec_ready`, `in_progress` o `done`
      tiene `specs/<name>/` con `requirements.md`, `design.md` y `tasks.md`.
- [ ] `requirements.md` usa EARS estricto (ver `docs/specs.md`).
- [ ] Toda feature `done` con `"sdd": true` tiene todas sus tasks en `[x]`.
- [ ] Cada `R<n>` está cubierto por al menos una prueba concreta.

---

**Cómo se usa:** el `reviewer` recorre cada casilla, marca `[x]` o `[ ]` en
su informe y rechaza el cierre si queda alguna vacía en C1 a C7.
