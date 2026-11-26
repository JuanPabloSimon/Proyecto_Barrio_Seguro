# Tasks — sos_mejorado

> Pasos en orden. El `implementer` marca `[x]` al terminar cada uno. Cada
> task dice qué `R<n>` cubre. T1 a T12 viven en `lib/ui/sos/` y en las
> pruebas. T13 a T19 son el pedido del equipo en la aprobación (SOS
> distinguible de un robo, R22 a R31, y todos los SOS en una fila "SOS" del informe, R32 a
> R34): tocan `lib/domain/models/alerta.dart`, `lib/domain/informe_alertas.dart`
> y `lib/ui/core/` y las pantallas de mapa y detalle. Sin cambios de datos
> ni de backend.

## Ayudas de prueba

- [ ] T1 — En `test/ayudas/falsos.dart`: `alertaDePrueba` suma parámetros opcionales `categoria`, `tipo`, `descripcion` y `direccion` (por defecto los valores actuales: `robo`, "Intento de robo", "Prueba", "Calle de prueba"); `AlertasFalsas.crearAlerta` guarda los que recibe; `AlertasFalsas` cuenta `cambiosDeEstado` en `cambiarEstado`. Correr `test/unit/repositorios_test.dart` y `test/unit/ubicacion_test.dart` y ajustar lo que dependa de la alerta creada siempre igual. Cubre: R1, R2, R12, R16.

## Dominio (solo prueba)

- [ ] T2 — Prueba `el aviso tardío de un SOS "Intento de robo" dice "SOS de Marta 15:10"` en `test/unit/avisos_tardios_test.dart` (alerta `categoria: sos`, `tipo: 'Intento de robo'`, `reportadaPorNombre: 'Marta'`). Cubre: R4.

## ViewModel

- [ ] T3 — En `lib/ui/sos/view_models/sos_view_model.dart`: constantes `tipoAlertaSos = 'Intento de robo'` y `descripcionAlertaSos`; `enviar()` las usa. Cubre: R1, R2.
- [ ] T4 — Pruebas en `test/unit/view_models_test.dart` (grupo `SosViewModel`): `enviar crea una alerta sos con el título "Intento de robo"`, `enviar manda la descripción, la dirección y quien reporta como antes`, `si falla cerrarAlerta devuelve false y la alerta sigue activa`. Cubre: R1, R2, R17.

## Backend (solo prueba)

- [ ] T5 — En `backend/test/api_test.dart` › `la alerta nueva queda a nombre de quien tiene la sesión`: mandar `'tipo': 'Intento de robo'` y verificar `tipo` y `categoria` de la respuesta, además de `estado` y `creada_en` que ya verifica. Cubre: R3.

## Pantalla

