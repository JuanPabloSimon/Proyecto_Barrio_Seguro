# Design — reportar_alerta

> Decisiones técnicas tomadas antes de escribir código. Se apoya en
> `docs/architecture.md` y `docs/conventions.md`; acá solo va lo que esta
> feature agrega o donde roza sus límites.

## Punto de partida (código actual, verificado)

- **Inicio** (`lib/ui/inicio/widgets/inicio_screen.dart`, `_ContenidoInicio`):
  un `ListView` con padding horizontal 16. La tarjeta del mapa es una
  `TarjetaTocable` que ocupa todo el ancho. Debajo, "Llamar al 911" es un
  `OutlinedButton.icon` envuelto en `Align(centerLeft)` para que tenga el
  ancho de su texto ("el SOS tiene que ser el botón más grande"). El SOS es
  el `floatingActionButton` de `PrincipalScreen` (`BotonSos`, mínimo
  184 x 88 dp, texto de 30).
- **SOS** (`lib/ui/sos/view_models/sos_view_model.dart`): `enviar()` lee la
  posición con `_ubicacionExacta()` (`capacidades.tieneGps` →
  `preferencias.compartirUbicacion()` → `ubicacion.ubicacionActual()`, y
  `null` ante cualquier falla) y crea la alerta con `Barrio.centro` y la
  dirección "Barrio Soberanía (zona aproximada)" si no hay posición, o con
  la posición y "Ubicación exacta del vecino" si la hay. Publica
  `AlertasActualizadas` en el bus.
- **Repositorio** (`AlertasRepositoryRemoto.crearAlerta`): manda el JSON,
  agrega la alerta a la caché y a la copia local. Si falla, pide una
  comprobación de la conexión cuando el error es de red y relanza el error
  (feature 15: nada queda guardado para después). Un rechazo de la API
  llega como `ErrorDelServidor` con el mensaje para mostrar tal cual.
- **API** (`backend/lib/src/api.dart`, `_crearAlerta`): valida que la
  categoría esté en `_categorias` (hoy incluye `arrebato`) y la ubicación.
  `tipo` es obligatorio como dato (`_texto` sin `opcional`) pero acepta
  `""`; descripción y dirección son opcionales; ningún largo máximo. Guarda
  con `estado: 'activa'`.
- **Servidor simulado** (`ServidorSimulado.crearAlerta`): no valida nada.
- **Compuerta de conexión** (`CompuertaDeConexion`): tapa el `Navigator`
  con `Offstage` sin desmontarlo; al volver la conexión las rutas abiertas
  se ven con su estado. `AtrasSinConexion` se queda con el botón Atrás
  mientras no hay conexión.
- **Inicio y mapa se actualizan solos**: `InicioViewModel` recarga con
  cualquier evento del bus y `MapaViewModel` con `AlertasActualizadas`; el
  repositorio ya agregó la alerta nueva a la caché.

### Verificación del análisis de `progress/spec_quitar_arrebato.md`

Sigue vigente, con dos ajustes:

- La prueba del mapa está en `test/accesibilidad_test.dart:178` (no :177).
- Hay una alerta de arrebato **real** fuera del repositorio:
  `backend/datos/barrio.json` (ignorado por `backend/.gitignore`) la tiene
  porque se creó con los datos de ejemplo viejos. Es justo el caso "las
  alertas de arrebato que ya existen se siguen viendo": `GET /alertas` no
  valida categoría (R41). No se toca ese archivo.

Lo demás se confirma: `CategoriaAlerta.desdeApi` cae en `sos` si el valor
no existe, por eso `arrebato` **queda en el enum solo para leer**;
`informe_alertas.dart` agrupa por `alerta.tipo`; `nombreCorto` devuelve
`null` para arrebato y `tipoParaAviso` usa `alerta.tipo`, así que el aviso
tardío y `test/unit/avisos_tardios_test.dart:85` no cambian; `a4` está en
`backend/lib/src/datos_de_ejemplo.dart:192` y en
`lib/data/services/simulados/servidor_simulado.dart:457`; en
`backend/test/` no hay referencias a `a4` ni a arrebato.

