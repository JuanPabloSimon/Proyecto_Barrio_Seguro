# Implementación — reportar_alerta (feature 18)

- **Rama:** `feature/reportar_alerta` (sin commitear)
- **Spec:** `specs/reportar_alerta/` (R1–R53, T1–T34, todas `[x]`)
- **Estado:** `done` (review aprobado, ver Cierre).
- **Paquetes nuevos:** ninguno. No se tocó nada de la feature 19.

## Archivos tocados

### App (`lib/`)

| Archivo | Cambio |
|---|---|
| `lib/domain/models/alerta.dart` | `CategoriaAlerta.paraReportar`; comentario de `arrebato` (solo para leer) |
| `lib/domain/avisos_tardios.dart` | Solo el comentario de `nombreCorto` |
| `lib/domain/reglas_alertas.dart` (nuevo) | `ReglasAlertas`: máximos, mensajes, `categoriasAceptadas`, `largo`, `errorTitulo`, `errorDescripcion`, `errorDireccion`, `motivoRechazo` |
| `lib/data/services/simulados/servidor_simulado.dart` | `crearAlerta` valida con `ReglasAlertas.motivoRechazo` y lanza `ErrorDelServidor`; `a4` pasa a `robo` / "Robo de celular" |
| `lib/ui/core/ubicacion_de_alerta.dart` (nuevo) | `UbicacionDeAlerta`, `direccionExacta`, `direccionZona` (lógica movida del SOS) |
| `lib/ui/sos/view_models/sos_view_model.dart` | Usa `UbicacionDeAlerta`; misma firma y comportamiento |
| `lib/ui/reportar_alerta/view_models/reportar_alerta_view_model.dart` (nuevo) | `CampoReporte`, `mensajeAlertaReportada`, `mensajeSinConexionAlReportar`, `ReportarAlertaViewModel` |
| `lib/ui/reportar_alerta/widgets/reportar_alerta_screen.dart` (nuevo) | `ReportarAlertaScreen` con `abrir(context, dependencias)` |
| `lib/ui/reportar_alerta/widgets/confirmar_descarte.dart` (nuevo) | `confirmarDescarte(context)` |
| `lib/ui/inicio/widgets/inicio_screen.dart` | Botón "Reportar alerta" (`FilledButton.icon`, `Icons.add_alert_outlined`); "Llamar al 911" sin `Align`; 12 dp entre mapa y botones |
| `lib/ui/core/widgets/boton_sos.dart` | `anchoMinimo` 216, `altoMinimo` 104, texto 32, ícono 36, comentario "mínimo 216x104 dp" |

`lib/dependencias.dart` sin cambios (como dice el design). Los rellenos de
140 dp de Inicio, Turnos y Perfil y `MapaScreen._margenMapa` sin cambios.

### Backend (`backend/`)

| Archivo | Cambio |
|---|---|
| `backend/lib/src/reglas.dart` | `ReglasAlertas` con las mismas constantes, mensajes y `motivoRechazo`; `categorias` sin `arrebato` |
| `backend/lib/src/api.dart` | `_crearAlerta` responde 400 con `ReglasAlertas.motivoRechazo` antes de validar la ubicación; se borró `Api._categorias` |
| `backend/lib/src/datos_de_ejemplo.dart` | `a4` pasa a `robo` / "Robo de celular" |
| `backend/README.md` | Fila de `POST /alertas`: categorías aceptadas, obligatorios y máximos |

### Pruebas

`test/ayudas/falsos.dart` (`AlertasFalsas.errorAlCrear`, `creadas` y
`DatosAlertaCreada`), `test/unit/dominio_test.dart`,
`test/unit/repositorios_test.dart`, `test/unit/view_models_test.dart`,
`test/widget_test.dart`, `test/accesibilidad_test.dart`,
`backend/test/reglas_test.dart`, `backend/test/api_test.dart`.

## Trazabilidad

