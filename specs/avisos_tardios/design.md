# Design — avisos_tardios

> Decisiones técnicas tomadas antes de escribir código. Se apoya en
> `docs/architecture.md` y `docs/conventions.md`; acá solo va lo que esta
> feature agrega o donde roza sus límites.

## Resumen

1. "Tardía" **no es un dato de la alerta**: depende de cuándo le llegó el
   aviso a **cada** teléfono. El teléfono guarda, por alerta, la primera
   llegada de su aviso (push o vigilante) en `Preferencias`, ya corregida a
   la hora del servidor. La lista, el mapa y el detalle comparan esa
   llegada con `creada_en`.
2. El reloj del teléfono puede estar desfasado: `GET /salud` pasa a
   devolver también `ahora` (hora del servidor) y la comprobación de
   conexión de la feature 15, que ya corre cada 30 s, guarda el desfase.
3. El nombre de quien reportó lo pone **el backend**: el primer nombre en el
   campo `reportada_por_nombre` de cada alerta (JSON de la API) y, por lo
   tanto, en los datos del push. La app no lo busca. Ese mismo nombre se
   muestra en el aviso tardío y en "Reportada por" del detalle (R32–R35).
4. Los avisos con la app abierta (vigilante) **sí** pueden ser tardíos (por
   ejemplo, al volver la conexión después de que la compuerta tapó la app,
   o al volver a primer plano en un teléfono sin push) y siguen la misma
   regla.

## Decisiones pedidas

### De dónde sale el nombre de quien reportó

Con el código real:

- El push (`backend/lib/src/push_service.dart`) manda como `data` **todas**
  las claves del mapa de la alerta convertidas a texto; hoy trae
  `reportada_por` (id), no el nombre.
- La app no tiene ninguna ruta para pedir un vecino por id (solo
  `GET /vecinos/yo`), y el handler de segundo plano
  (`manejarMensajePushEnSegundoPlano`) corre en un isolate aparte, sin
  sesión armada, justo cuando el teléfono recién recupera la señal: hacer un
  pedido HTTP ahí es frágil.
- El vigilante también necesita el nombre para su aviso tardío (R19), y él
  trabaja con `GET /alertas`.

Decisión: el backend agrega `reportada_por_nombre` a **cada alerta que
devuelve** (`GET /alertas`, `POST /alertas`, `PATCH /alertas/<id>`) y a la
que le pasa a `notificarAlerta`. Se calcula al responder con
`_almacen.vecinos[reportada_por]['nombre']` → primera palabra (igual que
`Vecino.primerNombre` en la app); **no se guarda** en `datos/barrio.json`,
así un cambio de nombre se ve en la próxima lectura. Como
`PushServiceFcm.enviarAlerta` ya copia todas las claves, el push lo trae
sin tocar ese archivo (R9).

Privacidad: solo el primer nombre (R10), que ya se ve en la app (inicio y
turnos muestran nombres de vecinos). Va a quien ya recibe la alerta: los
vecinos con sesión (`GET /alertas` pide token) y los teléfonos suscriptos
al tópico. El equipo confirmó en la aprobación que el nombre se muestre
también en la app (ver "Quién reportó, en el detalle").

Límite de FCM (4096 bytes de `data`): el primer nombre suma unos 30 bytes
(`"reportada_por_nombre":"Marta"`). El riesgo de tamaño que ya existe es
`descripcion`, que el backend no limita; no lo agrava esta feature (ver
"Riesgos").

### Qué es "tardía" en la lista y el mapa, y el reloj desfasado

Es un **cálculo en el teléfono** con un dato **del teléfono**: la llegada
guardada. Dos teléfonos ven la misma alerta distinto (uno sin señal la ve
tardía, el otro no), por eso no puede ser un campo de la alerta del
servidor.

- **Qué se guarda.** `AvisosRecibidosRepositoryLocal.registrarLlegada(id)`
  guarda `ahora del teléfono + desfase` la primera vez (R5) y devuelve la
  que ya estaba las siguientes (R6). Así, si el push llegó a tiempo con la
  app en segundo plano y después el vigilante "descubre" la misma alerta al
  volver a primer plano, cuenta la llegada del push.
