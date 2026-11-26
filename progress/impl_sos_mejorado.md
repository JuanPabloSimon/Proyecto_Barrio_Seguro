# Implementación — sos_mejorado (feature 17)

- **Rama:** `feature/sos_mejorado` (sin commitear)
- **Fecha:** 2026-11-25
- **Spec:** `specs/sos_mejorado/` (R1–R34, T1–T21 marcadas `[x]`)
- **Paquetes nuevos:** ninguno. Backend: sin cambios de código (solo su prueba).
- **Features 18 y 19:** sin tocar. Datos de ejemplo (`a3`) sin cambios.

## Archivos tocados

| Capa | Archivo | Cambio |
|---|---|---|
| domain | `lib/domain/models/alerta.dart` | `prefijoSos` y getter `Alerta.tituloConCategoria` |
| domain | `lib/domain/informe_alertas.dart` | `filaSosInforme`; los SOS se cuentan aparte en una fila "SOS"; `_nombreDeTipo` (título "SOS" de otra categoría → "SOS (Robo)"); importa `avisos_tardios.dart` para `nombreCorto`. `_ordenar` y `toCsv()` sin cambios |
| ui | `lib/ui/sos/view_models/sos_view_model.dart` | `tipoAlertaSos = 'Intento de robo'`, `descripcionAlertaSos`; `enviar()` las usa |
| ui | `lib/ui/sos/widgets/confirmar_cierre_sos.dart` (nuevo) | `enum CierreSos`, `confirmarCierreSos(context, cierre)` |
| ui | `lib/ui/sos/widgets/sos_screen.dart` | `PopScope` (dentro de un `ListenableBuilder` con `child`), `_volver`, `_confirmarYCerrar`, botón "Volver"; `_VistaSosEnviada` con `onCerrar`/`onVolver` |
| ui | `lib/ui/core/widgets/marca_sos.dart` (nuevo) | `MarcaSos` (ícono + "SOS", en `ExcludeSemantics`) |
| ui | `lib/ui/core/widgets/tarjeta_alerta.dart` | `Wrap` con `MarcaSos` + `ChipEstado`; `descripcion` "Alerta SOS: …" para `sos` |
| ui | `lib/ui/core/widgets/mapa_barrio.dart` | `etiquetaDe` "Alerta SOS: …" para `sos` |
| ui | `lib/ui/mapa/widgets/mapa_screen.dart` | Resumen: `MarcaSos` en el `Wrap` y `semanticsLabel: tituloConCategoria` |
| ui | `lib/ui/alerta_detalle/widgets/detalle_alerta_screen.dart` | Igual que el resumen |
| ui | `lib/ui/core/tema/app_colors.dart` | Pares "Texto sobre rojo suave (marca SOS)" y "Rojo de emergencia sobre rojo suave (marca SOS)" |
| pruebas | `test/ayudas/falsos.dart` | `alertaDePrueba` con `categoria`/`tipo`/`descripcion`/`direccion`; `AlertasFalsas.crearAlerta` guarda lo recibido; `cambiosDeEstado`; `cambiarEstado` conserva los datos de la alerta |
| pruebas | `test/unit/avisos_tardios_test.dart`, `test/unit/view_models_test.dart`, `test/unit/dominio_test.dart`, `test/widget_test.dart`, `test/accesibilidad_test.dart`, `backend/test/api_test.dart` | Pruebas nuevas (ver trazabilidad) |

Notas:

- `AlertasFalsas.cambiarEstado` ahora conserva categoría, tipo, descripción, dirección, fecha y nombre de la alerta (antes la rehacía con los valores por defecto). Ninguna prueba existente dependía de eso; todas siguen verdes.
- En `accesibilidad_test.dart`, `abrirSosYVolver` espera 7 s a que se vaya el aviso "Tu alerta sigue activa…": al 200 % ese aviso ocupa mucho y sube el botón SOS sobre el centro de la lista, y el helper `mostrar` no encontraba la lista tocable. Es solo de la prueba; la pantalla no cambió por esto.
- Las pruebas de la feature 14 (`Informe de alertas` en `dominio_test.dart` y el widget del informe) no cambiaron y están verdes; el helper `crearAlerta` solo sumó `categoria` opcional (por defecto `robo`).

