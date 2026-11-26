# Implementación — feature 14 (`informe_alertas`)

## Archivos creados o modificados

- `lib/domain/informe_alertas.dart`: creados `FranjaInforme`, `FilaInforme` e `InformeAlertas` (`InformeAlertas.delMes`, `sinAlertas`, `nombreArchivoCsv` y `toCsv`).
- `lib/data/services/descarga_csv_service.dart`: creados `DescargaCsvService` y `DescargaCsvServiceLocal` (guardado con BOM UTF-8).
- `lib/dependencias.dart`: inyectado `DescargaCsvService descargaCsv` en `Dependencias`, `Dependencias.simuladas` y `Dependencias.conApi`.
- `lib/ui/perfil/view_models/perfil_view_model.dart`: agregado getter `esComision`.
- `lib/ui/perfil/widgets/perfil_screen.dart`: entrada `"Informe mensual de alertas"` visible solo cuando `viewModel.esComision` es `true`, con navegación a `InformeAlertasScreen`.
- `lib/ui/informe_alertas/view_models/informe_alertas_view_model.dart`: creado `InformeAlertasViewModel` (`cargar`, `elegirMes`, `mesAnterior`, `mesSiguiente`, `descargarCsv`, suscripción a `AlertasActualizadas` y `dispose`).
- `lib/ui/informe_alertas/widgets/informe_alertas_screen.dart`: creada `InformeAlertasScreen` y sus clases `StatelessWidget` privadas (`_ContenidoInforme`, `_SelectorMesInforme`, `_InformeVacio`, `_ResumenTotalMes`, `_TablaInforme`, `_FilaTablaInforme`).
- `test/ayudas/falsos.dart` y `test/ayudas/app_de_prueba.dart`: agregado `DescargaCsvFalsa` e inyección en `appDePrueba`.
- `test/unit/dominio_test.dart`, `test/unit/persistencia_test.dart`, `test/unit/view_models_test.dart`, `test/widget_test.dart` y `test/accesibilidad_test.dart`: pruebas unitarias, de widgets y de accesibilidad.

## Trazabilidad

| Requisito | Prueba |
|---|---|
| R1 | `test/unit/dominio_test.dart` › `Informe de alertas › incluye solo las alertas del mes y año elegidos` |
| R2 | `test/unit/dominio_test.dart` › `Informe de alertas › agrupa y ordena por calle y por tipo de mayor a menor y alfabéticamente` |
| R3 | `test/unit/dominio_test.dart` › `Informe de alertas › agrupa y ordena por calle y por tipo de mayor a menor y alfabéticamente` |
| R4 | `test/unit/dominio_test.dart` › `Informe de alertas › agrupa por franja horaria según la hora de creación` |
| R5 | `test/unit/view_models_test.dart` › `InformeAlertasViewModel y rol en PerfilViewModel › PerfilViewModel.esComision distingue comisión de vecino común` y `test/widget_test.dart` › `Informe de alertas para la comisión › un miembro de la comisión ve la opción, consulta el informe, descarga el CSV y ve el aviso en un mes sin alertas` |
| R6 | `test/unit/view_models_test.dart` › `InformeAlertasViewModel y rol en PerfilViewModel › PerfilViewModel.esComision distingue comisión de vecino común` y `test/widget_test.dart` › `Informe de alertas para la comisión › para un vecino común la opción del informe no aparece en el perfil` |
| R7 | `test/unit/view_models_test.dart` › `InformeAlertasViewModel y rol en PerfilViewModel › carga el informe del mes actual, cambia de mes y reacciona al bus` y `test/widget_test.dart` › `Informe de alertas para la comisión › un miembro de la comisión ve la opción, consulta el informe, descarga el CSV y ve el aviso en un mes sin alertas` |
| R8 | `test/unit/dominio_test.dart` › `Informe de alertas › sin alertas en el mes devuelve sinAlertas en true y tablas vacías` y `test/widget_test.dart` › `Informe de alertas para la comisión › un miembro de la comisión ve la opción, consulta el informe, descarga el CSV y ve el aviso en un mes sin alertas` |
| R9 | `test/unit/view_models_test.dart` › `InformeAlertasViewModel y rol en PerfilViewModel › si falla la carga pasa al estado de error` |
| R10 | `test/unit/dominio_test.dart` › `Informe de alertas › toCsv y nombreArchivoCsv exportan el informe y escapan comas`, `test/unit/persistencia_test.dart` › `Descarga de CSV › DescargaCsvServiceLocal guarda el archivo CSV en disco`, `test/unit/view_models_test.dart` › `InformeAlertasViewModel y rol en PerfilViewModel › descargarCsv guarda el CSV del mes y avisa si falla` y `test/widget_test.dart` › `Informe de alertas para la comisión › un miembro de la comisión ve la opción, consulta el informe, descarga el CSV y ve el aviso en un mes sin alertas` |
| R11 | `test/unit/view_models_test.dart` › `InformeAlertasViewModel y rol en PerfilViewModel › descargarCsv guarda el CSV del mes y avisa si falla` |
| R12 | `test/widget_test.dart` › `Informe de alertas para la comisión › un miembro de la comisión ve la opción, consulta el informe, descarga el CSV y ve el aviso en un mes sin alertas` |
| R13 | `test/accesibilidad_test.dart` › `Guías de accesibilidad › Informe de alertas` y `Texto del sistema al 200 % › Informe de alertas` |

## Salida de `./init.sh`

```text
[OK]    feature_list.json válido (14 features)
[OK]    Specs presentes para las features sdd que ya no están en pending
[OK]    flutter pub get
[OK]    dart pub get en backend/
[OK]    flutter analyze sin avisos
[OK]    dart analyze sin avisos en backend/
00:28 +192: All tests passed!
[OK]    Pruebas de la app
00:00 +42: All tests passed!
[OK]    Pruebas del backend
[OK]    Entorno listo. Podés empezar a trabajar.
```
