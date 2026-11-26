# Spec bloqueado — quitar_arrebato (feature 17)

> Autor: spec_author. Rama: `feature/quitar_arrebato`.

## Motivo del bloqueo

El primer criterio del `acceptance` choca con el código actual:

> "Al reportar una alerta, Arrebato ya no aparece entre los tipos para elegir"

**En la app no hay ninguna pantalla donde se elija el tipo de alerta.** El
único camino para crear una alerta es el botón SOS:
`lib/ui/sos/view_models/sos_view_model.dart` llama a
`AlertasRepository.crearAlerta` con `categoria: CategoriaAlerta.sos` y
`tipo: 'Pedido de ayuda (SOS)'` fijos. No hay selector, lista ni formulario
de reporte que recorra `CategoriaAlerta.values` (busqué `crearAlerta`,
`CategoriaAlerta.`, `Dropdown`, `ChoiceChip`, `SegmentedButton`,
`RadioListTile`, "reportar" y "elegí" en `lib/`). Las alertas de las demás
categorías (robo, vehículo, arrebato…) salen solo de los datos de ejemplo
del backend y del servidor simulado.

Por eso el criterio no se puede verificar con una prueba tal como está
escrito: la pantalla que menciona no existe. Para seguir hace falta que el
equipo (Leandro por el lado del cliente) elija una de estas opciones:

1. **Reinterpretarlo:** "La app no ofrece ninguna forma de crear una alerta
   de arrebato". Hoy ya se cumple. Se verificaría con una prueba de que el
   SOS crea con `sos` y con una prueba de dominio sobre una lista explícita
   de categorías que se pueden reportar (`CategoriaAlerta.paraReportar`, sin
   arrebato). La lista no la usaría ninguna pantalla todavía, quedaría
   lista para un formulario futuro. Hay que reescribir el criterio en
   `feature_list.json`.
2. **Agregar primero el formulario de reporte** con selector de tipo, como
   una feature aparte (pantalla nueva, Carla). Recién después se hace la
   feature 17 o se le suma este criterio.
3. **Sacar el criterio** y dejar la feature 17 solo en backend, datos de
   ejemplo y lectura de alertas viejas.

No elijo yo porque cada opción cambia el alcance, y la regla es no inventar
requisitos que el `acceptance` no respalda.

## Análisis previo de los demás puntos (para cuando se destrabe)

Ninguno de estos puntos bloquea. Lo dejo acá para no tener que volver a
leer el código.

- **Alertas de arrebato que ya existen (servidor, caché sqflite, push).**
  `CategoriaAlerta.desdeApi` usa `orElse: () => sos`: si se borra el valor
  `arrebato` del enum, una alerta vieja se leería como SOS, con ícono de
  megáfono y, en `notificaciones_service.dart:104`, con trato de SOS. Eso
  no cumple "se siguen viendo" con su ícono actual. Propuesta: **el valor
  `arrebato` queda en el enum solo para leer** (sigue en `desdeApi`,
  `fromJson`/`fromMap` y en `PresentacionCategoria.icono` →
  `Icons.phone_android`). El texto visible ya sale de `alerta.tipo`
  ("Arrebato"), no del enum. La caché local no cambia de esquema.
  Alternativa descartada: mapearla a `robo`, porque cambia ícono y nombre
  corto.
- **API ante `POST /alertas` con `categoria: arrebato`.** `_crearAlerta`
  (`backend/lib/src/api.dart:250`) ya responde
  `ErrorDeApi.datosInvalidos('Elegí qué tipo de alerta es.')` (400) cuando
  la categoría no está en `_categorias`. Se saca `'arrebato'` del set y la
  respuesta queda igual a la de cualquier categoría inválida: 400 con
  `{"error": "Elegí qué tipo de alerta es."}`. El GET y el PATCH de estado
  no validan categoría, así que una alerta vieja de arrebato se sigue
  pudiendo leer y cambiar de estado. Hay que actualizar la lista de
  categorías en `backend/README.md` si figura (hoy la fila de
  `POST /alertas` no las enumera).
- **Servidor simulado.** `ServidorSimulado.crearAlerta` no valida la
  categoría. Para que quede igual a la API habría que agregarle el rechazo
  con el mismo mensaje (`ErrorDelServidor('Elegí qué tipo de alerta es.')`).
- **Informe (feature 14).** `lib/domain/informe_alertas.dart` agrupa por
  `alerta.tipo` (texto), no por categoría: un mes con arrebatos sigue
  mostrando la fila "Arrebato" con su cantidad. No hace falta cambiar nada.
  Las pruebas `test/unit/dominio_test.dart:299` y `:330` arman alertas en
  memoria con `tipo: 'Arrebato'` y siguen valiendo.
- **Aviso tardío (feature 16).** `nombreCorto` devuelve `null` para
  arrebato y `tipoParaAviso` cae en `alerta.tipo`, así que un aviso tardío
  de un arrebato viejo dice "Arrebato de Marta 15:10". Como el valor queda
  en el enum, el `switch` exhaustivo sigue compilando y la prueba
  `test/unit/avisos_tardios_test.dart:85` sigue valiendo. No cambia nada.
- **Datos de ejemplo.** La alerta `a4` (`categoria: 'arrebato'`,
  "Le sacaron el celular…", resuelta, de `clara`) está en
  `backend/lib/src/datos_de_ejemplo.dart:193` y en
  `lib/data/services/simulados/servidor_simulado.dart:458`. Propuesta:
  reemplazarla por una de `robo` con `tipo: 'Robo de celular'`, misma
  ubicación, estado y autora, así la cantidad de alertas y los estados no
  cambian.
- **Pruebas que dependen de `a4`.** `test/accesibilidad_test.dart:177`
  busca el marcador `RegExp('^Alerta: Arrebato')` en el mapa y hay que
  cambiarlo por el `tipo` nuevo. En `backend/test/` no encontré referencias
  a `a4` ni a arrebato.
- **Paquetes nuevos:** ninguno.