## Trazabilidad

| Requisito | Prueba |
|---|---|
| R1 | `test/unit/view_models_test.dart` › SosViewModel › enviar crea una alerta sos con el título "Intento de robo" |
| R2 | `test/unit/view_models_test.dart` › SosViewModel › enviar manda la descripción, la dirección y quien reporta como antes; `test/unit/ubicacion_test.dart` › SOS (ubicación exacta / zona, sin cambios) |
| R3 | `backend/test/api_test.dart` › la alerta nueva queda a nombre de quien tiene la sesión (tipo "Intento de robo", categoría `sos`, estado `activa`, `creada_en` del servidor) |
| R4 | `test/unit/avisos_tardios_test.dart` › Texto del aviso tardío › el aviso tardío de un SOS "Intento de robo" dice "SOS de Marta 15:10" |
| R5 | `test/widget_test.dart` › SOS enviado › la pantalla del SOS enviado muestra "Volver" |
| R6 | `test/widget_test.dart` › SOS enviado › "Volver" cierra el SOS, deja la alerta activa y avisa dónde encontrarla |
| R7 | `test/widget_test.dart` › SOS enviado › el botón Atrás en el SOS enviado hace lo mismo que "Volver" (y "Sin conexión › con conexión el botón Atrás cierra el SOS como siempre", sin cambios, para el paso de confirmar) |
| R8 | `test/widget_test.dart` › SOS enviado › "Volver" cierra el SOS… / el botón Atrás en el SOS enviado… |
| R9 | `test/widget_test.dart` › SOS enviado › "Ya estoy a salvo" pide confirmación con los textos acordados |
| R10 | `test/widget_test.dart` › SOS enviado › confirmar "Sí, estoy a salvo" resuelve la alerta y cierra con aviso |
| R11 | `test/widget_test.dart` › SOS enviado › confirmar "Sí, estoy a salvo" resuelve la alerta y cierra con aviso |
| R12 | `test/widget_test.dart` › SOS enviado › "Seguir con la alerta" en "Ya estoy a salvo" no cambia nada; Atrás en el diálogo de "Ya estoy a salvo" no cambia nada |
| R13 | `test/widget_test.dart` › SOS enviado › "Fue una falsa alarma" pide confirmación con los textos acordados |
| R14 | `test/widget_test.dart` › SOS enviado › confirmar "Sí, fue una falsa alarma" resuelve la alerta y cierra con aviso |
| R15 | `test/widget_test.dart` › SOS enviado › confirmar "Sí, fue una falsa alarma" resuelve la alerta y cierra con aviso |
| R16 | `test/widget_test.dart` › SOS enviado › "Seguir con la alerta" en "Fue una falsa alarma" no cambia nada; tocar fuera del diálogo de "Fue una falsa alarma" no cambia nada |
| R17 | `test/widget_test.dart` › SOS enviado › si falla el cierre se avisa que se haga desde "Mis alertas"; `test/unit/view_models_test.dart` › si falla cerrarAlerta devuelve false y la alerta sigue activa |
| R18 | `test/accesibilidad_test.dart` › Guías de accesibilidad › SOS: alerta enviada / SOS: confirmar "Ya estoy a salvo" (diálogo) / SOS: confirmar "Fue una falsa alarma" (diálogo) |
| R19 | `test/accesibilidad_test.dart` › Texto del sistema al 200 % › SOS: alerta enviada (con "Volver" a la vista) / los dos diálogos (con el botón de confirmar a la vista) |
| R20 | `test/widget_test.dart` › SOS enviado › "Ya estoy a salvo" pide confirmación… / "Fue una falsa alarma" pide confirmación… (`OutlinedButton` cancelar, `FilledButton` confirmar) |
| R21 | `test/accesibilidad_test.dart` › SOS enviado › el botón "Volver" y los botones de los diálogos se anuncian con su texto |
| R22 | `test/widget_test.dart` › SOS y robo con el mismo título › la tarjeta del SOS lleva la marca SOS y la de robo no; "Mis alertas reportadas" muestra la marca SOS en la alerta enviada |
| R23 | `test/widget_test.dart` › SOS y robo con el mismo título › el pin del SOS se anuncia "Alerta SOS: Intento de robo, …" y su resumen muestra la marca… |
| R24 | `test/widget_test.dart` › SOS y robo con el mismo título › el detalle del SOS muestra la marca y lee "SOS: Intento de robo" |
| R25 | `test/widget_test.dart` › SOS y robo con el mismo título › la tarjeta del SOS lleva la marca SOS y la de robo no; el pin del SOS… (resumen de `a3` sin marca); el detalle del SOS… (detalle de `a3` sin marca) |
| R26 | `test/widget_test.dart` › SOS y robo con el mismo título › la tarjeta del SOS se anuncia "Alerta SOS: intento de robo, …" y la de robo como antes |
| R27 | `test/widget_test.dart` › SOS y robo con el mismo título › el pin del SOS se anuncia "Alerta SOS: Intento de robo, …"… |
| R28 | `test/widget_test.dart` › el pin del SOS… (resumen lee "SOS: Intento de robo") / el detalle del SOS…; `test/unit/dominio_test.dart` › tituloConCategoria antepone "SOS: " solo a las alertas sos |
| R29 | `test/widget_test.dart` › la tarjeta del SOS se anuncia… y la de robo como antes / el pin del SOS… (pin y resumen de `a3` sin cambios) / el detalle del SOS… (detalle de `a3` lee "Intento de robo"); `test/unit/dominio_test.dart` › tituloConCategoria…; pruebas existentes de alertas tardías que buscan `^Alerta de intento` y `^Alerta: Intento` (verdes) |
| R30 | `test/widget_test.dart` › SOS y robo con el mismo título › la marca SOS no se anuncia aparte |
| R31 | `test/accesibilidad_test.dart` › Guías y 200 % › Inicio con una alerta SOS / Resumen de una alerta SOS en el mapa / Detalle de una alerta SOS; Colores › Los pares de la marca SOS están en AppColors / Todos los pares de AppColors cumplen el contraste mínimo |
| R32 | `test/unit/dominio_test.dart` › Informe de alertas › cuenta todos los SOS en una sola fila "SOS"; un robo titulado "SOS" no se suma a la fila de los SOS |
| R33 | `test/unit/dominio_test.dart` › Informe de alertas › cuenta todos los SOS en una sola fila "SOS"; un robo titulado "SOS" no se suma a la fila de los SOS (y las pruebas de la feature 14, sin cambios) |
| R34 | `test/unit/dominio_test.dart` › Informe de alertas › el CSV trae una sola fila de los SOS |

## `./init.sh` completo (resumen)

```
── 1. Entorno ──  [OK] Flutter 3.47.5 • [OK] Dart SDK 3.13.4
── 2. Archivos base del arnés ──  [OK] (todos)
── 3. feature_list.json y specs ──  [OK] feature_list.json válido (19 features)
                                     [OK] Specs presentes para las features sdd que ya no están en pending
── 4. Dependencias y analizador ──  [OK] flutter pub get / dart pub get en backend/
                                     flutter analyze: No issues found!
                                     dart analyze (backend): No issues found!
── 5. Pruebas ──  App: 00:36 +333: All tests passed!
                  Backend: 00:00 +48: All tests passed!
── 6. Resumen ──  [OK] Entorno listo. Podés empezar a trabajar.
```

`dart format` sobre `lib`, `test`, `backend/lib` y `backend/test`: 0 cambios pendientes.

## Prueba manual

No se hizo en el emulador. El recorrido (enviar SOS, "Volver", Atrás, los dos diálogos con confirmar y cancelar, marca SOS en Inicio, Mapa, detalle y "Mis alertas reportadas") está cubierto por las pruebas de widgets con la app completa (`appDePrueba`) y con `SosScreen` empujada sobre una pantalla base.
