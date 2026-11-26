# Review — feature 14 (informe_alertas)

**Veredicto:** APPROVED

## Trazabilidad
- R1: [x] `test/unit/dominio_test.dart` › `Informe de alertas › incluye solo las alertas del mes y año elegidos`
- R2: [x] `test/unit/dominio_test.dart` › `Informe de alertas › agrupa y ordena por calle y por tipo de mayor a menor y alfabéticamente`
- R3: [x] `test/unit/dominio_test.dart` › `Informe de alertas › agrupa y ordena por calle y por tipo de mayor a menor y alfabéticamente`
- R4: [x] `test/unit/dominio_test.dart` › `Informe de alertas › agrupa por franja horaria según la hora de creación`
- R5: [x] `test/unit/view_models_test.dart` › `InformeAlertasViewModel y rol en PerfilViewModel › PerfilViewModel.esComision distingue comisión de vecino común` y `test/widget_test.dart` › `Informe de alertas para la comisión › un miembro de la comisión ve la opción, consulta el informe, descarga el CSV y ve el aviso en un mes sin alertas`
- R6: [x] `test/unit/view_models_test.dart` › `InformeAlertasViewModel y rol en PerfilViewModel › PerfilViewModel.esComision distingue comisión de vecino común` y `test/widget_test.dart` › `Informe de alertas para la comisión › para un vecino común la opción del informe no aparece en el perfil`
- R7: [x] `test/unit/view_models_test.dart` › `InformeAlertasViewModel y rol en PerfilViewModel › carga el informe del mes actual, cambia de mes y reacciona al bus` y `test/widget_test.dart` › `Informe de alertas para la comisión › un miembro de la comisión ve la opción, consulta el informe, descarga el CSV y ve el aviso en un mes sin alertas`
- R8: [x] `test/unit/dominio_test.dart` › `Informe de alertas › sin alertas en el mes devuelve sinAlertas en true y tablas vacías` y `test/widget_test.dart` › `Informe de alertas para la comisión › un miembro de la comisión ve la opción, consulta el informe, descarga el CSV y ve el aviso en un mes sin alertas`
- R9: [x] `test/unit/view_models_test.dart` › `InformeAlertasViewModel y rol en PerfilViewModel › si falla la carga pasa al estado de error`
- R10: [x] `test/unit/dominio_test.dart` › `Informe de alertas › toCsv y nombreArchivoCsv exportan el informe y escapan comas`, `test/unit/persistencia_test.dart` › `Descarga de CSV › DescargaCsvServiceLocal guarda el archivo CSV en disco`, `test/unit/view_models_test.dart` › `InformeAlertasViewModel y rol en PerfilViewModel › descargarCsv guarda el CSV del mes y avisa si falla` y `test/widget_test.dart` › `Informe de alertas para la comisión › un miembro de la comisión ve la opción, consulta el informe, descarga el CSV y ve el aviso en un mes sin alertas`
- R11: [x] `test/unit/view_models_test.dart` › `InformeAlertasViewModel y rol en PerfilViewModel › descargarCsv guarda el CSV del mes y avisa si falla`
- R12: [x] `test/widget_test.dart` › `Informe de alertas para la comisión › un miembro de la comisión ve la opción, consulta el informe, descarga el CSV y ve el aviso en un mes sin alertas`
- R13: [x] `test/accesibilidad_test.dart` › `Guías de accesibilidad › Informe de alertas` y `Texto del sistema al 200 % › Informe de alertas`

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

## Arquitectura y convenciones
- [x] `lib/domain/informe_alertas.dart` es puro Dart (sin importar Flutter).
- [x] `InformeAlertasViewModel` no recibe `BuildContext` ni importa widgets, y cancela su suscripción al `BusDeEventos` en `dispose`.
- [x] `DescargaCsvService` es una clase abstracta armada en `lib/dependencias.dart` e inyectada por constructor (`DescargaCsvServiceLocal` en producción y `DescargaCsvFalsa` en pruebas).
- [x] `InformeAlertasScreen` se estructura con `ConViewModel`, `ListenableBuilder` y clases `StatelessWidget` privadas (sin métodos `_buildX()`).
- [x] Textos en español y voseo. Sin paquetes nuevos.

## Checkpoints
- C1: [x] El arnés está completo y `./init.sh` termina con código 0.
- C2: [x] Estado coherente, todas las features en `done` con pruebas que pasan y `progress/current.md` limpio al cerrar.
- C3: [x] El código respeta la arquitectura y no agrega paquetes nuevos.
- C4: [x] `flutter analyze` y `dart analyze` sin avisos; `flutter test` (192 pruebas) y `dart test` en `backend/` (42 pruebas) en verde.
- C5: [x] Accesibilidad verificada en `test/accesibilidad_test.dart` para `Informe de alertas` (48 dp, etiquetas, contraste y texto al 200 %).
- C6: [x] Sin archivos temporales ni `print`/`debugPrint` de depuración.
- C7: [x] `specs/informe_alertas/` completo en EARS estricto, todas las tasks en `[x]` y cada `R1..R13` cubierto por pruebas concretas.

## Salida de init.sh
```text
[OK]    flutter analyze sin avisos
[OK]    dart analyze sin avisos en backend/
00:28 +192: All tests passed!
[OK]    Pruebas de la app
00:00 +42: All tests passed!
[OK]    Pruebas del backend
[OK]    Entorno listo. Podés empezar a trabajar.
```

## Cambios requeridos
Ninguno.
