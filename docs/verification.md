# Verificación — Cómo demostrar que funciona

> Regla de oro: **no se dice "funciona", se demuestra.** Toda feature
> termina con evidencia ejecutable.

## Nivel 1 — Analizador (obligatorio)

```bash
flutter analyze
cd backend && dart analyze
```

Cero avisos. Un aviso nuevo es un error.

## Nivel 2 — Pruebas unitarias (obligatorio)

Van en `test/unit/`, agrupadas por capa (`dominio_test.dart`,
`repositorios_test.dart`, `view_models_test.dart`, `servicios_http_test.dart`,
`persistencia_test.dart`, …).

- **Dominio y reglas:** funciones puras, sin falsos.
- **ViewModels:** con los repositorios y servicios falsos de
  `test/ayudas/falsos.dart` y `RelojFijo`. Se verifica el estado
  (`cargando` → `exito` / `error`) y lo que expone, no la implementación.
- **Servicios HTTP:** con `MockClient` de `package:http`: ruta, encabezado
  `Authorization`, JSON y traducción de errores.
- **Persistencia:** SQLite real en memoria (`sqflite_common_ffi`) y
  preferencias en memoria (`InMemorySharedPreferencesAsync`). "Cerrar y abrir
  la app" = crear objetos nuevos sobre el mismo almacenamiento.

Cada prueba cubre el camino feliz y al menos un camino de error.

## Nivel 3 — Pruebas de widgets y accesibilidad (obligatorio si hay pantalla)

- La app completa con `appDePrueba()` de `test/ayudas/app_de_prueba.dart`
  (servidor simulado, sin demoras, sin internet, capacidades falsas).
- Buscar por **texto visible**, no por `.first` ni por tipo.
- Desplazar la lista hasta el elemento antes de tocarlo.
- En `test/accesibilidad_test.dart`, por cada pantalla nueva:
  `androidTapTargetGuideline`, `iOSTapTargetGuideline`,
  `labeledTapTargetGuideline`, `textContrastGuideline` y texto al 200 %.

## Nivel 4 — Pruebas del backend (obligatorio si toca `backend/`)

```bash
cd backend && dart test
```

Contra el handler, sin abrir un puerto. Si cambia una regla de turnos, hay
prueba en `backend/test/reglas_test.dart` **y** en la app.

## Nivel 5 — Trazabilidad (obligatorio para `"sdd": true`)

Cada `R<n>` de `specs/<name>/requirements.md` tiene al menos una prueba.
El mapa va en `progress/impl_<name>.md` (ver `docs/specs.md`).

## Nivel 6 — Prueba manual (recomendada antes de cerrar)

En el emulador, primero con el servidor simulado y después con la API:

```bash
flutter run
# en otra terminal:
cd backend && dart run bin/servidor.dart
flutter run --dart-define=API_URL=http://10.0.2.2:8080
```

Cuentas de prueba en `backend/README.md`. Anotá en `progress/impl_<name>.md`
qué recorriste.

## Antipatrones

- ❌ "Agregué la pantalla, debería andar." → falta prueba.
- ❌ Una prueba que solo verifica que no se lanza una excepción.
- ❌ Pruebas que dependen de la hora real o de internet.
- ❌ `find.byType(...).first` cuando hay un texto para buscar.
- ❌ Marcar `done` sin `./init.sh` verde.

## Antes de cerrar

```bash
./init.sh     # tiene que terminar con "[OK] Entorno listo"
```

Si está en rojo, **no** se marca nada como `done`: se anota el bloqueo en
`progress/current.md` y la feature pasa a `blocked`.