## Decisiones

### 1. Pantalla completa con forma de diálogo, no hoja inferior ni `AlertDialog`

El formulario se abre con `MaterialPageRoute(fullscreenDialog: true)`,
igual que el SOS: `Scaffold` con `AppBar` (X "Cerrar" a la izquierda y el
título "Reportar alerta") y el contenido en un `ListView`.

- Con el texto al 200 % y el teclado abierto, una hoja inferior o un
  `AlertDialog` dejan una franja de pocos centímetros para cuatro campos;
  una pantalla completa usa todo el alto y el `Scaffold`
  (`resizeToAvoidBottomInset`, por defecto) achica el cuerpo por encima
  del teclado, así el `ListView` se desplaza hasta "Enviar alerta" (R50).
- La X y el botón Atrás se comportan como en cualquier pantalla, sin el
  gesto de arrastrar hacia abajo de la hoja, que una persona mayor puede
  hacer sin querer y perder lo escrito.
- "Enviar alerta" y "Cancelar" van **al final del `ListView`**, no en
  `bottomNavigationBar`: con el teclado abierto una barra fija le come
  alto al formulario.

### 2. Tipo y título sugerido

- `CategoriaAlerta.paraReportar` (nuevo) lista los cuatro tipos en el orden
  del `acceptance`. El nombre visible es `nombreCorto` (feature 16), que
  ya dice "Actividad sospechosa", "Vehículo sospechoso", "Robo" y
  "Ruidos": un solo lugar para el nombre.
- Arranca sin tipo elegido (R7): un tipo preelegido se mandaría sin que el
  vecino lo mire.
- Al elegir un tipo, el título se completa con su nombre si está vacío o
  si todavía es la sugerencia del tipo anterior (R8). Si el vecino lo
  cambió, se respeta (R9). La regla vive en el ViewModel
  (`tituloAlElegir`) para probarla sin pantalla.

### 3. Validaciones: las mismas en la app y el backend

Como las reglas de turnos (principio 6), se duplican a propósito en
`lib/domain/reglas_alertas.dart` y `backend/lib/src/reglas.dart` con los
mismos mensajes. Se cuentan **letras** como `texto.trim().runes.length`,
igual en Flutter y en Dart puro (sin el paquete `characters`).

| Campo | Obligatorio | Máximo | Mensaje |
|---|---|---|---|
| Tipo (`categoria`) | sí | — | "Elegí qué tipo de alerta es." |
| Título (`tipo`) | sí | 60 | "Escribí un título para la alerta." / "Acortá el título: puede tener hasta 60 letras." |
| Descripción | no | 500 | "Acortá la descripción: puede tener hasta 500 letras." |
| Dirección | no | 120 | "Acortá la dirección: puede tener hasta 120 letras." |

- Descripción y dirección son opcionales porque escribir con el teclado
  del teléfono es lo más difícil para una persona mayor: el tipo y el
  título ya dicen qué pasa, y la posición va sola.
- Orden de chequeo: categoría, título, descripción, dirección. El backend
  responde el primer motivo; la app muestra todos los errores de campo a
  la vez (es más fácil corregir de una).
- En el backend la validación aplica a **todo** `POST /alertas`, también
  al SOS: "Intento de robo" (15 letras) y "Un vecino pidió ayuda con el
  botón SOS." pasan. La categoría `sos` sigue aceptada en la API y en el
  simulado (la crea el botón SOS), pero no está en `paraReportar`.
- Los campos usan `maxLength` con `MaxLengthEnforcement.none`: se ve el
  contador ("12/60") y el vecino puede pegar o seguir escribiendo; el
  error sale de la regla al enviar, no de un corte silencioso.

### 4. Ubicación compartida con el SOS

