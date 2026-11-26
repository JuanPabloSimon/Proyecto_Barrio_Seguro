# Tasks — reportar_alerta

> Pasos en orden. El `implementer` marca `[x]` al terminar cada uno. Cada
> task dice qué `R<n>` cubre. Orden: dominio → datos → ViewModel →
> pantalla → inicio → botón SOS → backend. No tocar nada de la feature 19.

## Ayudas de prueba

- [x] T1 — En `test/ayudas/falsos.dart`: `AlertasFalsas` suma `ErrorDelServidor? errorAlCrear` (si no es null, `crearAlerta` lo lanza) y guarda los datos de cada `crearAlerta` (categoría, tipo, descripción, dirección, ubicación, reportadaPor) en `creadas`. Las pruebas que ya usan `ubicacionesEnviadas` siguen igual. Cubre: R13, R14, R15, R16, R17, R18, R32.

## Dominio

- [x] T2 — `CategoriaAlerta.paraReportar` en `lib/domain/models/alerta.dart` y comentario de `arrebato` ("solo para leer alertas viejas"); actualizar el comentario de `nombreCorto` en `lib/domain/avisos_tardios.dart`. Cubre: R6, R42.
- [x] T3 — Pruebas en `test/unit/dominio_test.dart`: `los tipos para reportar son actividad sospechosa, vehículo, robo y ruidos, en ese orden y sin arrebato`; `una alerta de arrebato de la API se lee como arrebato` (`fromJson` y `fromMap`). Cubre: R6, R42.
- [x] T4 — Crear `lib/domain/reglas_alertas.dart` con `ReglasAlertas` (máximos, mensajes, `categoriasAceptadas`, `largo`, `errorTitulo`, `errorDescripcion`, `errorDireccion`, `motivoRechazo`) según `design.md`. Cubre: R24, R25, R26, R27, R28, R31.
- [x] T5 — Pruebas en `test/unit/dominio_test.dart`, grupo `ReglasAlertas`: título vacío o solo espacios; título de 60 letras pasa y de 61 no; los espacios de los extremos no cuentan; descripción de 500/501; dirección de 120/121; descripción y dirección vacías pasan; `motivoRechazo` rechaza `arrebato` y una categoría inventada con "Elegí qué tipo de alerta es." y acepta `sos`; los valores del SOS (`tipoAlertaSos`, `descripcionAlertaSos`) pasan. Cubre: R24, R25, R26, R27, R28, R31.

## Datos

- [x] T6 — En `lib/data/services/simulados/servidor_simulado.dart`: `crearAlerta` lanza `ErrorDelServidor(ReglasAlertas.motivoRechazo(...))` si hay motivo; `a4` pasa a `'categoria': 'robo'`, `'tipo': 'Robo de celular'`, el resto igual. Cubre: R19, R31, R43, R44.
- [x] T7 — Pruebas en `test/unit/repositorios_test.dart` (con `AlertasServiceSimulado`): `el servidor simulado rechaza una alerta de arrebato con "Elegí qué tipo de alerta es."`; `el servidor simulado rechaza un título vacío con el mismo mensaje que la API`; `una alerta nueva del servidor simulado queda activa`; `los datos del servidor simulado no tienen alertas de arrebato y a4 es "Robo de celular"` (categoría, descripción, dirección, ubicación, estado `resuelta`, `reportada_por` `clara`). Cubre: R19, R31, R32, R43, R44.

## Ubicación compartida

- [x] T8 — Crear `lib/ui/core/ubicacion_de_alerta.dart` (`UbicacionDeAlerta`, `direccionExacta`, `direccionZona`) moviendo la lógica de `SosViewModel._ubicacionExacta`; `SosViewModel` la usa sin cambiar su firma. Correr `test/unit/view_models_test.dart` y `test/unit/ubicacion_test.dart`: tienen que seguir verdes sin cambios. Cubre: R13, R14, R16.

## ViewModel