| Requisito | Prueba |
|---|---|
| R1 | `test/widget_test.dart` › Inicio: reportar alerta › "Reportar alerta" está debajo del mapa y arriba de "Llamar al 911" |
| R2 | `test/widget_test.dart` › Inicio: reportar alerta › "Reportar alerta" y "Llamar al 911" tienen el ancho de la tarjeta del mapa |
| R3 | `test/widget_test.dart` › Inicio: reportar alerta › "Reportar alerta" y "Llamar al 911" tienen el ancho de la tarjeta del mapa |
| R4 | `test/widget_test.dart` › Inicio: reportar alerta › los dos botones son más bajos que el botón SOS (52 < 104) |
| R5 | `test/widget_test.dart` › Inicio: reportar alerta › "Reportar alerta" abre el formulario |
| R6 | `test/unit/dominio_test.dart` › Tipos para reportar › los tipos para reportar son actividad sospechosa, vehículo, robo y ruidos, en ese orden y sin arrebato; `test/unit/view_models_test.dart` › ReportarAlertaViewModel › ofrece los cuatro tipos para reportar en orden; `test/widget_test.dart` › Reportar alerta › muestra los cuatro tipos sin ninguno elegido y los campos vacíos |
| R7 | `test/unit/view_models_test.dart` › ReportarAlertaViewModel › arranca sin tipo elegido; `test/widget_test.dart` › Reportar alerta › muestra los cuatro tipos sin ninguno elegido y los campos vacíos |
| R8 | `test/unit/view_models_test.dart` › ReportarAlertaViewModel › elegir un tipo con el título vacío sugiere su nombre / elegir otro tipo cambia la sugerencia si el título no se tocó; `test/widget_test.dart` › Reportar alerta › elegir "Robo" completa el título con "Robo" |
| R9 | `test/unit/view_models_test.dart` › ReportarAlertaViewModel › elegir otro tipo conserva el título que escribió el vecino; `test/widget_test.dart` › Reportar alerta › el vecino puede cambiar el título |
| R10 | `test/widget_test.dart` › Reportar alerta › el vecino puede cambiar el título |
| R11 | `test/unit/view_models_test.dart` › ReportarAlertaViewModel › con GPS y ubicación exacta activada conUbicacionExacta es true; `test/widget_test.dart` › Reportar alerta › con ubicación exacta dice "Vamos a mandar tu ubicación exacta." |
| R12 | `test/unit/view_models_test.dart` › ReportarAlertaViewModel › sin GPS o sin la preferencia conUbicacionExacta es false; `test/widget_test.dart` › Reportar alerta › sin ubicación exacta dice "Vamos a mandar la zona del barrio, no tu ubicación exacta." |
| R13 | `test/unit/view_models_test.dart` › ReportarAlertaViewModel › envía la posición del GPS y "Ubicación exacta del vecino" si la dirección está vacía |
| R14 | `test/unit/view_models_test.dart` › ReportarAlertaViewModel › si el GPS no responde envía Barrio.centro y "Barrio Soberanía (zona aproximada)" / sin la preferencia envía Barrio.centro (también sin GPS) |
| R15 | `test/unit/view_models_test.dart` › ReportarAlertaViewModel › la dirección escrita viaja sin espacios en los extremos |
| R16 | `test/unit/view_models_test.dart` › ReportarAlertaViewModel › envía la posición del GPS y "Ubicación exacta del vecino" si la dirección está vacía / si el GPS no responde envía Barrio.centro y "Barrio Soberanía (zona aproximada)" |
| R17 | `test/unit/view_models_test.dart` › ReportarAlertaViewModel › enviar crea la alerta con la categoría elegida, el título y la descripción recortados y el id del vecino |
| R18 | `test/unit/view_models_test.dart` › ReportarAlertaViewModel › enviar con la descripción vacía crea la alerta |
| R19 | `test/unit/repositorios_test.dart` › Alertas contra el servidor simulado › una alerta nueva del servidor simulado queda activa; `backend/test/api_test.dart` › Alertas › una alerta nueva de actividad sospechosa queda activa; `test/widget_test.dart` › Inicio: reportar alerta › una alerta reportada aparece en "Alertas cerca tuyo" y en el mapa |
| R20 | `test/widget_test.dart` › Reportar alerta › enviar cierra el formulario y muestra "Reportaste la alerta. Ya aparece en la lista y el mapa." |
| R21 | `test/widget_test.dart` › Inicio: reportar alerta › una alerta reportada aparece en "Alertas cerca tuyo" y en el mapa; `test/unit/view_models_test.dart` › ReportarAlertaViewModel › enviar publica AlertasActualizadas y devuelve true |
| R22 | `test/unit/view_models_test.dart` › ReportarAlertaViewModel › mientras envía enviando es true; `test/widget_test.dart` › Reportar alerta › mientras envía, "Enviar alerta" está deshabilitado con "Enviando la alerta" y Atrás no cierra |
| R23 | `test/widget_test.dart` › Reportar alerta › mientras envía, "Enviar alerta" está deshabilitado con "Enviando la alerta" y Atrás no cierra (X y "Cancelar" deshabilitados, Atrás no cierra ni pregunta) |
| R24 | `test/unit/dominio_test.dart` › ReglasAlertas › motivoRechazo rechaza arrebato y una categoría inventada y acepta sos; `test/unit/view_models_test.dart` › ReportarAlertaViewModel › sin tipo marca el error de tipo y no llama a crearAlerta; `test/widget_test.dart` › Reportar alerta › enviar vacío muestra "Elegí qué tipo de alerta es." y … |
| R25 | `test/unit/dominio_test.dart` › ReglasAlertas › un título vacío o solo con espacios no pasa; `test/unit/view_models_test.dart` › ReportarAlertaViewModel › título vacío y descripción larga marcan los dos errores y primerError es titulo; `test/widget_test.dart` › Reportar alerta › enviar vacío muestra … "Escribí un título para la alerta." … |
| R26 | `test/unit/dominio_test.dart` › ReglasAlertas › un título de 60 letras pasa y uno de 61 no / los espacios de los extremos no cuentan; `test/unit/view_models_test.dart` › ReportarAlertaViewModel › un título de 61 letras marca su error; `test/widget_test.dart` › Reportar alerta › un título de 61 letras muestra "Acortá el título: …" y lleva el foco al Título |
| R27 | `test/unit/dominio_test.dart` › ReglasAlertas › una descripción de 500 letras pasa y una de 501 no; `test/unit/view_models_test.dart` › ReportarAlertaViewModel › título vacío y descripción larga …; `test/widget_test.dart` › Reportar alerta › descripción y dirección largas muestran sus mensajes |
| R28 | `test/unit/dominio_test.dart` › ReglasAlertas › una dirección de 120 letras pasa y una de 121 no; `test/unit/view_models_test.dart` › ReportarAlertaViewModel › dirección larga marca su error; `test/widget_test.dart` › Reportar alerta › descripción y dirección largas muestran sus mensajes |
| R29 | `test/unit/view_models_test.dart` › ReportarAlertaViewModel › sin tipo y con título vacío primerError es tipo / título vacío y descripción larga … primerError es titulo / dirección larga marca su error; `test/widget_test.dart` › Reportar alerta › enviar vacío … lleva el foco al primer tipo / un título de 61 letras … lleva el foco al Título / descripción y dirección largas (foco en Descripción); `test/accesibilidad_test.dart` › Texto del sistema al 200 % › Reportar alerta con errores |
| R30 | `backend/test/api_test.dart` › Alertas › rechaza un título vacío, un título de 61 letras, una descripción de 501 y una dirección de 121 con los mensajes de la app; `backend/test/reglas_test.dart` › ReglasAlertas (todos) |
| R31 | `test/unit/repositorios_test.dart` › Alertas contra el servidor simulado › el servidor simulado rechaza una alerta de arrebato con "Elegí qué tipo de alerta es." / el servidor simulado rechaza un título vacío con el mismo mensaje que la API; `test/unit/dominio_test.dart` › ReglasAlertas (todos) |
| R32 | `test/unit/view_models_test.dart` › ReportarAlertaViewModel › si la API rechaza muestra su mensaje tal cual; `test/widget_test.dart` › Reportar alerta › si la API rechaza, el formulario muestra el mensaje y conserva tipo, título, descripción y dirección; `test/unit/repositorios_test.dart` › Alertas contra el servidor simulado (el `ErrorDelServidor` del simulado llega por el repositorio) |
| R33 | `test/unit/view_models_test.dart` › ReportarAlertaViewModel › sin conexión muestra "No pudimos enviar la alerta. Revisá tu conexión y probá de nuevo."; `test/widget_test.dart` › Reportar alerta › sin conexión el formulario muestra el error de red y conserva lo escrito |
| R34 | `test/unit/view_models_test.dart` › ReportarAlertaViewModel › si falla, el tipo elegido sigue elegido; `test/widget_test.dart` › Reportar alerta › si la API rechaza, … conserva tipo, título, descripción y dirección / sin conexión el formulario muestra el error de red y conserva lo escrito |
| R35 | `test/widget_test.dart` › Sin conexión › el formulario de reportar alerta conserva lo escrito al volver la conexión |
| R36 | `test/unit/view_models_test.dart` › ReportarAlertaViewModel › hayDatos es false sin tipo ni texto (solo espacios) y true con cualquiera de los dos; `test/widget_test.dart` › Reportar alerta › la X sin datos cierra sin preguntar |
| R37 | `test/unit/view_models_test.dart` › ReportarAlertaViewModel › hayDatos …; `test/widget_test.dart` › Reportar alerta › "Cancelar" con un tipo elegido pide "¿Descartar la alerta?" / Atrás con texto escrito pide "¿Descartar la alerta?" |
| R38 | `test/widget_test.dart` › Reportar alerta › "Sí, descartar" cierra sin crear ninguna alerta |
| R39 | `test/widget_test.dart` › Reportar alerta › "Seguir escribiendo" vuelve con todo lo escrito (incluye Atrás en el diálogo) / tocar fuera del diálogo vuelve con todo lo escrito |
| R40 | `backend/test/api_test.dart` › Alertas › rechaza una alerta nueva de arrebato con "Elegí qué tipo de alerta es."; `backend/test/reglas_test.dart` › ReglasAlertas › rechaza arrebato y una categoría inventada y acepta sos |
| R41 | `backend/test/api_test.dart` › Alertas › una alerta de arrebato guardada se sigue leyendo en GET /alertas |
| R42 | `test/unit/dominio_test.dart` › Tipos para reportar › una alerta de arrebato de la API se lee como arrebato (`fromJson` y `fromMap`); `test/widget_test.dart` › una alerta de arrebato guardada se ve con su título y el ícono de arrebato |
| R43 | `test/unit/repositorios_test.dart` › Alertas contra el servidor simulado › los datos del servidor simulado no tienen alertas de arrebato y a4 es "Robo de celular"; `backend/test/api_test.dart` › Alertas › los datos de ejemplo no tienen alertas de arrebato y a4 es "Robo de celular" |
| R44 | Las mismas dos pruebas de R43 (categoría, título, descripción, dirección, ubicación, estado `resuelta`, autora `clara`) |
| R45 | `test/accesibilidad_test.dart` › Guías de accesibilidad › Inicio / Reportar alerta / Reportar alerta con errores / Descartar la alerta (diálogo) |
| R46 | `test/accesibilidad_test.dart` › Reportar alerta › los tipos se anuncian con su nombre y si están elegidos y los campos con su nombre |
| R47 | `test/accesibilidad_test.dart` › Reportar alerta › los errores de tipo y de envío son regiones en vivo con ícono |
| R48 | `test/accesibilidad_test.dart` › Texto del sistema al 200 % › Inicio / Reportar alerta / Reportar alerta con errores / Descartar la alerta (diálogo) |
| R49 | `test/accesibilidad_test.dart` › Reportar alerta › el formulario se lee en orden |
| R50 | `test/accesibilidad_test.dart` › Reportar alerta › con el teclado abierto y el texto al 200 % se llega a "Enviar alerta" y se puede tocar |
| R51 | `test/widget_test.dart` › Botón SOS › el SOS mide 216 x 104 dp con el texto "SOS" en 32 |
| R52 | `test/widget_test.dart` › Botón SOS › BotonSos.altoActual es 104 al 100 % y al 200 %; `test/accesibilidad_test.dart` › Botón SOS › al 200 % en 360 dp el SOS mide al menos 104 de alto y entra en la pantalla sin desbordes |
| R53 | `test/accesibilidad_test.dart` › Botón SOS › al 200 % en 360 x 640 el mapa y la última alerta del inicio se pueden ver enteros por encima del SOS |

