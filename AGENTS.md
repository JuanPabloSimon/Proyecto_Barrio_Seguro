# AGENTS.md — Mapa del repositorio para agentes de IA

> Punto de entrada para cualquier agente (o persona) que trabaje en Barrio
> Seguro. No es un reglamento: es un **mapa**. Leé solo lo que necesites,
> cuando lo necesites.

---

## 1. Antes de empezar (obligatorio)

1. Ejecutá `./init.sh` y verificá que termina verde. Si falla, **pará** y
   resolvé el entorno antes de tocar código.
2. Leé `progress/current.md` para saber en qué quedó la última sesión.
3. Leé `feature_list.json`. Toda feature con `"sdd": true` pasa por
   **Spec Driven Development**: ver `docs/specs.md` y la §4 de este archivo.

## 2. Mapa del repositorio

| Archivo / carpeta | Qué contiene | Cuándo leerlo |
|---|---|---|
| `feature_list.json` | Features con su estado (`pending` / `spec_ready` / `in_progress` / `done` / `blocked`) | Siempre, al empezar |
| `progress/current.md` | Estado vivo de la sesión actual | Siempre, al empezar |
| `progress/history.md` | Bitácora de sesiones anteriores (solo se agrega al final) | Si necesitás contexto |
| `specs/<feature>/` | `requirements.md` + `design.md` + `tasks.md` | Antes de implementar una feature `sdd` |
| `specs/_plantilla/` | Plantillas de los tres archivos del spec | Al redactar un spec |
| `docs/architecture.md` | Capas, reglas de dependencias, qué es "buen trabajo" acá | Antes de implementar |
| `docs/conventions.md` | Nombres, estilo, textos de la UI, git | Antes de escribir código |
| `docs/specs.md` | Proceso SDD: EARS, los 3 archivos, aprobación humana | Antes de redactar o leer un spec |
| `docs/verification.md` | Cómo demostrar que algo funciona (tests, trazabilidad) | Antes de cerrar una feature |
| `CHECKPOINTS.md` | Criterios objetivos de "estado final correcto" | Para autoevaluarte |
| `.claude/agents/` | `leader`, `spec_author`, `implementer`, `reviewer` | Si orquestás trabajo |
| `lib/` | App Flutter (MVVM en capas) | Para implementar |
| `test/` | Pruebas de la app (unitarias, de widgets y de accesibilidad) | Para verificar |
| `backend/` | API REST en Dart (shelf), proyecto aparte con sus pruebas | Si la feature toca el servidor |
| `tool/validar_harness.dart` | Valida `feature_list.json` y los specs (lo llama `init.sh`) | Si `init.sh` falla en el paso 3 |

## 3. Reglas duras (no negociables)

- **Una sola feature a la vez.** Como máximo una en `in_progress`.
- **Nada es `done` sin `./init.sh` verde**: analizador sin avisos y todas las
  pruebas de la app y del backend pasando.
- **No se saltea el spec.** Toda feature `"sdd": true` pasa por `spec_author`
  y por la aprobación humana antes de tocar `lib/`, `test/` o `backend/`.
- **No se saltea la puerta humana.** El leader se detiene en `spec_ready`.
- **Sin dependencias nuevas sin discutirlo.** Si una feature necesita un
  paquete nuevo en `pubspec.yaml`, se marca `blocked` y se consulta al equipo.
- **Documentá mientras trabajás** en `progress/current.md`, no al final.
- **Si no sabés algo, buscalo en `docs/`** antes de inventarlo.

## 4. Flujo de trabajo (SDD)

```
pending → [spec_author] → spec_ready → ⏸ HUMANO → in_progress → [implementer → reviewer] → done
```

1. El leader toma la primera feature `pending` con `"sdd": true`.
2. Lanza `spec_author`, que escribe `specs/<name>/{requirements,design,tasks}.md`
   y deja la feature en `spec_ready`.
3. **Pausa.** Una persona del equipo lee el spec y dice "aprobado" o pide cambios.
4. El leader pasa la feature a `in_progress` y lanza `implementer`.
5. El implementer ejecuta `tasks.md` una por una, marcándolas `[x]`.
6. El reviewer verifica trazabilidad `R<n>` ↔ test, tasks completas y
   `CHECKPOINTS.md`. Aprueba o rechaza.
7. Si aprueba, el implementer marca `done` y pasa el resumen a
   `progress/history.md`.

## 5. Cierre de sesión

1. `./init.sh` verde.
2. Si la feature terminó: `status: "done"` en `feature_list.json`.
3. Resumen de `progress/current.md` → al final de `progress/history.md`.
4. `progress/current.md` vuelve a la plantilla.
5. Sin archivos temporales, sin `print`/`debugPrint` de depuración, sin TODO
   sin contexto.

## 6. Si te bloqueás

- Releé la sección de `docs/` que corresponda.
- Si una herramienta no hace lo esperado, **no inventes un atajo**: anotá el
  bloqueo en `progress/current.md`, marcá la feature `blocked` y cortá.