La lógica de `_ubicacionExacta()` del SOS se mueve a
`lib/ui/core/ubicacion_de_alerta.dart` (`UbicacionDeAlerta`) y la usan los
dos ViewModels. `SosViewModel` no cambia de firma: arma la
`UbicacionDeAlerta` en su constructor con lo que ya recibe. Las pruebas
actuales del SOS (`test/unit/view_models_test.dart` › `SosViewModel`,
`test/unit/ubicacion_test.dart`) aseguran que no cambia nada.

- Al abrir el formulario, `cargar()` pregunta `compartePosicionExacta()`
  (GPS + preferencia) para el texto de R11/R12. Mientras no respondió se
  muestra el de la zona (R12), que nunca promete de más.
- La posición se lee **al enviar** (como el SOS), así es la de ese
  momento. Si el GPS no responde a tiempo, va `Barrio.centro` (R14).
- La dirección escrita viaja tal cual (sin espacios en los extremos); si
  está vacía, se usa la misma que el SOS (R16).

### 5. Cerrar con datos escritos

Si hay tipo elegido o algún campo con texto (sin contar espacios), la X,
"Cancelar" y el botón Atrás muestran `confirmarDescarte`:

- Título "¿Descartar la alerta?", texto "Todavía no la enviaste. Si
  salís, se borra lo que escribiste."
- `OutlinedButton` "Seguir escribiendo" (devuelve `false`) y
  `FilledButton` "Sí, descartar" (devuelve `true`). Atrás o tocar fuera
  devuelven `false` (R39).
- Mismo armado que `confirmarCierreSos`: `AlertDialog(scrollable: true,
  actionsOverflowButtonSpacing: 8)`, botones con `minimumSize: Size(0, 48)`.

Mientras se envía, no se puede cerrar (R23): `PopScope(canPop: false)` y la
X y "Cancelar" deshabilitados.

### 6. Sin conexión

- Si la conexión se corta con el formulario abierto, la compuerta lo tapa
  sin desmontarlo: los `TextEditingController` y el tipo viven en el
  `State` y en el ViewModel, así que al volver se ve todo (R35). No hace
  falta código nuevo, solo la prueba.
- Si el envío falla por la red, el repositorio pide la comprobación y
  relanza; el ViewModel muestra "No pudimos enviar la alerta. Revisá tu
  conexión y probá de nuevo." (R33) y no borra nada (R34). Si la compuerta
  aparece, al volver se ve el formulario con el error y lo escrito; el
  vecino toca "Enviar alerta" de nuevo. Nada se guarda para después.
- Si la API rechaza (`ErrorDelServidor`), se muestra su mensaje (R32).

### 7. Botones del inicio y "el SOS es el más grande"

