# Review — merge de `origin/develop` en `feature/requiere_conexion`

**Veredicto:** APPROVED

Revisión acotada al merge (sin commitear, `MERGE_HEAD` presente) que trae la
feature 14 `informe_alertas` (aprobada en `progress/review_informe_alertas.md`)
sobre la feature 15 `requiere_conexion` (aprobada en
`progress/review_requiere_conexion.md`). Base común: `bcaa01b`.

## Método

- "Diff de diffs": se comparó `git diff bcaa01b origin/develop` (lo que aportó
  la 14) contra `git diff --cached HEAD` (lo que el merge suma a la rama), y
  `git diff bcaa01b HEAD` (lo que aportó la 15) contra
  `git diff --cached origin/develop` (lo que el merge suma a develop), solo
  líneas `+`/`-`.
- Listado de nombres de `test`/`testWidgets`/`group` en `persistencia_test`,
  `view_models_test`, `widget_test`, `accesibilidad_test`, `dominio_test` y
  `conexion_test`: los del índice contra los de `HEAD` y los de
  `origin/develop`.

## 1. No se perdió nada de la 14

- [x] El aporte de la 14 llega entero. Las únicas diferencias del diff de
  diffs son de forma:
  - `test/unit/persistencia_test.dart`: `import 'dart:io';` no se duplica
    (ya lo tenía la 15).
  - `test/widget_test.dart`: los imports `ayudas/bases_de_prueba.dart` y
    `ayudas/falsos.dart` no se duplican (ya los tenía la 15). El import de
    `dependencias.dart` sigue en `test/widget_test.dart:10`. Cambian el
    comentario de cabecera (ahora unificado) y algunas líneas en blanco.
  - Se agrega `progress/merge_requiere_conexion.md`.
- [x] Están los archivos nuevos de la 14: `lib/data/services/descarga_csv_service.dart`,
  `lib/domain/informe_alertas.dart`, `lib/ui/informe_alertas/**`,
  `specs/informe_alertas/**`, los cambios de `lib/ui/perfil/**`,
  `DescargaCsvFalsa` en `test/ayudas/falsos.dart` y el parámetro
  `descargaCsv` en `test/ayudas/app_de_prueba.dart` y en `lib/dependencias.dart`
  (`simuladas`, `conApi`, `_armar`).
- [x] Ninguna prueba de `origin/develop` falta en el índice.
- [x] R1–R13 de `specs/informe_alertas/` conservan la prueba que cita
  `progress/review_informe_alertas.md`. Se encontraron todas por nombre:
  `dominio_test` › Informe de alertas (R1–R4, R8, R10); `view_models_test` ›
  esComision, carga del informe, falla de la carga, descargarCsv (R5–R7, R9–R11);
  `persistencia_test` › Descarga de CSV (R10); `widget_test` › grupo
  `Informe de alertas para la comisión` (`test/widget_test.dart:376`)
  (R5–R8, R10, R12); `accesibilidad_test` › Informe de alertas (R13).

## 2. No se perdió nada de la 15 ni volvió lo que borró

- [x] El aporte de la 15 llega entero. Diferencias de forma: el lugar de la
  línea borrada `TareasService tareas` dentro del hunk, la cabecera de
  `widget_test`, el import `dependencias.dart` que la 14 sumó y la 15 ya
  tenía, y líneas en blanco.
- [x] Ninguna prueba de `HEAD` falta en el índice. Entre ellas: el grupo
  `Sin conexión` (`test/widget_test.dart:106`), las de Atrás (R25), las
  migraciones v2→v3 y v1→v3 (`test/unit/persistencia_test.dart:483` y `:522`)
  y `un ErrorDelServidor no dispara la comprobación` (`:437`).
  `test/unit/conexion_test.dart` y `test/unit/notificaciones_test.dart` quedan
  igual que en `HEAD`.
- [x] `git grep --cached` de `PendientesDao|TareasService|TareasFalsas|TareasNinguna|enviosDePendientes|estaPendiente|enviarPendientes|correTareasEnSegundoPlano|sqlCrearPendientes|workmanager`
  en `lib/`, `test/`, `backend/`, `pubspec.yaml` y `pubspec.lock`: sin
  resultados.
- [x] R1–R25 de `specs/requiere_conexion/`: sus pruebas siguen presentes
  (mismo conjunto de nombres que en `HEAD`).

## 3. Adaptación: quitar `tareas` de las fábricas de `Dependencias`

- [x] La 14 no usaba `tareas`. En `git diff bcaa01b origin/develop -- lib/dependencias.dart`
  las líneas `tareas` aparecen solo como contexto, y en `origin/develop`
  ningún archivo de la 14 (lib, specs, pruebas) usa `tareas`. Quitarlas
  devuelve lo que ya había hecho la 15 (`lib/dependencias.dart` del índice
  coincide con el de `HEAD`, más `descargaCsv`). Ninguna de las dos specs
  cambia de comportamiento.
- [x] Las pruebas del informe usan `appDePrueba()` sin `conexion`, o sea
  `ConexionServiceSimulado` siempre conectado (`lib/dependencias.dart`,
  `conexion ?? ConexionServiceSimulado()`), y pasan la `CompuertaDeConexion`
  sin cambios.

## 4. Estado

- [x] `feature_list.json`: 14 `informe_alertas` y 15 `requiere_conexion` en
  `done`, 16 `avisos_tardios` en `pending`.
- [x] `progress/history.md`: entradas de la feature 14 (línea 69), de la nota
  de dependencias de la 15 (línea 76) y de la feature 15 (línea 80), en orden.

## 5. Marcadores e init.sh

- [x] Sin marcadores `<<<<<<<` / `=======` / `>>>>>>>` en el índice ni en el
  árbol de trabajo (`lib/`, `test/`, `backend/`, `feature_list.json`,
  `progress/history.md`).
- [x] `./init.sh` termina con exit 0.

## Salida de init.sh

```
[OK]    Specs presentes para las features sdd que ya no están en pending
No issues found! (ran in 3.1s)          # flutter analyze
No issues found!                        # dart analyze backend/
00:24 +225: All tests passed!           # app
00:00 +42: All tests passed!            # backend
[OK]    Pruebas del backend
[OK]    Entorno listo. Podés empezar a trabajar.
```

## Observaciones (no bloquean)

- Falta cerrar el merge con un commit (el informe lo deja abierto a propósito).
- `progress/history.md:73`: el "Próximo" de la entrada de la 14 dice "Todas
  las features (1 a 14) … están en `done`". Era cierto cuando se escribió y la
  entrada de la 15 lo actualiza después. Queda como registro histórico.

## Cambios requeridos

Ninguno.