- [ ] T6 — Crear `lib/ui/sos/widgets/confirmar_cierre_sos.dart` con `enum CierreSos { aSalvo, falsaAlarma }` y `confirmarCierreSos(context, cierre)` con los textos, íconos, colores y tamaños de `design.md` (`AlertDialog(scrollable: true, actionsOverflowButtonSpacing: 8)`, cancelar `OutlinedButton` "Seguir con la alerta", confirmar `FilledButton`, ambos `minimumSize: Size(0, 48)`; `null` → `false`). Cubre: R9, R13, R18, R19, R20, R21.
- [ ] T7 — En `lib/ui/sos/widgets/sos_screen.dart`: `_confirmarYCerrar` (confirma antes de `cerrarAlerta`, no hace nada si se cancela, reutiliza `_cerrar` con los avisos de éxito o de falla); `_VistaSosEnviada` recibe `onCerrar: ValueChanged<CierreSos>`. Cubre: R10, R11, R12, R14, R15, R16, R17.
- [ ] T8 — En `lib/ui/sos/widgets/sos_screen.dart`: botón "Volver" (`OutlinedButton.icon`, `Icons.arrow_back`, estilo de contorno del SOS) al final de `_VistaSosEnviada`; `_volver` cierra y muestra el aviso "Tu alerta sigue activa. La encontrás en Perfil, en "Mis alertas reportadas"."; `PopScope(canPop: paso != enviada, onPopInvokedWithResult: …_volver)`. Cubre: R5, R6, R7, R8, R18, R19, R21.
- [ ] T9 — Pruebas de widgets en `test/widget_test.dart`, grupo `SOS enviado` (SosScreen empujada sobre una pantalla base, con `AlertasFalsas`): `la pantalla del SOS enviado muestra "Volver"`; `"Volver" cierra el SOS, deja la alerta activa y avisa dónde encontrarla`; `el botón Atrás en el SOS enviado hace lo mismo que "Volver"`. Cubre: R5, R6, R7, R8.
- [ ] T10 — Pruebas de widgets en `test/widget_test.dart`, grupo `SOS enviado`: `"Ya estoy a salvo" pide confirmación con los textos acordados` (título, texto, `OutlinedButton` "Seguir con la alerta", `FilledButton` "Sí, estoy a salvo"); `confirmar "Sí, estoy a salvo" resuelve la alerta y cierra con aviso`; `"Seguir con la alerta" en "Ya estoy a salvo" no cambia nada`; `Atrás en el diálogo de "Ya estoy a salvo" no cambia nada` (estado `activa`, `cambiosDeEstado == 0`, sigue "Alerta enviada"). Cubre: R9, R10, R11, R12, R20.
- [ ] T11 — Pruebas de widgets en `test/widget_test.dart`, grupo `SOS enviado`: `"Fue una falsa alarma" pide confirmación con los textos acordados`; `confirmar "Sí, fue una falsa alarma" resuelve la alerta y cierra con aviso`; `"Seguir con la alerta" en "Fue una falsa alarma" no cambia nada`; `tocar fuera del diálogo de "Fue una falsa alarma" no cambia nada`; `si falla el cierre se avisa que se haga desde "Mis alertas"` (con `AlertasFalsas.falla = true` después de enviar). Cubre: R13, R14, R15, R16, R17, R20.
- [ ] T12 — En `test/accesibilidad_test.dart`: la entrada `SOS: alerta enviada` verifica `find.text('Volver')`; entradas nuevas `SOS: confirmar "Ya estoy a salvo" (diálogo)` y `SOS: confirmar "Fue una falsa alarma" (diálogo)` en `pantallas` (corren con las guías y al 200 %); prueba `el botón "Volver" y los botones de los diálogos se anuncian con su texto` con `tester.getSemantics`. Cubre: R18, R19, R21.

## SOS distinguible de un robo y todos los SOS en una fila del informe (pedido del equipo en la aprobación)

### Dominio

- [ ] T13 — En `lib/domain/models/alerta.dart`: `const prefijoSos = 'SOS: '` y getter `Alerta.tituloConCategoria` (`'SOS: $tipo'` si `categoria == sos`, `tipo` si no). Prueba en `test/unit/dominio_test.dart`: `tituloConCategoria antepone "SOS: " solo a las alertas sos` (una `sos` "Intento de robo" → "SOS: Intento de robo"; una `robo` "Intento de robo" → "Intento de robo"). Cubre: R28, R29.
- [ ] T14 — En `lib/domain/informe_alertas.dart`: importar `avisos_tardios.dart`, constante `filaSosInforme = 'SOS'` y privado `_nombreDeTipo(Alerta)` (título tal cual, "Sin tipo" si está vacío y "<título> (<nombreCorto ?? 'otra categoría'>)" si una alerta que no es `sos` se titula "SOS" sin importar mayúsculas ni espacios al borde). En `delMes`: las alertas `sos` suman a un contador `sos` y no al mapa `tipos`; las demás van a `tipos` con `_nombreDeTipo`; después del `for`, `if (sos > 0) tipos[filaSosInforme] = sos`. `_ordenar` y `toCsv()` sin cambios. En `test/unit/dominio_test.dart`, grupo `Informe de alertas`: el helper `crearAlerta` suma `CategoriaAlerta categoria = CategoriaAlerta.robo`; pruebas nuevas `cuenta todos los SOS en una sola fila "SOS"` (`sos` "Intento de robo", `sos` "Pedido de ayuda (SOS)" y dos `robo` "Intento de robo" → `porTipo` `['Intento de robo:2', 'SOS:2']`), `un robo titulado "SOS" no se suma a la fila de los SOS` (`sos` "Intento de robo", `robo` "SOS", `robo` " sos " y `robo` "Pedido de ayuda (SOS)" → `['Pedido de ayuda (SOS):1', 'SOS:1', 'SOS (Robo):1', 'sos (Robo):1']`) y `el CSV trae una sola fila de los SOS` (dos `sos` con títulos distintos → `contains('Por tipo,SOS,2')` e `isNot(contains('Por tipo,SOS: '))`). Correr todo el grupo `Informe de alertas` y la prueba de widgets del informe: tienen que seguir verdes sin cambios. Cubre: R32, R33, R34.