El `acceptance` pide "Reportar alerta" y "Llamar al 911" de ancho completo.
En un teléfono de 360 dp eso da 328 x 52 dp, más área que el SOS de hoy
(184 x 88). La regla de arquitectura se cumple por **alto y peso visual**
y, como pidió el equipo en la aprobación, **el SOS crece un poco** ("un
poco más grande que hoy, pero no tanto"):

| | Hoy | Con esta feature |
|---|---|---|
| Alto mínimo (`BotonSos.altoMinimo`) | 88 dp | **104 dp** (+18 %) |
| Ancho mínimo (`BotonSos.anchoMinimo`) | 184 dp | **216 dp** (+17 %, proporcional: 184 x 104 / 88 ≈ 217, redondeado a múltiplo de 8) |
| Texto "SOS" (`_tamanioTexto`) | 30 | **32** |
| Ícono `Icons.campaign` | 34 | **36** |
| Relleno | 28 horizontal, 12 vertical | sin cambios |
| Forma | `StadiumBorder` rojo con borde blanco de 4 y `elevation: 6` | sin cambios |

- Los dos botones anchos usan el alto del tema (52 dp, texto de 16): el
  SOS mide el doble de alto, con texto del doble de tamaño, relleno rojo y
  sombra. R4 lo verifica con alturas y R51 con los valores exactos.
- **Por qué no más.** Con 104 dp el SOS tapa 120 dp abajo de cada pestaña
  (104 + 16 de separación del `Scaffold`). Las listas de Inicio, Turnos y
  Perfil ya dejan 140 dp de relleno abajo
  (`EdgeInsets.fromLTRB(16, …, 16, 140)`), así que lo último se sigue
  pudiendo llevar por encima del SOS **sin tocar esos rellenos** (quedan
  20 dp libres). Un SOS de 120 dp o más obligaría a cambiar los tres.
- **Texto al 200 %.** `altoActual` da `32 x 2 x 1,2 + 24 = 100,8`, menor
  que 104: el SOS no crece de alto con el texto al 200 % y los 140 dp
  siguen alcanzando (R53). A lo ancho, con la fuente de las pruebas
  (cada letra mide 1 em), "SOS" a 64 da 192 dp y el botón
  `56 + 36 + 10 + 192 = 294` dp, dentro de los 360 dp (R52). Con la
  fuente real es más angosto.
- **Mapa del inicio.** En 360 x 640 dp el cuerpo de la pestaña mide
  640 - 56 (`AppBar`) - 80 (`NavigationBar`) = 504 dp; el SOS ocupa los
  120 de abajo y quedan 384 dp libres arriba. La tarjeta del mapa (150 dp
  del mapa + la fila "Abrir el mapa de alertas", unos 70 dp al 200 %)
  entra entera arriba del SOS cuando se la desplaza al principio de la
  lista (R53).
- **Pestaña Mapa.** `MapaScreen._margenMapa` ya usa
  `BotonSos.altoActual(context)`: el encuadre deja libre el alto nuevo sin
  cambios. Los botones de zoom están arriba a la derecha (`top: 12`), no
  chocan con el SOS más ancho.
- "Reportar alerta": `FilledButton.icon` con `Icons.add_alert_outlined`,
  color primario (no rojo: no es una emergencia).
- "Llamar al 911": el mismo `OutlinedButton.icon` rojo de hoy, sin el
  `Align`. Dentro del `ListView` los dos toman el ancho de la tarjeta del
  mapa.
- Separación de 12 dp entre mapa, "Reportar alerta" y "Llamar al 911".

## Archivos a crear o cambiar

| Capa | Archivo | Cambio |
|---|---|---|
| domain | `lib/domain/models/alerta.dart` | `CategoriaAlerta.paraReportar`; comentario en `arrebato` ("solo para leer alertas viejas") |
| domain | `lib/domain/reglas_alertas.dart` (nuevo) | `ReglasAlertas`: máximos, mensajes, `categoriasAceptadas`, `errorTitulo`, `errorDescripcion`, `errorDireccion`, `motivoRechazo` |
| domain | `lib/domain/avisos_tardios.dart` | Solo el comentario de `nombreCorto` (arrebato queda para leer) |
| data | `lib/data/services/simulados/servidor_simulado.dart` | `crearAlerta` valida con `ReglasAlertas.motivoRechazo`; `a4` pasa a `robo` / "Robo de celular" |
| ui | `lib/ui/core/ubicacion_de_alerta.dart` (nuevo) | `UbicacionDeAlerta` y las constantes de dirección |
| ui | `lib/ui/sos/view_models/sos_view_model.dart` | Usa `UbicacionDeAlerta`; misma firma y comportamiento |
| ui | `lib/ui/reportar_alerta/view_models/reportar_alerta_view_model.dart` (nuevo) | `ReportarAlertaViewModel` |
| ui | `lib/ui/reportar_alerta/widgets/reportar_alerta_screen.dart` (nuevo) | `ReportarAlertaScreen` con `abrir(context, dependencias)` |
| ui | `lib/ui/reportar_alerta/widgets/confirmar_descarte.dart` (nuevo) | `confirmarDescarte(context)` |
| ui | `lib/ui/inicio/widgets/inicio_screen.dart` | Botón "Reportar alerta"; "Llamar al 911" sin `Align` |
| ui | `lib/ui/core/widgets/boton_sos.dart` | `anchoMinimo` 216, `altoMinimo` 104, `_tamanioTexto` 32, ícono 36; comentario de la clase con "mínimo 216x104 dp" (decisión 7) |
| armado | `lib/dependencias.dart` | Sin cambios: `ReportarAlertaScreen.abrir` arma el ViewModel con `Dependencias` (como `DetalleAlertaScreen.abrir`) |
| backend | `backend/lib/src/reglas.dart` | `ReglasAlertas` con las mismas constantes y mensajes; `categorias` sin `arrebato` |
| backend | `backend/lib/src/api.dart` | `_crearAlerta` usa `ReglasAlertas.motivoRechazo`; se borra `Api._categorias` |
| backend | `backend/lib/src/datos_de_ejemplo.dart` | `a4` pasa a `robo` / "Robo de celular" |
| backend | `backend/README.md` | Fila de `POST /alertas`: categorías aceptadas, obligatorios y máximos |
| pruebas | `test/ayudas/falsos.dart` | `AlertasFalsas`: `errorAlCrear` (un `ErrorDelServidor` a lanzar) y registro de los datos de cada `crearAlerta` |
| pruebas | `test/unit/dominio_test.dart`, `test/unit/view_models_test.dart`, `test/unit/repositorios_test.dart`, `test/widget_test.dart`, `test/accesibilidad_test.dart`, `backend/test/api_test.dart`, `backend/test/reglas_test.dart` | Ver `tasks.md` |

## Firmas nuevas

```dart
// lib/domain/models/alerta.dart
enum CategoriaAlerta {
  // … sin cambios en los valores; arrebato queda solo para leer.

  /// Los tipos que el vecino puede elegir en "Reportar alerta", en orden.
  static const paraReportar = [actividadSospechosa, vehiculo, robo, ruidos];
}

// lib/domain/reglas_alertas.dart
class ReglasAlertas {
  ReglasAlertas._();

  static const maxTitulo = 60;
  static const maxDescripcion = 500;
  static const maxDireccion = 120;

  static const mensajeCategoria = 'Elegí qué tipo de alerta es.';
  static const mensajeTituloVacio = 'Escribí un título para la alerta.';
  static const mensajeTituloLargo =
      'Acortá el título: puede tener hasta $maxTitulo letras.';
  static const mensajeDescripcionLarga =
      'Acortá la descripción: puede tener hasta $maxDescripcion letras.';
  static const mensajeDireccionLarga =
      'Acortá la dirección: puede tener hasta $maxDireccion letras.';

  /// Las que acepta el servidor: `sos` (botón SOS) y [CategoriaAlerta.paraReportar].
  static final Set<String> categoriasAceptadas;

  /// Letras sin los espacios de los extremos.
  static int largo(String texto) => texto.trim().runes.length;

  static String? errorTitulo(String titulo);
  static String? errorDescripcion(String descripcion);
  static String? errorDireccion(String direccion);

  /// El primer motivo para rechazar una alerta nueva, o null si es válida.
  /// Lo usa el servidor simulado (y el backend tiene la copia).
  static String? motivoRechazo({
    required String categoria,
    required String tipo,
    required String descripcion,
    required String direccion,
  });
}

// backend/lib/src/reglas.dart — misma API con Strings
class ReglasAlertas {
  static const maxTitulo = 60, maxDescripcion = 500, maxDireccion = 120;
  static const categorias = {'sos', 'actividad_sospechosa', 'vehiculo', 'robo', 'ruidos'};
  // mismos mensajes
  static String? motivoRechazo({
    required String categoria,
    required String tipo,
    required String descripcion,
    required String direccion,
  });
}

// lib/ui/core/ubicacion_de_alerta.dart
const direccionExacta = 'Ubicación exacta del vecino';
const direccionZona = '${Barrio.nombre} (zona aproximada)';

class UbicacionDeAlerta {
  const UbicacionDeAlerta({
    required Capacidades capacidades,
    required Preferencias preferencias,
    required UbicacionService ubicacion,
  });

  /// True si hay GPS y el vecino activó la ubicación exacta. False si
  /// falla la lectura de la preferencia.
  Future<bool> compartePosicionExacta();

  /// La posición del GPS, o null si no comparte, no hay GPS o no responde.
  Future<LatLng?> posicionExacta();
}

// lib/ui/reportar_alerta/view_models/reportar_alerta_view_model.dart
enum CampoReporte { tipo, titulo, descripcion, direccion }

const mensajeAlertaReportada =
    'Reportaste la alerta. Ya aparece en la lista y el mapa.';
const mensajeSinConexionAlReportar =
    'No pudimos enviar la alerta. Revisá tu conexión y probá de nuevo.';

class ReportarAlertaViewModel extends ChangeNotifier {
  ReportarAlertaViewModel({
    required AlertasRepository alertas,
    required SesionRepository sesion,
    required BusDeEventos bus,
    required UbicacionDeAlerta ubicacion,
  });

  List<CategoriaAlerta> get tipos => CategoriaAlerta.paraReportar;
  CategoriaAlerta? get tipo;

  /// Elige [nuevo] y devuelve el título que tiene que quedar en el campo:
  /// el nombre del tipo si [tituloActual] está vacío o es la sugerencia del
  /// tipo anterior; si no, [tituloActual] (R8, R9).
  String tituloAlElegir(CategoriaAlerta nuevo, {required String tituloActual});

  /// R11/R12. False hasta que [cargar] responde.
  bool get conUbicacionExacta;
  Future<void> cargar();

  bool get enviando;
  String? errorDe(CampoReporte campo);
  /// El primero con error, en el orden de [CampoReporte] (R29).
  CampoReporte? get primerError;
  /// R32/R33. null si no hubo error de envío.
  String? get errorDeEnvio;

  /// True si hay tipo elegido o algún texto (sin contar espacios) (R36, R37).
  bool hayDatos({
    required String titulo,
    required String descripcion,
    required String direccion,
  });

  /// Valida; si todo está bien, crea la alerta y publica
  /// AlertasActualizadas. Devuelve true si se creó. Nunca borra el tipo.
  Future<bool> enviar({
    required String titulo,
    required String descripcion,
    required String direccion,
  });
}

// lib/ui/reportar_alerta/widgets/reportar_alerta_screen.dart
class ReportarAlertaScreen extends StatefulWidget {
  const ReportarAlertaScreen({super.key, required this.viewModel});
  final ReportarAlertaViewModel viewModel;

  /// Empuja la pantalla completa con su ViewModel (ConViewModel, ..cargar()).
  static void abrir(BuildContext context, Dependencias dependencias);
}

// lib/ui/reportar_alerta/widgets/confirmar_descarte.dart
/// True solo con "Sí, descartar"; "Seguir escribiendo", Atrás o tocar fuera
/// devuelven false.
Future<bool> confirmarDescarte(BuildContext context);
```

El `State` de `ReportarAlertaScreen` tiene los tres `TextEditingController`
y un `FocusNode` por elemento validable (primer tipo, Título, Descripción,
Dirección), todos liberados en `dispose`. Después de un `enviar` con
errores pide el foco de `primerError`. El `PopScope` escucha
`Listenable.merge([viewModel, controladores…])` para saber si hay datos.
Al crear la alerta toma el `ScaffoldMessenger` **antes** del `await`, hace
`pop` y muestra `mensajeAlertaReportada` con `mostrarAvisoEn`.

## Pantalla (orden de arriba hacia abajo = orden de lectura, R49)

1. `AppBar`: `IconButton` X (`tooltip: 'Cerrar'`), título "Reportar alerta".
2. Encabezado "¿Qué pasó?" (`Semantics(header: true)`).
3. `RadioGroup<CategoriaAlerta>` con un `RadioListTile` por tipo: título
   `nombreCorto`, `secondary: Icon(categoria.icono)` excluido de la
   semántica. El elegido se ve con la marca del radio, no solo con color.
4. Error de tipo (si hay): `Semantics(liveRegion: true)` con
   `Icons.error_outline` y el texto en `AppColors.emergencia`.
5. `TextField` "Título" (`helperText: 'Lo ven tus vecinos en la lista y el
   mapa.'`, `maxLength: 60`, `errorText`, `textInputAction: next`).
6. `TextField` "Descripción (opcional)" (`minLines: 3`, `maxLines: 6`,
   `maxLength: 500`, `keyboardType: multiline`).
7. Encabezado "¿Dónde?" y una fila con ícono (`Icons.my_location` o
   `Icons.location_city`) y el texto de R11 o R12.
8. `TextField` "Dirección o referencia (opcional)" (`helperText: 'Por
   ejemplo: Cabildo de Mendoza y Ascasubi'`, `maxLength: 120`).
9. Error de envío (si hay): `Semantics(liveRegion: true)`, ícono y texto.
10. `FilledButton.icon` "Enviar alerta" (`Icons.send`). Enviando: sin
    `onPressed` y con `CircularProgressIndicator(semanticsLabel: 'Enviando
    la alerta')`.
11. `OutlinedButton` "Cancelar" (igual que la X).

`ListView(padding: EdgeInsets.fromLTRB(16, 8, 16, 24))`, sin alturas fijas.

## API y datos

- `POST /alertas`: mismo cuerpo y respuesta. Errores nuevos, todos 400 con
  `{"error": "<mensaje>"}`: categoría `arrebato` (u otra no aceptada) →
  "Elegí qué tipo de alerta es." (igual que hoy para una inválida); título
  vacío o largo, descripción o dirección largas → mensajes de la tabla.
  La ubicación inválida sigue respondiendo "La ubicación no es válida.".
- `GET /alertas` y `PATCH /alertas/<id>`: sin cambios; no validan
  categoría, así que una alerta de arrebato guardada se lee y cambia de
  estado.
- JSON de los modelos: sin cambios.
- sqflite: sin cambios (la copia local guarda `categoria` como texto y
  `arrebato` se sigue leyendo).
- Datos de ejemplo: `a4` queda con `'categoria': 'robo'`, `'tipo': 'Robo de
  celular'` y el resto igual, en los dos lados. La cantidad de alertas y
  sus estados no cambian.

## Plataforma

Pregunta `Capacidades.tieneGps` (a través de `UbicacionDeAlerta`), igual
que el SOS. La ubicación se pide solo mientras se usa la app (sin cambios
en `UbicacionService`). Nada más depende de la plataforma.

## Accesibilidad

- **48 dp**: botones del tema (52 dp de alto), `RadioListTile` (≥ 56 dp),
  `IconButton` de la X (48 dp), botones del diálogo con `Size(0, 48)`. Se
  verifica con `androidTapTargetGuideline` e `iOSTapTargetGuideline` en
  `test/accesibilidad_test.dart` (R45).
- **Etiquetas**: los campos se anuncian por su `labelText`; los tipos por
  su texto y el estado "elegido" del radio; la X por su `tooltip` (R46).
  `labeledTapTargetGuideline` lo controla.
- **Errores anunciados**: errores de campo en `errorText` (forman parte de
  la semántica del campo y el foco va al primero, R29); error de tipo y de
  envío en `liveRegion` con ícono (R47). Nunca solo color.
- **200 %**: todo en un `ListView`; `RadioListTile` y textos crecen hacia
  abajo; el diálogo es `scrollable` y apila los botones (R48).
- **Teclado**: pantalla completa y botones al final del `ListView` (R50).
- **Botón SOS**: 216 x 104 dp con texto de 32 al 100 % (R51); al 200 %
  sigue con 104 dp de alto, entra en 360 dp de ancho (R52) y no tapa el
  mapa ni la última alerta del inicio, que se pueden desplazar por encima
  (R53). Su etiqueta y su acción de lector de pantalla no cambian.
- **Contraste**: solo colores de `AppColors` ya probados.
- **Animaciones**: la ruta usa las transiciones del tema, que respetan
  "Quitar animaciones".

## Pruebas existentes que cambian

- `test/accesibilidad_test.dart:178`: `RegExp('^Alerta: Arrebato')` pasa a
  `RegExp('^Alerta: Robo de celular')`.
- `backend/test/api_test.dart` › `rechaza una categoría o una ubicación
  inválidas`: sigue pasando (`'tipo': 'x'` es un título válido).
- `test/unit/view_models_test.dart` › `SosViewModel` y
  `test/unit/ubicacion_test.dart`: no cambian; tienen que seguir verdes
  después de mover la lógica a `UbicacionDeAlerta`.
- Pruebas del inicio que buscan `find.text('Llamar al 911')` (accesibilidad
  y sin conexión): siguen encontrando uno solo.
- `test/unit/avisos_tardios_test.dart:85` y `test/unit/dominio_test.dart:299`
  y `:330` (arrebato en memoria): no cambian.
- **Ninguna prueba mide hoy el tamaño del SOS**: no hay `getSize` sobre
  `BotonSos` ni usos de `anchoMinimo`/`altoMinimo` en `test/`. Las que lo
  usan solo lo tocan o leen su semántica (`test/accesibilidad_test.dart`
  › `Botón SOS` y `:220`, `:225`, `:317`, `:461`; `test/widget_test.dart`
  `:191`, `:215`, `:317`, `:371`, `:1023`) y siguen igual. Los grupos
  `Guías de accesibilidad` y `Texto del sistema al 200 %` (entradas
  `Inicio`, `Turnos`, `Mapa`, `Perfil`) pasan a correr con el SOS nuevo.
  `activarConLector` ya contempla que el SOS tape pines del mapa al 200 %.

## Paquetes nuevos

Ninguno. `RadioGroup` es de Flutter (3.47.5 en este equipo).

## Alternativas descartadas

**Hoja inferior (`showModalBottomSheet(isScrollControlled: true)`).** Se
descarta porque con el texto al 200 % y el teclado abierto queda muy poco
alto útil, el gesto de arrastrar hacia abajo la cierra sin querer y el
foco del lector de pantalla se pierde más fácil entre la hoja y el inicio
de fondo.

**`AlertDialog` con el formulario adentro.** Se descarta por lo mismo: un
diálogo con cuatro campos, un grupo de radios y el teclado no entra en un
teléfono con texto grande.

**Borrar `arrebato` del enum y mapear las viejas a `robo`.** Se descarta
(ya lo estaba en `progress/spec_quitar_arrebato.md`): cambia el ícono y el
nombre corto de alertas viejas y `desdeApi` las leería como SOS si solo se
borrara.

**Cortar el texto con `maxLength` (enforcement por defecto).** Se descarta
porque corta lo pegado sin avisar y cuenta grafemas, distinto del backend
(runas). Se muestra el contador y se valida al enviar.

**Tipo preelegido (por ejemplo, Actividad sospechosa).** Se descarta: se
mandaría un tipo que el vecino no eligió.

**SOS de ancho completo o de 120 dp o más de alto.** Se descarta: el
equipo pidió "un poco más grande, pero no tanto"; uno así taparía buena
parte de la lista y del mapa del inicio en un teléfono de 360 x 640 con
texto grande, y obligaría a cambiar el relleno de las tres listas.

## Riesgos y notas

- R4 lee "el SOS es el más grande" por alto y el SOS crece a 216 x 104
  (decisión 7, confirmada en la aprobación). Si más adelante se agranda
  otra vez por encima de 120 dp, hay que subir los 140 dp de relleno de
  Inicio, Turnos y Perfil.
- La validación nueva del backend aplica también al SOS; los valores del
  SOS están muy por debajo de los máximos.
- Contar letras con `runes` hace que un emoji compuesto cuente más de una;
  es aceptable con estos máximos y es igual en los dos lados.
- `backend/datos/barrio.json` (local, ignorado) conserva su alerta de
  arrebato: es lo esperado (R41).
- No se toca nada de la feature 19 (`estado_alerta`).