## Pruebas existentes que cambiaron

- `test/accesibilidad_test.dart` › Resumen de alerta en el mapa:
  `RegExp('^Alerta: Arrebato')` → `RegExp('^Alerta: Robo de celular')`.
- Las demás (SOS, ubicación, avisos tardíos, arrebato en memoria,
  "Llamar al 911") siguen sin cambios y verdes.

## Decisiones de implementación y desvíos menores (para el reviewer)

1. **Orden T20/T21.** T20 (sin conexión) se hizo después de T21: la prueba
   abre el formulario con el botón del inicio dentro de la app con la
   compuerta, y ese botón llega en T21.
2. **Elegir un tipo borra el error de tipo.** Con un tipo elegido, "Elegí
   qué tipo de alerta es." deja de ser cierto. Los demás errores se
   recalculan al enviar.
3. **Foco al primer error con la lista desplazada (R29).** Con texto
   grande, el `ListView` deja de tener armados los tipos o el título cuando
   el vecino está abajo tocando "Enviar alerta", y el `FocusNode` queda con
   un contexto desmontado. Si pasa eso, la pantalla lleva la lista al
   principio (`ScrollController.jumpTo(0)`), espera un cuadro y recién ahí
   pide el foco y hace `Scrollable.ensureVisible`. Lo cubre la entrada
   `Reportar alerta con errores` al 200 %.