- **Cuándo se guarda.** Solo cuando hay aviso: alerta de otro vecino, no
  resuelta y con los avisos activos (R5, R7). Si los avisos están apagados
  no hay aviso, y la alerta se ve en la lista como siempre, sin marca.
  Tampoco se guarda en la primera revisión del vigilante al abrir la app
  (lo que ya estaba no se avisa, como hoy). Las alertas propias nunca se
  guardan: "Mis alertas" no cambia.
- **Se guarda también si es demasiado tardía** (R26): no se muestra la
  notificación, pero la lista y el mapa la marcan.
- **Desfase.** El backend responde `GET /salud` con
  `{"estado": "ok", "ahora": <ms>}` (R2). `ConexionServiceHttp` toma la
  hora del teléfono antes (`t0`) y después (`t1`) del pedido y calcula
  `desfase = ahora − (t0 + (t1 − t0) / 2)` (R3); el error es como mucho la
  mitad del viaje (menos de 2,5 s con el tope de 5 s), despreciable contra
  5 minutos. `ConexionRepositoryRemoto` lo guarda después de cada
  comprobación buena. Sin `ahora` (backend viejo) no se guarda nada y queda
  el último (o cero). El isolate del push lee el desfase de `Preferencias`
  (R4). Por qué importa: un teléfono con la hora adelantada 3 horas
  clasificaría todo aviso como demasiado tardío y **no mostraría un SOS**.
- **Demora negativa** (el desfase medido no es exacto): cuenta como a
  tiempo (R1).
- La comparación es entre dos instantes (milisegundos), así que la zona
  horaria no influye en la clasificación; solo en cómo se escribe la hora.

### Formato de hora y medianoche

- `horaYMinutos(fecha)`: `HH:mm`, 24 h, con dos dígitos (`"09:05"`), sobre
  `creadaEn`, que `Alerta.fromJson` arma con
  `DateTime.fromMillisecondsSinceEpoch` → **zona del teléfono** (R17). Es
  la hora real de la alerta (del servidor), no la de llegada.
- **Notificación: sin fecha**, aunque cruce la medianoche (R17). La demora
  de una notificación que se muestra es de 2 horas como mucho, así que
  "SOS de Marta 23:50" recibido a las 00:30 solo puede ser de hace 40
  minutos; el cuerpo dice que llegó con demora y el sistema muestra la hora
  de llegada al lado. El título queda exactamente con el formato acordado.
- **Lista, mapa y detalle: con fecha si no es de hoy** (R21). Ahí la alerta
  puede quedar días (se ve hasta que se resuelve), así que
  "Llegó con demora. Alerta del 24/11 a las 23:50". "Hoy" se mide con el
  `Reloj` del ViewModel en la zona del teléfono. No se agrega "ayer": el
  texto "Ayer a las 23:50" que ya da `tiempoTranscurrido` sigue al lado.

### Nombre corto de la categoría y Arrebato

Aprobados en la revisión: "SOS", "Robo", "Actividad sospechosa",
"Vehículo sospechoso" y "Ruidos" (R16). Arrebato **no** tiene nombre corto:
el tipo se va a quitar de la app en la feature 17 (`quitar_arrebato`), y las
alertas de arrebato que ya existen se siguen viendo. Mientras exista, el
aviso tardío de una alerta de arrebato usa `alerta.tipo` tal cual (en los
datos de ejemplo, "Arrebato"). Por eso `nombreCorto` devuelve `String?`
(`null` para arrebato) y el título usa `tipoParaAviso(alerta)`
= `alerta.categoria.nombreCorto ?? alerta.tipo`. Cuando la feature 17 quite
el valor del enum (o lo deje solo para leer), el `switch` exhaustivo de
`nombreCorto` la obliga a revisar este punto.

### Quién reportó, en el detalle

