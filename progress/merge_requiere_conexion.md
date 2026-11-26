# Merge de `origin/develop` en `feature/requiere_conexion`

- **Fecha:** 2026-11-25
- **Qué:** `git merge origin/develop` (trae la feature 14 `informe_alertas`, PR #26) sobre la rama de la feature 15 `requiere_conexion`.
- **Estado:** conflictos resueltos y agregados con `git add`. **Sin commit** (el merge queda abierto para que lo cierre el equipo).

## Archivos en conflicto y cómo se resolvió cada uno

| Archivo | Resolución |
|---|---|
| `feature_list.json` | Se dejó la versión de la rama (entradas 15 y 16) y se puso la 14 en `"done"`. Quedan 14 y 15 en `done`, 16 `avisos_tardios` en `pending`. JSON válido (lo comprueba también `init.sh`). |
| `lib/dependencias.dart` | Se conservaron las dos cosas: `import conexion_service.dart` + `import descarga_csv_service.dart`; `ConexionService? conexion` y `DescargaCsvService descargaCsv` en `Dependencias.simuladas`; `descargaCsv` en `Dependencias.conApi` y en `_armar`. Se descartaron `TareasService tareas = const TareasNinguna()` y `tareas: tareas` que traía develop (la 15 borró `TareasService`). |
| `progress/history.md` | Las dos entradas, en orden cronológico: primero la feature 14 (entró antes a `develop`), después la nota de dependencias y la entrada de la feature 15. Texto de cada una sin cambios. |
| `test/ayudas/app_de_prueba.dart` | Imports de `conexion_service.dart` y `descarga_csv_service.dart`; parámetros `ConexionService? conexion` y `DescargaCsvService? descargaCsv`; se pasan los dos a `Dependencias.simuladas` (`descargaCsv ?? DescargaCsvFalsa()`). |
| `test/ayudas/falsos.dart` | Imports de los dos lados; se conservan `ConexionFalsa`, `ConexionRepositoryFalsa`, `AlertasDaoEnMemoria`, `TurnosDaoEnMemoria` (15) y se agrega `DescargaCsvFalsa` (14) a continuación. |
| `test/unit/persistencia_test.dart` | Imports de `error_del_servidor.dart` (15) y `descarga_csv_service.dart` (14); se conserva el grupo `Sin envío diferido` y la migración de la 15, y se agrega el grupo `Descarga de CSV` de la 14 al final. |
| `test/widget_test.dart` | Base: la versión de la 15 completa (SOS sin red, grupo `Sin conexión`, helpers `tituloSinConexion`, `esperarComprobacion`, `ingresar`). Se agregaron de la 14: los imports de `con_view_model.dart`, `perfil_view_model.dart`, `perfil_screen.dart`, el helper `_tocar` y el grupo `Informe de alertas para la comisión` completo al final de `main`. Comentario de cabecera unificado. |

Archivos que git mezcló solo (sin conflicto): `test/accesibilidad_test.dart`, `test/unit/view_models_test.dart`, `test/unit/dominio_test.dart`, `lib/ui/perfil/...` y los archivos nuevos de la 14 (`lib/domain/informe_alertas.dart`, `lib/data/services/descarga_csv_service.dart`, `lib/ui/informe_alertas/...`, `specs/informe_alertas/`, `progress/impl_informe_alertas.md`, `progress/review_informe_alertas.md`).

## Adaptaciones

- La única dependencia de la 14 sobre lo que borró la 15 era el parámetro `tareas` (`TareasService`/`TareasNinguna`) en las fábricas de `Dependencias`, que develop arrastraba de la feature 10. Se quitó; la 14 no lo usaba para nada propio. Ningún comportamiento de `specs/informe_alertas/` ni de `specs/requiere_conexion/` cambió.
- Las pruebas del informe usan `appDePrueba()` sin `conexion`, o sea `ConexionServiceSimulado` siempre conectado: pasan por la `CompuertaDeConexion` sin cambios.

## Verificaciones

- Marcadores `<<<<<<<` / `=======` / `>>>>>>>`: ninguno en `lib/`, `test/`, `feature_list.json` ni `progress/history.md`.
- `grep` de `PendientesDao|TareasService|TareasFalsas|TareasNinguna|enviosDePendientes|estaPendiente|enviarPendientes|correTareasEnSegundoPlano|sqlCrearPendientes|workmanager` en `lib/`, `test/` y `pubspec.yaml`: sin resultados.
- `dart format` sobre los 5 archivos Dart tocados: 0 cambios.

## Salida resumida de `./init.sh` (exit 0)

```
[OK] feature_list.json válido (16 features)
[OK] Specs presentes para las features sdd que ya no están en pending
[OK] flutter pub get / dart pub get en backend/
[OK] flutter analyze sin avisos            (No issues found!)
[OK] dart analyze sin avisos en backend/   (No issues found!)
[OK] Pruebas de la app                     (+225: All tests passed!)
[OK] Pruebas del backend                   (+42: All tests passed!)
[OK] Entorno listo. Podés empezar a trabajar.
```

225 pruebas en la app = las 211 de la 15 + las que trajo la 14. Se confirmó con `-r expanded` que corren tanto `Informe de alertas para la comisión` (widget_test) y `Descarga de CSV` (persistencia_test) como `Sin conexión` y `Sin envío diferido`.
