# Spec Driven Development (SDD)

> Flujo estilo Kiro: requirements → design → tasks → código. No se escribe
> código hasta que una persona del equipo aprueba el spec.

## Estructura

Cada feature con `"sdd": true` tiene su carpeta en cuanto deja `pending`:

```
specs/<name>/
├── requirements.md   QUÉ tiene que pasar (EARS)
├── design.md         CÓMO se va a construir (decisiones técnicas)
└── tasks.md          PASOS concretos, en orden
```

`<name>` es el campo `name` de `feature_list.json`. Hay plantillas en
`specs/_plantilla/`.

## Estados

| Estado | Significado |
|---|---|
| `pending` | Sin spec. Le toca al `spec_author`. |
| `spec_ready` | Spec escrito, esperando aprobación humana. No se toca código. |
| `in_progress` | Spec aprobado. El `implementer` trabaja. |
| `done` | Pruebas verdes, `reviewer` aprobó, sesión cerrada. |
| `blocked` | Trabada. El motivo está en `progress/current.md` o `progress/spec_<name>.md`. |

## La puerta de aprobación humana

El flujo se detiene **una vez**: cuando el `spec_author` termina, la feature
queda en `spec_ready` y el leader para. Una persona del equipo lee
`specs/<name>/` y responde "aprobado" o pide cambios. Recién ahí el leader
pasa la feature a `in_progress`.

```
pending → [spec_author] → spec_ready → ⏸ HUMANO → in_progress → [implementer → reviewer] → done
```

Quién aprueba: quien abrió la sesión, después de mirarlo con quien tenga el
rol relacionado (Leandro para requisitos del cliente, Carla si toca
pantallas, Juan Pablo si toca pruebas). Para que el resto lo vea, el spec se
commitea en la rama `feature/<name>` y se abre un PR en borrador.

## requirements.md — EARS estricto

Cada requisito es un párrafo numerado con uno de estos cinco patrones:

| Patrón | Plantilla |
|---|---|
| Ubicuo | `El sistema DEBE <acción>.` |
| Evento | `CUANDO <disparador>, el sistema DEBE <acción>.` |
| Estado | `MIENTRAS <estado>, el sistema DEBE <acción>.` |
| Opcional | `DONDE <capacidad o condición de plataforma>, el sistema DEBE <acción>.` |
| No deseado | `SI <evento no deseado> ENTONCES el sistema DEBE <acción>.` |

Reglas duras:

- Id estable: `R1`, `R2`, … No se renumera al editar.
- Un solo `DEBE` (o `NO DEBE`) por requisito. Si hay dos, se parte.
- Nada de "podría", "puede", "soporta", "rápido", "amigable".
- Cada requisito se puede verificar con una prueba concreta.
- Al final, una tabla que muestre qué `R<n>` cubre cada criterio del
  `acceptance` de `feature_list.json`.

Ejemplos con este proyecto:

```markdown
## R1
CUANDO un vecino toca "Anotarme" en un turno con lugar libre, el sistema
DEBE agregarlo como patrullero de ese turno.

## R2
SI el vecino ya tiene 2 turnos en el mes ENTONCES el sistema DEBE mostrar
el mensaje "Ya tenés 2 turnos este mes, que es el máximo permitido." y no
anotarlo.

## R3
DONDE el dispositivo no puede hacer llamadas, el sistema DEBE indicar que
se llame al 911 desde otro teléfono.

## R4
MIENTRAS no hay conexión, el sistema DEBE mostrar los turnos guardados con
el aviso "Sin conexión".
```

## design.md — decisiones técnicas

Se escribe **antes** del código y responde:

- Qué archivos se crean o cambian, en qué capa (`lib/`, `test/`, `backend/`).
- Qué clases, métodos y rutas de la API aparecen, con su firma.
- Cómo se arma en `lib/dependencias.dart` (simulado y con API).
- Qué cambia en el JSON de la API, si cambia, y en la copia local (sqflite).
- Qué dice `Capacidades` o `Politicas`, si la feature depende de la plataforma.
- Cómo cumple las reglas de accesibilidad, si tiene pantalla.
- Paquetes nuevos: ninguno, o la decisión del equipo que los autorizó.
- Al menos **una alternativa descartada** y por qué.

No reinventa la arquitectura: se apoya en `docs/architecture.md` y anota
solo los puntos donde la feature roza sus límites.

## tasks.md — checklist ejecutable

Pasos chicos, en orden, cada uno con `[ ]` y los `R<n>` que cubre. Primero
dominio y datos, después ViewModel, después pantalla; cada paso con su
prueba.

```markdown
- [ ] T1 — Agregar `rol` a `Vecino` (fromJson/toJson) en `lib/domain/models/vecino.dart`. Cubre: R1.
- [ ] T2 — Prueba `rol viaja en el JSON` en `test/unit/dominio_test.dart`. Cubre: R1.
- [ ] T3 — Validar el rol en `PUT /vecinos/<id>` en `backend/lib/src/api.dart`. Cubre: R3.
- [ ] T4 — Prueba `un vecino no puede cambiarse el rol` en `backend/test/api_test.dart`. Cubre: R3.
```

El `implementer` marca `[x]` al terminar cada una. El `reviewer` rechaza si
queda alguna `[ ]` sin justificación.

## Trazabilidad (regla dura)

- Cada `R<n>` tiene al menos una prueba concreta.
- El `implementer` deja el mapa en `progress/impl_<name>.md`:

```markdown
## Trazabilidad
| Requisito | Prueba |
|---|---|
| R1 | `test/unit/dominio_test.dart` › rol viaja en el JSON |
| R3 | `backend/test/api_test.dart` › un vecino no puede cambiarse el rol |
```

- El `reviewer` lo comprueba y rechaza si falta alguno.

## Cuándo NO aplica

Las features 1 a 11 (`"sdd"` ausente) se hicieron antes de adoptar SDD y no
tienen spec. SDD se aplica de acá en adelante. Un arreglo chico que no es
una feature (un texto, un color) no necesita spec, pero sí `./init.sh` verde.