### Pantalla

- [ ] T15 — Crear `lib/ui/core/widgets/marca_sos.dart` con `MarcaSos` (fondo `emergenciaSuave`, borde `emergencia` 1.5, radio 8, `Icons.campaign` 16 en `emergencia` y `Flexible(Text('SOS'))` en `AppColors.texto`, negrita 14, todo en `ExcludeSemantics`). Sumar a `AppColors.paresDeContraste` los pares "Texto sobre rojo suave (marca SOS)" (`texto`/`emergenciaSuave`, `textoNormal`) y "Rojo de emergencia sobre rojo suave (marca SOS)" (`emergencia`/`emergenciaSuave`, `componente`). Cubre: R30, R31.
- [ ] T16 — En `TarjetaAlerta`: `Wrap(spacing: 8, runSpacing: 8)` con `if (sos) const MarcaSos()` y `ChipEstado`; `descripcion` empieza con "Alerta SOS: <tipo en minúsculas>" si es `sos` (igual que hoy si no). En `MapaBarrio.etiquetaDe`: "Alerta SOS: <tipo>" si es `sos` (igual que hoy si no). Cubre: R22, R25, R26, R27, R29, R30.
- [ ] T17 — En el resumen de `MapaScreen` y en `DetalleAlertaScreen`: `if (sos) const MarcaSos()` como primer hijo del `Wrap` y `Text(alerta.tipo, semanticsLabel: alerta.tituloConCategoria, …)` en el título. Cubre: R23, R24, R25, R28, R29, R30.
- [ ] T18 — Pruebas de widgets en `test/widget_test.dart`, grupo `SOS y robo con el mismo título` (`appDePrueba`, enviar un SOS, "Volver"): `la tarjeta del SOS lleva la marca SOS y la de robo no`; `la tarjeta del SOS se anuncia "Alerta SOS: intento de robo, …" y la de robo como antes`; `el pin del SOS se anuncia "Alerta SOS: Intento de robo, …" y su resumen muestra la marca y lee "SOS: Intento de robo"` (y el de `a3` sin marca, con su etiqueta de hoy); `el detalle del SOS muestra la marca y lee "SOS: Intento de robo"` (y el de `a3` sin marca); `"Mis alertas reportadas" muestra la marca SOS en la alerta enviada`; `la marca SOS no se anuncia aparte` (`find.bySemanticsLabel('SOS')` `findsNothing` en Inicio, resumen y detalle). Buscar el SOS con `RegExp('^Alerta SOS: ')` y `a3` con `RegExp('^Alerta de intento')` / `RegExp('^Alerta: Intento')`. Cubre: R22, R23, R24, R25, R26, R27, R28, R29, R30.
- [ ] T19 — Accesibilidad en `test/accesibilidad_test.dart`, lista `pantallas` (corren con las guías `androidTapTargetGuideline`, `iOSTapTargetGuideline`, `labeledTapTargetGuideline`, `textContrastGuideline` y al 200 %): `Inicio con una alerta SOS`, `Resumen de una alerta SOS en el mapa` y `Detalle de una alerta SOS` (envían un SOS, tocan "Volver" y abren cada vista por `RegExp('^Alerta SOS: ')`, verificando que `MarcaSos` está a la vista). Verificar que la prueba de contraste de `AppColors.paresDeContraste` recorre los dos pares nuevos. Cubre: R31.

## Cierre

- [ ] T20 — Trazabilidad `R<n>` → prueba en `progress/impl_sos_mejorado.md` (R1 a R34).
- [ ] T21 — `./init.sh` verde.