4. **Indicador "Enviando la alerta" (R22).** Reemplaza al ícono del botón;
   el texto "Enviar alerta" queda. El lector lo anuncia junto con el botón
   (etiqueta combinada), por eso la prueba busca con `RegExp`.
5. **T26, última alerta.** En vez de `scrollUntilVisible` con un buscador
   de la última tarjeta (no se sabe cuál es sin armar toda la lista), la
   prueba arrastra hasta `maxScrollExtent` y compara el `bottom` más bajo
   de las `TarjetaAlerta` a la vista contra el `top` del SOS. Mismo
   objetivo que el spec.
6. **T28, teclado.** Después de tocar "Enviar alerta" la prueba quita los
   `viewInsets` (el teclado se va al cerrarse el formulario): si se dejan
   300 dp de teclado falso, el aviso flotante del inicio no entra con texto
   al 200 % y Flutter lo informa como "SnackBar presented off screen". En
   el teléfono el teclado se cierra solo al desaparecer el campo.
7. **Backend, orden de errores.** `_crearAlerta` lee `tipo` (obligatorio
   como dato, igual que antes) antes de validar: si falta el campo `tipo`
   en el JSON responde 400 "Falta el dato "tipo"." aunque la categoría
   también sea inválida. Con todos los campos presentes, el orden es el del
   design (categoría, título, descripción, dirección, ubicación).