- [x] T9 — Crear `lib/ui/reportar_alerta/view_models/reportar_alerta_view_model.dart` (`CampoReporte`, mensajes, `ReportarAlertaViewModel`) según `design.md`. Cubre: R6, R7, R8, R9, R11, R12, R13, R14, R15, R16, R17, R18, R20, R21, R22, R24, R25, R26, R27, R28, R29, R32, R33, R34, R36, R37.
- [x] T10 — Pruebas en `test/unit/view_models_test.dart`, grupo `ReportarAlertaViewModel` — tipos y título: `ofrece los cuatro tipos para reportar en orden`; `arranca sin tipo elegido`; `elegir un tipo con el título vacío sugiere su nombre`; `elegir otro tipo cambia la sugerencia si el título no se tocó`; `elegir otro tipo conserva el título que escribió el vecino`. Cubre: R6, R7, R8, R9.
- [x] T11 — Pruebas en el mismo grupo — ubicación: `con GPS y ubicación exacta activada conUbicacionExacta es true`; `sin GPS o sin la preferencia conUbicacionExacta es false`; `envía la posición del GPS y "Ubicación exacta del vecino" si la dirección está vacía`; `si el GPS no responde envía Barrio.centro y "Barrio Soberanía (zona aproximada)"`; `sin la preferencia envía Barrio.centro`; `la dirección escrita viaja sin espacios en los extremos`. Cubre: R11, R12, R13, R14, R15, R16.
- [x] T12 — Pruebas en el mismo grupo — envío: `enviar crea la alerta con la categoría elegida, el título y la descripción recortados y el id del vecino`; `enviar con la descripción vacía crea la alerta`; `enviar publica AlertasActualizadas y devuelve true`; `mientras envía enviando es true`. Cubre: R17, R18, R21, R22.
- [x] T13 — Pruebas en el mismo grupo — validaciones y errores: `sin tipo marca el error de tipo y no llama a crearAlerta`; `título vacío y descripción larga marcan los dos errores y primerError es titulo`; `sin tipo y con título vacío primerError es tipo`; `dirección larga marca su error`; `si la API rechaza muestra su mensaje tal cual` (`errorAlCrear`); `sin conexión muestra "No pudimos enviar la alerta. Revisá tu conexión y probá de nuevo."` (`falla = true`); `si falla, el tipo elegido sigue elegido`; `hayDatos es false sin tipo ni texto (solo espacios) y true con cualquiera de los dos`. Cubre: R24, R25, R26, R27, R28, R29, R32, R33, R34, R36, R37.

## Pantalla del formulario

- [x] T14 — Crear `lib/ui/reportar_alerta/widgets/confirmar_descarte.dart` (`confirmarDescarte`, textos, botones y armado de `design.md`). Cubre: R37, R38, R39, R45, R48.
- [x] T15 — Crear `lib/ui/reportar_alerta/widgets/reportar_alerta_screen.dart`: `abrir` con `MaterialPageRoute(fullscreenDialog: true)` y `ConViewModel`; la pantalla en el orden de `design.md` (X, título, "¿Qué pasó?", `RadioGroup` con `RadioListTile`, error de tipo en `liveRegion`, Título, Descripción, "¿Dónde?" con R11/R12, Dirección, error de envío en `liveRegion`, "Enviar alerta", "Cancelar"); controladores y `FocusNode` en el `State` con `dispose`; foco al `primerError`; `PopScope` y confirmación de descarte; al crear, `pop` y aviso con el `ScaffoldMessenger` tomado antes del `await`. Cubre: R5, R7, R8, R9, R10, R11, R12, R20, R22, R23, R24, R25, R26, R27, R28, R29, R32, R33, R34, R36, R37, R38, R39, R46, R47, R49, R50.
- [x] T16 — Pruebas de widgets en `test/widget_test.dart`, grupo `Reportar alerta` (pantalla empujada sobre una base, con `AlertasFalsas`): `muestra los cuatro tipos sin ninguno elegido y los campos vacíos`; `elegir "Robo" completa el título con "Robo"`; `el vecino puede cambiar el título`; `con ubicación exacta dice "Vamos a mandar tu ubicación exacta."`; `sin ubicación exacta dice "Vamos a mandar la zona del barrio, no tu ubicación exacta."`. Cubre: R6, R7, R8, R10, R11, R12.
- [x] T17 — Pruebas en el mismo grupo — envío: `enviar cierra el formulario y muestra "Reportaste la alerta. Ya aparece en la lista y el mapa."`; `mientras envía, "Enviar alerta" está deshabilitado con "Enviando la alerta" y Atrás no cierra` (servicio con demora controlada por un `Completer`). Cubre: R20, R22, R23.
- [x] T18 — Pruebas en el mismo grupo — errores: `enviar vacío muestra "Elegí qué tipo de alerta es." y "Escribí un título para la alerta." y lleva el foco al primer tipo`; `un título de 61 letras muestra "Acortá el título: puede tener hasta 60 letras." y lleva el foco al Título`; `descripción y dirección largas muestran sus mensajes`; `si la API rechaza, el formulario muestra el mensaje y conserva tipo, título, descripción y dirección`; `sin conexión el formulario muestra el error de red y conserva lo escrito`. Cubre: R24, R25, R26, R27, R28, R29, R32, R33, R34.
- [x] T19 — Pruebas en el mismo grupo — cerrar: `la X sin datos cierra sin preguntar`; `"Cancelar" con un tipo elegido pide "¿Descartar la alerta?"`; `Atrás con texto escrito pide "¿Descartar la alerta?"`; `"Sí, descartar" cierra sin crear ninguna alerta`; `"Seguir escribiendo" vuelve con todo lo escrito`; `tocar fuera del diálogo vuelve con todo lo escrito`. Cubre: R36, R37, R38, R39.
- [x] T20 — Prueba en `test/widget_test.dart`, grupo `Sin conexión`: `el formulario de reportar alerta conserva lo escrito al volver la conexión` (mismo armado que `el texto escrito en el login sigue al volver`). Cubre: R35.

