# Tasks — informe_alertas

> Pasos en orden. El `implementer` marca `[x]` al terminar cada uno. Cada
> task dice qué `R<n>` cubre.

## Dominio y servicio de descarga CSV

- [x] T1 — Crear `lib/domain/informe_alertas.dart` con `FranjaInforme`, `FilaInforme` e `InformeAlertas.delMes` (filtrado por año/mes, agrupación y ordenamiento por calle, por tipo y por franja horaria, más `nombreArchivoCsv` y `toCsv()`). Cubre: R1, R2, R3, R4, R10.
- [x] T2 — Pruebas unitarias en el grupo `Informe de alertas` de `test/unit/dominio_test.dart`: filtrado solo del mes elegido (R1), conteo y orden por calle (R2), conteo y orden por tipo (R3), conteo por franja horaria (R4), informe sin alertas en el mes (`sinAlertas: true`; R8) y generación de CSV con `toCsv()` y `nombreArchivoCsv` (R10). Cubre: R1, R2, R3, R4, R8, R10.
- [x] T3 — Crear `lib/data/services/descarga_csv_service.dart` (`DescargaCsvService` y `DescargaCsvServiceLocal`), inyectarlo en `lib/dependencias.dart` y agregar `DescargaCsvFalsa` en `test/ayudas/falsos.dart` y `test/ayudas/app_de_prueba.dart`, con prueba de escritura en directorio temporal en `test/unit/persistencia_test.dart`. Cubre: R10, R11.

## ViewModel

- [x] T4 — Agregar `bool get esComision` en `PerfilViewModel` (`lib/ui/perfil/view_models/perfil_view_model.dart`) y crear `InformeAlertasViewModel` en `lib/ui/informe_alertas/view_models/informe_alertas_view_model.dart` (carga desde `AlertasRepository`, selección de mes `mesAnterior`/`mesSiguiente`/`elegirMes`, suscripción a `AlertasActualizadas`, `descargarCsv()` y `dispose`). Cubre: R5, R6, R7, R8, R9, R10, R11.
- [x] T5 — Pruebas unitarias en `test/unit/view_models_test.dart`: `PerfilViewModel.esComision` según el rol del vecino (R5, R6) y grupo `InformeAlertasViewModel` (carga del mes actual, cambio a un mes sin alertas, actualización al publicar `AlertasActualizadas`, estado de error cuando falla el repositorio y descarga de CSV exitosa y con fallo; R7, R8, R9, R10, R11). Cubre: R5, R6, R7, R8, R9, R10, R11.

## Pantalla y accesibilidad

- [x] T6 — Crear `InformeAlertasScreen` en `lib/ui/informe_alertas/widgets/informe_alertas_screen.dart` (dividida en clases `StatelessWidget`, con selector de mes accesible, botón `"Descargar informe (CSV)"` en meses con alertas, mensaje sin tablas ni botón de descarga cuando no hay alertas en el mes, y tablas por calle, por tipo y por franja horaria) y agregar la entrada `"Informe mensual de alertas"` en `PerfilScreen` (`lib/ui/perfil/widgets/perfil_screen.dart`) visible únicamente cuando `viewModel.esComision` es `true`. Cubre: R5, R6, R7, R8, R9, R10, R11, R12, R13.
- [x] T7 — Pruebas de widgets en `test/widget_test.dart` (miembro de la comisión ve la opción en el perfil, abre el informe con los totales por calle/tipo/franja, descarga el CSV tocando `"Descargar informe (CSV)"`, y al cambiar a un mes sin alertas ve el mensaje de mes vacío sin tablas ni botón de descarga; un vecino común no ve la opción en el perfil) y agregar la pantalla `Informe de alertas` en `test/accesibilidad_test.dart` (guías de 48 dp, etiquetas, contraste y texto al 200 %). Cubre: R5, R6, R7, R8, R10, R12, R13.

## Cierre

- [x] T8 — Trazabilidad `R<n>` → prueba en `progress/impl_informe_alertas.md`.
- [x] T9 — `./init.sh` verde.