## `./init.sh` completo (resumen)

```
── 1. Entorno ── [OK] Flutter 3.47.5 / Dart 3.13.4
── 2. Archivos base del arnés ── [OK] (todos)
── 3. feature_list.json y specs ──
[OK] feature_list.json válido (19 features)
[OK] Specs presentes para las features sdd que ya no están en pending
── 4. Dependencias y analizador ──
[OK] flutter pub get
[OK] dart pub get en backend/
No issues found!   [OK] flutter analyze sin avisos
No issues found!   [OK] dart analyze sin avisos en backend/
── 5. Pruebas ──
00:39 +411: All tests passed!   [OK] Pruebas de la app
00:00 +62: All tests passed!    [OK] Pruebas del backend
── 6. Resumen ──
[OK] Entorno listo. Podés empezar a trabajar.
```

## Prueba manual

No se hizo (sin emulador en esta sesión). Queda recomendada antes de
cerrar: reportar una alerta con el servidor simulado y con la API
(`cd backend && dart run bin/servidor.dart`), probar el descarte con la X y
con Atrás, y mirar el SOS nuevo con el texto al 200 %. Ojo: un
`backend/datos/barrio.json` creado antes conserva su `a4` de arrebato
(esperado, R41); para ver los datos de ejemplo nuevos hay que borrarlo.

## Cierre

- 2026-11-26: el reviewer aprobó (`progress/review_reportar_alerta.md`, veredicto APPROVED) y `./init.sh` pasó completo (app y backend verdes).
- `feature_list.json`: la feature 18 `reportar_alerta` pasó a `"status": "done"`. La feature 19 no se tocó.
- Resumen de `progress/current.md` agregado al final de `progress/history.md` (entrada "2026-11-26 — Feature 18 (`reportar_alerta`)") con los pendientes que no bloquean.
- `progress/current.md` vuelve a la plantilla.
- No se tocó código de `lib/`, `test/` ni `backend/`. Sin commit ni push.