## Inicio

- [x] T21 — En `lib/ui/inicio/widgets/inicio_screen.dart`: debajo de la tarjeta del mapa, `FilledButton.icon` "Reportar alerta" (`Icons.add_alert_outlined`) que llama a `ReportarAlertaScreen.abrir(context, dependencias)`; "Llamar al 911" sin `Align`; 12 dp entre cada uno; comentario del porqué del alto (R4). Cubre: R1, R2, R3, R4, R5.
- [x] T22 — Pruebas en `test/widget_test.dart`, grupo `Inicio: reportar alerta` (app con `appDePrueba`): `"Reportar alerta" está debajo del mapa y arriba de "Llamar al 911"` (comparando `getTopLeft`/`getBottomLeft`); `"Reportar alerta" y "Llamar al 911" tienen el ancho de la tarjeta del mapa`; `los dos botones son más bajos que el botón SOS`; `"Reportar alerta" abre el formulario`; `una alerta reportada aparece en "Alertas cerca tuyo" y en el mapa` (servidor simulado: reportar, volver al inicio, buscar la `TarjetaAlerta` con el título y el pin `Alerta: <título>` en la pestaña Mapa). Cubre: R1, R2, R3, R4, R5, R19, R21.
- [x] T23 — Prueba en `test/widget_test.dart`: `una alerta de arrebato guardada se ve con su título y el ícono de arrebato` (`TarjetaAlerta` con una alerta `categoria: arrebato`, `tipo: 'Arrebato'`: `find.text('Arrebato')` y `find.byIcon(Icons.phone_android)`). Cubre: R42.

## Botón SOS (pedido en la aprobación)