Con el código real, el único lugar de la app que dice quién reportó es el
`ListTile` "Reportada por" de `DetalleAlertaScreen`
(`subtitle: Text(esMia ? 'Vos' : 'Un vecino de la zona')`). La tarjeta de
la lista (`TarjetaAlerta` y su `descripcion`), el pin y su etiqueta
(`MapaBarrio.etiquetaDe`) y el resumen del mapa no muestran a quien
reportó: **no cambian** en esto, así que no hay incoherencia entre
pantallas. "Mis alertas" muestra solo alertas propias y tampoco cambia.

- El texto lo decide `DetalleAlertaViewModel.reportadaPor`:
  propia → "Vos" (R34); ajena con nombre → el nombre (R32); ajena sin
  nombre → "Un vecino" (R33). Es el mismo criterio que R18 ("de un
  vecino"), con mayúscula por ir solo en el renglón. Se deja de usar
  "Un vecino de la zona".
- Usa `_alerta`, así que después de `marcarResuelta` (la respuesta del
  `PATCH` también trae el nombre, R8) sigue valiendo; de todos modos solo
  quien la reportó puede cerrarla, y para esa persona dice "Vos".
- El nombre ya llega al detalle porque `Alerta` lo lee del JSON y de la
  copia local (R11, R12), sin pedidos nuevos.
- Accesibilidad (R35): el `ListTile` va dentro de `MergeSemantics`, así el
  lector lee "Reportada por" y el nombre como una sola etiqueta; el
  subtítulo hace salto de línea con texto grande dentro del `ListView`.
  Colores sin cambios (los del `ListTile`, ya cubiertos por
  `textContrastGuideline`).

### Avisos locales con la app abierta (vigilante)

Sí pueden ser tardíos y usan exactamente la misma regla (R19). Casos reales
con el código de hoy:

- La conexión se corta con la app abierta: la compuerta tapa todo y
  `revisar()` falla en silencio; al volver, la primera revisión encuentra
  las alertas creadas mientras tanto. Si pasaron más de 5 minutos, el aviso
  dice que llegó con demora.
- Teléfono sin push (web, escritorio, o push caído) que vuelve a primer
  plano después de un rato: lo mismo.
- Teléfono con push que ya avisó a tiempo en segundo plano: la llegada
  guardada es la del push, así que el vigilante lo avisa a tiempo, igual
  que hoy (el aviso se reemplaza por usar el mismo id).

Orden dentro de `revisar()`: primero se guardan las llegadas de las nuevas
(si los avisos están activos), **después** se publica
`AlertasActualizadas` (así las pantallas, al recargar, ya ven la marca) y
al final se muestran los avisos. `revisar()` pasa a devolver las alertas
que efectivamente avisó (a tiempo o tardías); las demasiado tardías no.

## Archivos a crear o cambiar

| Capa | Archivo | Cambio |
|---|---|---|
| domain | `lib/domain/avisos_tardios.dart` | **Nuevo.** Umbrales, `PuntualidadAviso`, `clasificarAviso`, `nombreCorto`, `tipoParaAviso`, `horaYMinutos`, `tituloAvisoTardio`, `cuerpoAvisoTardio`. Puro Dart. |
| domain | `lib/domain/models/alerta.dart` | Campo `reportadaPorNombre` (`String`, `''` si falta) en constructor, `fromJson` y `toJson` (R11). |
| data | `lib/data/services/local/preferencias.dart` | Claves `avisos_recibidos` (JSON `{id: ms}`) y `desfase_reloj` (ms); se suman a `todasLasClaves`. Métodos abajo. |
| data | `lib/data/repositories/avisos_recibidos_repository.dart` | **Nuevo.** `AvisosRecibidosRepository` + `AvisosRecibidosRepositoryLocal` (Preferencias + Reloj). |
| data | `lib/data/services/conexion_service.dart` | Getter `Duration? get desfase` (último medido). |
| data | `lib/data/services/http/conexion_service_http.dart` | Recibe `Reloj`; mide el desfase con `ahora` de `/salud` (R3). |
| data | `lib/data/services/simulados/conexion_service_simulado.dart` | `Duration? desfase = Duration.zero` (mutable, para pruebas). El servidor simulado usa el mismo `Reloj`. |
| data | `lib/data/repositories/conexion_repository.dart` | `ConexionRepositoryRemoto` recibe `AvisosRecibidosRepository? avisos` y, tras una comprobación buena con `desfase != null`, llama `unawaited(avisos.guardarDesfase(d))`. |
| data | `lib/data/services/push_service.dart` | `alertaDesdeDatosPush` lee `reportada_por_nombre` (opcional). `procesarAvisoPush` recibe `avisos`, registra la llegada y elige aviso normal, tardío o ninguno. El handler de segundo plano arma `AvisosRecibidosRepositoryLocal(preferencias, RelojDelSistema())`. |
| data | `lib/data/services/notificaciones_service.dart` | `avisarAlertaTardia(Alerta)` en la interfaz, en `…Locales` (mismo id y payload, título y cuerpo de R14) y en `…Ninguno`. `avisarAlerta` no cambia (R13). |
| data | `lib/data/services/local/base_de_datos.dart` | `versionDelEsquema = 4`; columna en `sqlCrearAlertas`; migración en `onUpgrade` (R12). |
| data | `lib/data/services/simulados/servidor_simulado.dart` | Agrega `reportada_por_nombre` (primer nombre de `_vecinos`) a cada alerta que devuelve, como el backend. |
| ui | `lib/ui/core/formato.dart` | `marcaTardia({required DateTime creadaEn, required DateTime ahora})` (R20, R21). |
| ui | `lib/ui/core/widgets/marca_tardia.dart` | **Nuevo.** `MarcaTardia` (ícono reloj + texto). |
| ui | `lib/ui/core/widgets/pin_alerta.dart` | Parámetro `bool tardia = false`: distintivo de reloj (R22). |
| ui | `lib/ui/core/widgets/tarjeta_alerta.dart` | Parámetro `String? tardia`: muestra `MarcaTardia` y lo suma a `descripcion` (R20, R28). |
| ui | `lib/ui/core/widgets/mapa_barrio.dart` | Parámetro `Map<String, String> tardias = const {}` (id → texto de la marca): pin con distintivo y etiqueta con la marca (R22, R28). |
| ui | `lib/ui/core/tema/app_colors.dart` | Pares de contraste de la marca (R30). |
| ui | `lib/ui/inicio/view_models/inicio_view_model.dart` | Recibe `avisos`; carga las llegadas en `cargar()`; `String? tardia(Alerta)` y `Map<String, String> get tardias`. |
| ui | `lib/ui/inicio/widgets/inicio_screen.dart` | Pasa `tardia` a cada `TarjetaAlerta` y `tardias` al mapa chico. |
| ui | `lib/ui/mapa/view_models/mapa_view_model.dart` | Igual que inicio. |
| ui | `lib/ui/mapa/widgets/mapa_screen.dart` | `tardias` a `MapaBarrio`; `MarcaTardia` en el resumen (R23); muestra en `_Leyenda` (R31). |
| ui | `lib/ui/alerta_detalle/view_models/detalle_alerta_view_model.dart` | Recibe `avisos`; `Future<void> cargarLlegada()`; `String? get tardia`; `String get reportadaPor` (R32–R34). |
| ui | `lib/ui/alerta_detalle/widgets/detalle_alerta_screen.dart` | `abrir` pasa `avisos` y llama `cargarLlegada()`; `MarcaTardia` bajo el estado (R24); "Reportada por" muestra `viewModel.reportadaPor` dentro de `MergeSemantics` (R32–R35). |
| ui | `lib/ui/principal/vigilante_de_alertas.dart` | Recibe `avisos`; clasifica como el push (R19). |
| ui | `lib/ui/principal/widgets/principal_screen.dart` | Pasa `d.avisos` a `InicioViewModel`, `MapaViewModel` y `VigilanteDeAlertas`. |
| armado | `lib/dependencias.dart` | Ver "Armado". |
| backend | `backend/lib/src/api.dart` | `/salud` con `ahora` (R2); `_conNombre` en las tres rutas de alertas y en `notificarAlerta` (R8–R10). |
| backend | `backend/README.md` | `/salud` con `ahora`; campo `reportada_por_nombre` en las alertas y en el push. |
| pruebas | `test/ayudas/falsos.dart` | `NotificacionesFalsas.tardias`; `AvisosRecibidosFalsos`; `alertaDePrueba` con `reportadaPorNombre` y `creadaEn` configurables. |
| pruebas | `test/unit/dominio_test.dart`, `test/unit/avisos_tardios_test.dart` (nuevo), `test/unit/notificaciones_test.dart`, `test/unit/conexion_test.dart`, `test/unit/persistencia_test.dart`, `test/unit/view_models_test.dart`, `test/widget_test.dart`, `test/accesibilidad_test.dart`, `backend/test/api_test.dart` | Ver `tasks.md`. |

## Firmas nuevas

```dart
// lib/domain/avisos_tardios.dart
/// Hasta esta demora (inclusive) el aviso llegó a tiempo.
const demoraParaTardia = Duration(minutes: 5);

/// Con más demora que esto, el aviso ya no se muestra.
const demoraMaximaParaAvisar = Duration(hours: 2);

enum PuntualidadAviso { aTiempo, tardio, demasiadoTardio }

/// R1. [llegada] en hora del servidor (ver AvisosRecibidosRepository).
PuntualidadAviso clasificarAviso({
  required DateTime creadaEn,
  required DateTime llegada,
});

/// tardio o demasiadoTardio.
bool esTardia(PuntualidadAviso puntualidad);

/// R16. "SOS", "Actividad sospechosa", "Vehículo sospechoso", "Robo",
/// "Ruidos"; null para arrebato (se quita en la feature 17). `switch`
/// exhaustivo sobre el enum.
extension NombreCortoCategoria on CategoriaAlerta {
  String? get nombreCorto;
}

/// R16. `alerta.categoria.nombreCorto ?? alerta.tipo`.
String tipoParaAviso(Alerta alerta);

/// "15:10", "09:05". Zona del teléfono, 24 h (R17).
String horaYMinutos(DateTime fecha);

/// "SOS de Marta 15:10"; sin nombre, "SOS de un vecino 15:10" (R14, R16,
/// R18). El tipo sale de tipoParaAviso.
String tituloAvisoTardio(Alerta alerta);

const cuerpoAvisoTardio =
    'Llegó con demora por falta de señal. Puede que ya no esté pasando.';

// lib/domain/models/alerta.dart
/// Primer nombre de quien la reportó, para el aviso tardío. '' si el
/// servidor no lo mandó.
final String reportadaPorNombre; // const Alerta({…, this.reportadaPorNombre = ''})

// lib/data/services/local/preferencias.dart
static const claveAvisosRecibidos = 'avisos_recibidos';
static const claveDesfaseReloj = 'desfase_reloj';
Future<Map<String, int>> avisosRecibidos(); // {} si falta o no se lee
Future<void> guardarAvisosRecibidos(Map<String, int> llegadas);
Future<int> desfaseReloj(); // 0 si falta
Future<void> guardarDesfaseReloj(int milisegundos);

// lib/data/repositories/avisos_recibidos_repository.dart
/// Cuándo le llegó a este teléfono el aviso de cada alerta, en hora del
/// servidor. Lo usan el push (en su isolate), el vigilante y las pantallas.
abstract class AvisosRecibidosRepository {
  /// Guarda ahora + desfase si no había llegada para [alertaId]; si había,
  /// la deja. Devuelve la llegada que quedó (R5, R6).
  Future<DateTime> registrarLlegada(String alertaId);

  /// Todas las llegadas guardadas, por id de alerta.
  Future<Map<String, DateTime>> llegadas();

  Future<void> guardarDesfase(Duration desfase);
}

class AvisosRecibidosRepositoryLocal implements AvisosRecibidosRepository {
  AvisosRecibidosRepositoryLocal({
    required Preferencias preferencias,
    required Reloj reloj,
  });
  /// Al registrar, borra las llegadas de más de 30 días para que la clave
  /// no crezca sin fin.
  static const conservarDurante = Duration(days: 30);
}

// lib/data/services/conexion_service.dart
abstract class ConexionService {
  Future<bool> hayConexion();

  /// Hora del servidor menos hora del teléfono según la última respuesta
  /// de /salud; null si nunca se pudo medir.
  Duration? get desfase;
}

// lib/data/services/http/conexion_service_http.dart
ConexionServiceHttp(
  this._api, {
  this.espera = const Duration(seconds: 5),
  Reloj reloj = const RelojDelSistema(),
});

// lib/data/repositories/conexion_repository.dart
ConexionRepositoryRemoto({
  required ConexionService service,
  AvisosRecibidosRepository? avisos,
});

// lib/data/services/push_service.dart
Future<bool> procesarAvisoPush(
  Map<String, dynamic> datos, {
  required Preferencias preferencias,
  required NotificacionesService notificaciones,
  required AvisosRecibidosRepository avisos,
});
// Orden: parsear → resuelta: false → avisos apagados: false → propia: false
// → llegada = registrarLlegada(id) → switch clasificarAviso:
//   aTiempo → avisarAlerta (true); tardio → avisarAlertaTardia (true);
//   demasiadoTardio → false.

// lib/data/services/notificaciones_service.dart
/// R14. Mismo id y payload que avisarAlerta: si después llega el aviso
/// normal de la misma alerta, se reemplaza.
Future<void> avisarAlertaTardia(Alerta alerta);

// lib/ui/core/formato.dart
/// "Llegó con demora. Alerta de las 15:10" o, si no es del día de [ahora],
/// "Llegó con demora. Alerta del 24/11 a las 23:50" (R20, R21).
String marcaTardia({required DateTime creadaEn, required DateTime ahora});

// lib/ui/core/widgets/marca_tardia.dart
class MarcaTardia extends StatelessWidget {
  const MarcaTardia({super.key, required this.texto});
  final String texto;
}

// lib/ui/core/widgets/pin_alerta.dart
const PinAlerta({super.key, required this.estado, this.diametro = 32, this.tardia = false});

// lib/ui/core/widgets/tarjeta_alerta.dart
const TarjetaAlerta({super.key, required this.alerta, required this.hace, required this.onTap, this.tardia});
static String descripcion(Alerta alerta, String hace, {String? tardia});

// lib/ui/core/widgets/mapa_barrio.dart
final Map<String, String> tardias; // const {}
static String etiquetaDe(Alerta alerta, {String? tardia});

// InicioViewModel / MapaViewModel
required AvisosRecibidosRepository avisos,
/// Texto de la marca o null si no es tardía (R20, R25).
String? tardia(Alerta alerta);
/// id → texto de la marca, para el mapa.
Map<String, String> get tardias;

// DetalleAlertaViewModel
required AvisosRecibidosRepository avisos,
Future<void> cargarLlegada(); // notifyListeners al terminar
String? get tardia;
/// "Vos" si es propia; si no, `alerta.reportadaPorNombre`, o "Un vecino"
/// si está vacío (R32, R33, R34).
String get reportadaPor;

// VigilanteDeAlertas
required AvisosRecibidosRepository avisos,
```

En los tres ViewModels, si `llegadas()` falla se toma `{}` (sin marcas): la
lista no deja de verse por esto.

## Armado en `lib/dependencias.dart`

- `Dependencias` gana `final AvisosRecibidosRepository avisos;` (requerido
  en el constructor).
- `_armar` crea, después de `prefs`,
  `final avisos = AvisosRecibidosRepositoryLocal(preferencias: prefs, reloj: reloj);`
  y lo pasa a `ConexionRepositoryRemoto(service: …, avisos: avisos)` y a
  `Dependencias(avisos: avisos)`.
- `Dependencias.conApi` arma `ConexionServiceHttp(api, reloj: reloj)`.
- `Dependencias.simuladas`: sin cambios de parámetros
  (`ConexionServiceSimulado` mide desfase cero).
- `manejarMensajePushEnSegundoPlano` no usa `Dependencias` (corre en otro
  isolate): arma su propio `AvisosRecibidosRepositoryLocal` con
  `Preferencias(SharedPreferencesAsync())` y `const RelojDelSistema()`.
  `SharedPreferencesAsync` no tiene caché, así que el isolate y la app ven
  lo mismo.

## API y datos

- **`GET /salud`** → `200 {"estado": "ok", "ahora": 1764090600000}`. Sin
  token, como hoy. `ConexionServiceHttp` sigue exigiendo solo
  `estado == "ok"` para dar conexión: un backend sin `ahora` no rompe nada.
- **Alertas** (`GET /alertas`, `POST /alertas` 201, `PATCH /alertas/<id>`):
  suman `"reportada_por_nombre": "Clara"`. No se guarda en el almacén: lo
  agrega `_conNombre(alerta)` al responder (copia del mapa). Si el vecino no
  existe o no tiene nombre, `""`.
- **Push**: `notificarAlerta(_conNombre(alerta))`; los datos FCM suman
  `reportada_por_nombre`. Ninguna otra clave nueva (R10).
- **`Alerta`**: `fromJson` lee `json['reportada_por_nombre'] as String? ?? ''`;
  `toJson` lo escribe. `alertaDesdeDatosPush` lo pasa si es `String`.
  `crearAlerta` del repositorio no lo manda (lo pone el servidor).
- **sqflite**: `versionDelEsquema` 3 → 4.
  - `sqlCrearAlertas` suma `reportada_por_nombre TEXT NOT NULL DEFAULT ''`.
  - `onUpgrade`: `if (anterior < 4) await db.execute("ALTER TABLE alertas ADD COLUMN reportada_por_nombre TEXT NOT NULL DEFAULT ''");`
    (después del bloque `< 3`). Comentario de versiones: "4: alertas con
    reportada_por_nombre (avisos tardíos)".
  - Las llegadas **no** van a sqflite: el isolate del push ya usa
    `Preferencias` y abrir la base desde ahí agrega un riesgo innecesario.
- **Preferencias**: `avisos_recibidos` = `jsonEncode({"a12": 1764090600000, …})`;
  `desfase_reloj` = entero en ms. `olvidarTodo()` (cerrar sesión) los
  borra.

## Plataforma

No depende de la plataforma. Sin push (web, escritorio), los avisos los da
el vigilante con la misma regla. No se agrega nada a `Capacidades` ni a
`Politicas`.

## Accesibilidad

- **`MarcaTardia`**: `Row` con `Icon(Icons.schedule)` dentro de
  `ExcludeSemantics` y `Flexible(Text(texto))` que hace salto de línea (R29).
  Fondo `AppColors.alertaSuave`, borde y ícono `AppColors.alerta`, texto
  `AppColors.texto` en 14 sp con `FontWeight.w600`. Se registran en
  `AppColors.paresDeContraste`: "Texto de la marca tardía" (texto sobre
  `alertaSuave`, 4.5:1) e "Ícono de la marca tardía" (`alerta` sobre
  `alertaSuave`, 3:1) (R30). El estado se comunica con ícono y palabras,
  no solo con el naranja (R27). No es tocable: no necesita 48 dp.
- **Tarjeta**: `TarjetaAlerta.descripcion` agrega el texto de la marca tal
  cual (`"Llegó con demora. Alerta de las 15:10."`) antes de la dirección;
  la etiqueta del `TarjetaTocable` la incluye (R28). La `MarcaTardia` va entre `hace` y el `ChipEstado`.
- **Pin**: `PinAlerta(tardia: true)` dibuja, en un `Stack`, un círculo
  blanco de `diametro * 0.45` con borde `AppColors.alerta` y
  `Icons.schedule` en la esquina superior derecha: se distingue por forma,
  no solo por color (R22). `MapaBarrio.etiquetaDe(alerta, tardia: …)`
  agrega el texto de la marca antes de "Ver resumen" (R28). El área táctil
  sigue siendo de 48 dp (`ObjetivoTactil`).
- **"Reportada por" del detalle**: `MergeSemantics` alrededor del
  `ListTile`, para que el lector diga "Reportada por" y el nombre juntos;
  con texto al 200 % el subtítulo hace salto de línea (R35).
- **Leyenda**: un ítem más, `PinAlerta(estado: activa, diametro: 22,
  tardia: true)` + "Llegó con demora" (R31).
- **Resumen del mapa y detalle**: `MarcaTardia` dentro del `Wrap` del
  estado (con `ChipEstado` y `hace`), que ya se reacomoda con texto grande;
  el resumen ya es `SingleChildScrollView` y el detalle un `ListView` (R29).
- Pruebas: `meetsGuideline` (`androidTapTargetGuideline`,
  `iOSTapTargetGuideline`, `labeledTapTargetGuideline`,
  `textContrastGuideline`) con una alerta tardía en inicio, mapa (resumen
  abierto) y detalle (con nombre de quien reportó), y texto al 200 % sin
  excepciones de desborde.

## Paquetes nuevos

Ninguno. La hora se formatea a mano (como `tiempoTranscurrido` y
`fechaNumerica`), sin `intl`.

## Alternativas descartadas

**Que la app busque el nombre de quien reportó.** No existe ruta para pedir
un vecino por id, habría que crear una (más superficie de datos personales
que solo el primer nombre) y llamarla desde el isolate del push, sin sesión
armada y justo al recuperar señal. Se descarta.

**Mandar el nombre solo en el push y no en el JSON de la alerta.** Deja al
vigilante sin nombre para su aviso tardío (R19), que tendría un título
distinto del acordado. Se descarta.

**Mostrar quién reportó también en la tarjeta y el pin.** Hoy no lo
muestran; el lugar donde la app dice quién reportó es "Reportada por" del
detalle. Sumarlo a la tarjeta y a la etiqueta del pin alarga textos que ya
tienen tipo, hora, estado, dirección y, ahora, la marca de tardía. Se
descarta; queda coherente porque ninguna de las dos muestra a quien
reportó.

**Darle a Arrebato un nombre corto propio.** El tipo se elimina en la
feature 17; un nombre corto nuevo sería algo más para borrar. Se descarta:
usa `tipo`.

**Marcar "tardía" en el servidor** (por ejemplo, comparando `creada_en` con
la hora de entrega de FCM). El servidor no sabe cuándo llegó el mensaje a
cada teléfono, y la demora es por teléfono. Se descarta.

**Usar solo el reloj del teléfono, sin desfase.** Es más simple, pero con
la hora del teléfono adelantada más de 2 horas se dejaría de mostrar
cualquier aviso, incluido un SOS. El costo del desfase es un campo más en
`/salud`, que ya se consulta cada 30 s. Se descarta usar solo el teléfono.

**Guardar las llegadas en sqflite.** Sobreviviría a `reemplazarTodas` solo
con una tabla aparte, y habría que abrir la base desde el isolate del push.
`Preferencias` ya se usa ahí. Se descarta.

## Riesgos y notas

- **Feature 17 (`quitar_arrebato`).** Si se implementa después de esta,
  tiene que revisar `nombreCorto` y `tipoParaAviso` (R16) y la prueba del
  aviso de arrebato de T4. Esta feature no quita nada de Arrebato.
- **Tamaño del push.** `descripcion` no tiene límite en el backend; una
  muy larga puede pasar los 4096 bytes de FCM con o sin esta feature. Queda
  fuera del alcance; conviene una feature aparte que la limite.
- **Escrituras simultáneas en `avisos_recibidos`.** El isolate del push y
  el vigilante leen, modifican y escriben la misma clave. Casi no coinciden
  (el vigilante se detiene en segundo plano, que es cuando corre el handler
  del push); en el peor caso se pierde una llegada y esa alerta se ve sin
  marca. Aceptable.
- **Desfase viejo.** Si el vecino cambia la hora del teléfono con la app
  cerrada, el push usa el último desfase guardado hasta la próxima
  comprobación con la app abierta.
- **Pruebas existentes del push.** `test/unit/notificaciones_test.dart` usa
  `creada_en` = 1/10/2026 12:00 sin reloj: con esta feature esos avisos
  quedan demasiado tardíos. Hay que pasarles `AvisosRecibidosFalsos` con una
  llegada cercana (ver T14).
- Con 30 días de retención, una alerta tardía que siga abierta más de un mes
  pierde la marca. Aceptable para un barrio de 40 familias.
