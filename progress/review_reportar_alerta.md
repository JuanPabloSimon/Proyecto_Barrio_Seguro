# Review — feature 18 (reportar_alerta)

**Veredicto:** APPROVED

Revisado sobre el trabajo sin commitear de `feature/reportar_alerta`
(spec aprobado en 04313e1). Se leyeron `git diff`, los archivos nuevos
(`lib/domain/reglas_alertas.dart`, `lib/ui/core/ubicacion_de_alerta.dart`,
`lib/ui/reportar_alerta/**`) y cada prueba citada en la trazabilidad.

## Trazabilidad

- R1: [x] `test/widget_test.dart` › Inicio: reportar alerta › "Reportar alerta" está debajo del mapa y arriba de "Llamar al 911" (compara `getTopLeft`/`getBottomLeft` contra la `TarjetaTocable` del mapa y el `OutlinedButton`).
- R2: [x] `test/widget_test.dart` › Inicio: reportar alerta › "Reportar alerta" y "Llamar al 911" tienen el ancho de la tarjeta del mapa (ancho y `dx` iguales).
- R3: [x] la misma prueba de R2.
- R4: [x] `test/widget_test.dart` › Inicio: reportar alerta › los dos botones son más bajos que el botón SOS (52 y 52 < 104).
- R5: [x] `test/widget_test.dart` › Inicio: reportar alerta › "Reportar alerta" abre el formulario (pantalla nueva, X "Cerrar", el inicio queda tapado).
- R6: [x] `test/unit/dominio_test.dart` › Tipos para reportar › los tipos para reportar son … sin arrebato; `test/unit/view_models_test.dart` › ofrece los cuatro tipos …; `test/widget_test.dart` › Reportar alerta › muestra los cuatro tipos … (orden exacto y sin "Arrebato").
- R7: [x] `test/widget_test.dart` › Reportar alerta › muestra los cuatro tipos sin ninguno elegido y los campos vacíos; `view_models_test.dart` › arranca sin tipo elegido.
- R8: [x] `view_models_test.dart` › elegir un tipo con el título vacío sugiere su nombre / elegir otro tipo cambia la sugerencia si el título no se tocó; `widget_test.dart` › elegir "Robo" completa el título con "Robo" (y Ruidos lo cambia).
- R9: [x] `view_models_test.dart` › elegir otro tipo conserva el título que escribió el vecino; `widget_test.dart` › el vecino puede cambiar el título.
- R10: [x] `widget_test.dart` › Reportar alerta › el vecino puede cambiar el título.
- R11: [x] `view_models_test.dart` › con GPS y ubicación exacta activada conUbicacionExacta es true; `widget_test.dart` › con ubicación exacta dice "Vamos a mandar tu ubicación exacta."
- R12: [x] `view_models_test.dart` › sin GPS o sin la preferencia conUbicacionExacta es false; `widget_test.dart` › sin ubicación exacta dice "Vamos a mandar la zona del barrio, …"
- R13: [x] `view_models_test.dart` › envía la posición del GPS y "Ubicación exacta del vecino" si la dirección está vacía.
- R14: [x] `view_models_test.dart` › si el GPS no responde envía Barrio.centro … / sin la preferencia envía Barrio.centro (incluye sin GPS y verifica que no se pidió posición).
- R15: [x] `view_models_test.dart` › la dirección escrita viaja sin espacios en los extremos.
- R16: [x] las dos pruebas de R13 y R14 (dirección "Ubicación exacta del vecino" / "Barrio Soberanía (zona aproximada)").
- R17: [x] `view_models_test.dart` › enviar crea la alerta con la categoría elegida, el título y la descripción recortados y el id del vecino.
- R18: [x] `view_models_test.dart` › enviar con la descripción vacía crea la alerta.
- R19: [x] `test/unit/repositorios_test.dart` › Alertas contra el servidor simulado › una alerta nueva del servidor simulado queda activa; `backend/test/api_test.dart` › una alerta nueva de actividad sospechosa queda activa; `widget_test.dart` › una alerta reportada aparece … (estado `activa`).
- R20: [x] `widget_test.dart` › Reportar alerta › enviar cierra el formulario y muestra "Reportaste la alerta. …".
- R21: [x] `widget_test.dart` › Inicio: reportar alerta › una alerta reportada aparece en "Alertas cerca tuyo" y en el mapa (servidor simulado, `TarjetaAlerta` y pin `Alerta: Auto gris dando vueltas` sin recargar); `view_models_test.dart` › enviar publica AlertasActualizadas y devuelve true.
- R22: [x] `view_models_test.dart` › mientras envía enviando es true; `widget_test.dart` › mientras envía, "Enviar alerta" está deshabilitado con "Enviando la alerta" y Atrás no cierra.
- R23: [x] la misma prueba de widgets (X y "Cancelar" con `onPressed` null; `handlePopRoute` no cierra ni pregunta).
- R24: [x] `dominio_test.dart` › ReglasAlertas › motivoRechazo …; `view_models_test.dart` › sin tipo marca el error de tipo y no llama a crearAlerta; `widget_test.dart` › enviar vacío muestra "Elegí qué tipo de alerta es." …
- R25: [x] `dominio_test.dart` › un título vacío o solo con espacios no pasa; `view_models_test.dart` › título vacío y descripción larga …; `widget_test.dart` › enviar vacío muestra … "Escribí un título para la alerta."
- R26: [x] `dominio_test.dart` › un título de 60 letras pasa y uno de 61 no / los espacios de los extremos no cuentan; `view_models_test.dart` › un título de 61 letras marca su error; `widget_test.dart` › un título de 61 letras muestra … y lleva el foco al Título.
- R27: [x] `dominio_test.dart` › una descripción de 500 letras pasa y una de 501 no; `widget_test.dart` › descripción y dirección largas muestran sus mensajes.
- R28: [x] `dominio_test.dart` › una dirección de 120 letras pasa y una de 121 no; `view_models_test.dart` › dirección larga marca su error; `widget_test.dart` › descripción y dirección largas …
- R29: [x] `view_models_test.dart` › `primerError` (tipo, titulo, direccion); `widget_test.dart` › foco al primer tipo (`hasPrimaryFocus`), al Título y a Descripción (`hasFocus`).
- R30: [x] `backend/test/api_test.dart` › rechaza un título vacío, un título de 61 letras, una descripción de 501 y una dirección de 121 con los mensajes de la app (400 con el cuerpo de error exacto, y 201 en el límite); `backend/test/reglas_test.dart` › ReglasAlertas.
- R31: [x] `repositorios_test.dart` › el servidor simulado rechaza una alerta de arrebato … / rechaza un título vacío con el mismo mensaje que la API (también descripción 501 y dirección 121, `ErrorDelServidor` con el mensaje).
- R32: [x] `view_models_test.dart` › si la API rechaza muestra su mensaje tal cual; `widget_test.dart` › si la API rechaza, el formulario muestra el mensaje y conserva …
- R33: [x] `view_models_test.dart` › sin conexión muestra "No pudimos enviar la alerta. …"; `widget_test.dart` › sin conexión el formulario muestra el error de red y conserva lo escrito.
- R34: [x] `widget_test.dart` › las dos pruebas de R32/R33 (`conservaLoEscrito`: tipo, título, descripción y dirección); `view_models_test.dart` › si falla, el tipo elegido sigue elegido.
- R35: [x] `widget_test.dart` › Sin conexión › el formulario de reportar alerta conserva lo escrito al volver la conexión (compuerta real, tipo, título y descripción).
- R36: [x] `widget_test.dart` › la X sin datos cierra sin preguntar; `view_models_test.dart` › hayDatos … (ver observación 1).
- R37: [x] `widget_test.dart` › "Cancelar" con un tipo elegido pide … / Atrás con texto escrito pide …
- R38: [x] `widget_test.dart` › "Sí, descartar" cierra sin crear ninguna alerta.
- R39: [x] `widget_test.dart` › "Seguir escribiendo" vuelve con todo lo escrito (incluye Atrás en el diálogo) / tocar fuera del diálogo vuelve con todo lo escrito.
- R40: [x] `backend/test/api_test.dart` › rechaza una alerta nueva de arrebato con "Elegí qué tipo de alerta es." (400, cuerpo exacto, no se guarda ni manda push); `backend/test/reglas_test.dart` › rechaza arrebato …
- R41: [x] `backend/test/api_test.dart` › una alerta de arrebato guardada se sigue leyendo en GET /alertas (y acepta PATCH).
- R42: [x] `dominio_test.dart` › una alerta de arrebato de la API se lee como arrebato (`fromJson` y `fromMap`); `widget_test.dart` › una alerta de arrebato guardada se ve con su título y el ícono de arrebato (`Icons.phone_android`).
- R43: [x] `repositorios_test.dart` › los datos del servidor simulado no tienen alertas de arrebato y a4 es "Robo de celular"; `backend/test/api_test.dart` › los datos de ejemplo no tienen alertas de arrebato …
- R44: [x] las mismas dos pruebas (categoría, título, descripción, dirección, latitud, longitud, `resuelta`, `clara`).
- R45: [x] `test/accesibilidad_test.dart` › Guías de accesibilidad › Inicio / Reportar alerta / Reportar alerta con errores / Descartar la alerta (diálogo).
- R46: [x] `accesibilidad_test.dart` › Reportar alerta › los tipos se anuncian con su nombre y si están elegidos y los campos con su nombre (`isInMutuallyExclusiveGroup`, `isChecked`, `isTextField`, etiqueta).
- R47: [x] `accesibilidad_test.dart` › Reportar alerta › los errores de tipo y de envío son regiones en vivo con ícono (`liveRegion`, `Icons.error_outline` y flag `isLiveRegion`).
- R48: [x] `accesibilidad_test.dart` › Texto del sistema al 200 % › Inicio / Reportar alerta / Reportar alerta con errores / Descartar la alerta (diálogo).
- R49: [x] `accesibilidad_test.dart` › Reportar alerta › el formulario se lee en orden (recorre `traversalOrder` y compara posiciones de las 12 etiquetas).
- R50: [x] `accesibilidad_test.dart` › Reportar alerta › con el teclado abierto y el texto al 200 % se llega a "Enviar alerta" y se puede tocar (`viewInsets` 300 dp, `hitTestable`, se crea la alerta).
- R51: [x] `widget_test.dart` › Botón SOS › el SOS mide 216 x 104 dp con el texto "SOS" en 32 (360 dp, `getSize` exacto y `fontSize` 32).
- R52: [x] `accesibilidad_test.dart` › Botón SOS › al 200 % en 360 dp el SOS mide al menos 104 de alto y entra en la pantalla sin desbordes; `widget_test.dart` › BotonSos.altoActual es 104 al 100 % y al 200 %.
- R53: [x] `accesibilidad_test.dart` › Botón SOS › al 200 % en 360 x 640 el mapa y la última alerta del inicio se pueden ver enteros por encima del SOS.

## Tasks

- T1 a T34: [x] todas marcadas. El diff de `specs/reportar_alerta/tasks.md` solo cambia `[ ]` por `[x]`. Los desvíos (orden T20/T21, T26 con arrastre hasta `maxScrollExtent`, T28 quitando los `viewInsets` al cerrar) están justificados en `progress/impl_reportar_alerta.md` › Decisiones de implementación.