- [x] T24 — En `lib/ui/core/widgets/boton_sos.dart`: `anchoMinimo = 216.0`, `altoMinimo = 104.0`, `_tamanioTexto = 32.0`, `Icon(Icons.campaign, size: 36)`; relleno, forma, colores, etiqueta y acción sin cambios; el comentario de la clase dice "mínimo 216x104 dp". No tocar los 140 dp de relleno de Inicio, Turnos y Perfil ni `MapaScreen._margenMapa` (ya usa `altoActual`). Cubre: R51, R52, R53.
- [x] T25 — Pruebas en `test/widget_test.dart`, grupo `Botón SOS` (app con `appDePrueba`, pantalla de 360 dp de ancho, texto al 100 %): `el SOS mide 216 x 104 dp con el texto "SOS" en 32` (`tester.getSize(find.byType(BotonSos))` igual a `Size(216, 104)`; el `Text` "SOS" descendiente de `BotonSos` con `style.fontSize` 32); `BotonSos.altoActual es 104 al 100 % y al 200 %` (un `Builder` dentro de `MediaQuery` con `TextScaler.linear(1)` y `TextScaler.linear(2)`); en `Inicio: reportar alerta`, `los dos botones son más bajos que el botón SOS` compara contra el SOS nuevo (52 < 104). Cubre: R4, R51, R52.
- [x] T26 — Pruebas en `test/accesibilidad_test.dart`, grupo `Botón SOS`: `al 200 % en 360 dp el SOS mide al menos 104 de alto y entra en la pantalla sin desbordes` (`configurarPantalla(tester, alto: 640, escalaTexto: 2.0)`, `ingresar`; `tester.takeException()` es null; `getRect(find.byType(BotonSos))` con `height >= 104`, `left >= 0` y `right <= 360`); `al 200 % en 360 x 640 el mapa y la última alerta del inicio se pueden ver enteros por encima del SOS` (con `tester.ensureVisible` sobre la `TarjetaTocable` del mapa del inicio, su `getRect().bottom` es `<=` `getRect(find.byType(BotonSos)).top`; después `scrollUntilVisible` hasta el final de la lista y el `bottom` de la última `TarjetaAlerta` es `<=` el `top` del SOS). Las entradas `Inicio`, `Turnos`, `Mapa` y `Perfil` de `Guías de accesibilidad` y `Texto del sistema al 200 %` tienen que seguir verdes con el SOS nuevo. Cubre: R52, R53.

## Accesibilidad

- [x] T27 — En `test/accesibilidad_test.dart`: cambiar `RegExp('^Alerta: Arrebato')` por `RegExp('^Alerta: Robo de celular')`; agregar a `pantallas` las entradas `Reportar alerta`, `Reportar alerta con errores` (después de tocar "Enviar alerta" vacío) y `Descartar la alerta (diálogo)` (corren con las guías de 48 dp, etiquetas y contraste, y al 200 %); la entrada `Inicio` ya cubre el botón nuevo. Cubre: R45, R48.
- [x] T28 — Pruebas en `test/accesibilidad_test.dart`: `los tipos se anuncian con su nombre y si están elegidos y los campos con su nombre` (`tester.getSemantics`, flags `isInMutuallyExclusiveGroup`/`isChecked`); `los errores de tipo y de envío son regiones en vivo con ícono`; `el formulario se lee en orden` (recorrer el árbol de semántica en `DebugSemanticsDumpOrder.traversalOrder` y comprobar el orden relativo de las etiquetas de R49); `con el teclado abierto y el texto al 200 % se llega a "Enviar alerta" y se puede tocar` (`tester.view.viewInsets` con 300 dp abajo). Cubre: R46, R47, R49, R50.

## Backend

- [x] T29 — En `backend/lib/src/reglas.dart`: `ReglasAlertas` con las mismas constantes, mensajes y `motivoRechazo` que la app; `categorias` sin `arrebato`. Cubre: R30, R40.
- [x] T30 — Pruebas en `backend/test/reglas_test.dart`, grupo `ReglasAlertas`: mismos casos que T5 con los mismos mensajes. Cubre: R30, R40.
- [x] T31 — En `backend/lib/src/api.dart`: `_crearAlerta` responde 400 con `ReglasAlertas.motivoRechazo` (antes de validar la ubicación, como hoy la categoría); borrar `Api._categorias`. En `backend/lib/src/datos_de_ejemplo.dart`: `a4` pasa a `robo` / "Robo de celular". En `backend/README.md`: categorías aceptadas, obligatorios y máximos de `POST /alertas`. Cubre: R19, R30, R40, R43, R44.
- [x] T32 — Pruebas en `backend/test/api_test.dart`: `rechaza una alerta nueva de arrebato con "Elegí qué tipo de alerta es."` (400 y cuerpo); `rechaza un título vacío, un título de 61 letras, una descripción de 501 y una dirección de 121 con los mensajes de la app`; `una alerta nueva de actividad sospechosa queda activa`; `una alerta de arrebato guardada se sigue leyendo en GET /alertas` (`Almacen` armado con una alerta `arrebato`); `los datos de ejemplo no tienen alertas de arrebato y a4 es "Robo de celular"`. Cubre: R19, R30, R40, R41, R43, R44.

## Cierre

- [x] T33 — Trazabilidad `R1`…`R53` → prueba en `progress/impl_reportar_alerta.md`.
- [x] T34 — `./init.sh` verde.
