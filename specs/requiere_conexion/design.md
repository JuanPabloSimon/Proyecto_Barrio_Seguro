# Design — requiere_conexion

> Decisiones técnicas tomadas antes de escribir código. Se apoya en
> `docs/architecture.md` y `docs/conventions.md`; acá solo va lo que esta
> feature agrega o donde roza sus límites.
>
> Esta feature **cambia el principio 7** de `docs/architecture.md`
> ("Funciona sin conexión"): la app pasa a requerir conexión y la copia
> local queda solo como caché.

## Resumen

1. Una pieza nueva comprueba si la app llega a la API (`GET /salud`, que ya
   existe en `backend/lib/src/api.dart`). No hace falta ningún paquete.
2. Una "compuerta" montada en `MaterialApp.builder` tapa **todas** las
   rutas con `SinConexionScreen` mientras no hay conexión, sin destruirlas:
   cuando vuelve la conexión se ve de nuevo lo que estaba abierto.
3. Se borra el envío diferido de la feature 10: `PendientesDao`, la tabla
   `alertas_pendientes`, `envio_de_pendientes.dart`, `tarea_de_fondo.dart`,
   `tareas_service.dart`, el paquete `workmanager` y
   `Capacidades.correTareasEnSegundoPlano`.

## Cómo se detecta la conexión (sin paquete nuevo)

"Hay wifi" no implica "hay internet", y tampoco "hay internet" implica que
la app llegue a su servidor. Por eso **no** se mira el estado de la red del
sistema operativo: se le pregunta a la propia API.

- `ConexionServiceHttp.hayConexion()` hace `GET /salud` con `ClienteApi`
  (el `package:http` que ya está) y un tope de **5 s**. Devuelve `true` solo
  si la respuesta es un `Map` con `estado == 'ok'` (R2).
- Cualquier otra cosa da `false` (R3): excepción de red, `TimeoutException`,
  `ErrorDelServidor` (4xx/5xx) o `FormatException` (un wifi con portal de
  acceso responde HTML con 200 o redirige a una página HTML: `jsonDecode`
  falla o el cuerpo no es `{"estado": "ok"}`).
- Como no hay eventos del sistema ("cambió la red"), se **consulta cada
  tanto** mientras la app está en primer plano: cada 30 s con conexión
  (R5) y cada 5 s sin conexión (R6). Además se comprueba al arrancar (R1),
  al volver a primer plano (R8) y apenas un pedido de alertas o turnos
  falla por la red (R4), para no esperar al próximo ciclo.
- En segundo plano no se consulta (R7): no gasta batería ni datos.

Con 40 familias, un `GET /salud` cada 30 s por teléfono abierto es una
carga despreciable para el servidor.

### Modo simulado (sin `API_URL`)

El servidor simulado vive en memoria y no usa la red, así que no hay nada
real que comprobar. `ConexionServiceSimulado` responde lo que diga su campo
`conectado` (arranca en `true`). Las pruebas y una demo pueden ponerlo en
`false` para ver la pantalla sin conexión. Consecuencia: **en modo simulado
la app no detecta la falta de internet real**; esto es intencional (el modo
simulado existe justamente para no depender de la red) y queda anotado en
"Riesgos".

## Qué pasa si se pierde la conexión en medio del uso

La compuerta está en `MaterialApp.builder`, por encima del `Navigator`, así
que tapa cualquier ruta abierta: login, principal, SOS (que es un
`fullscreenDialog`), detalle, diálogos y hojas. El `child` (el `Navigator`
con todas sus rutas) **no se desmonta**: queda dentro de
`Offstage` + `TickerMode(enabled: false)`. `Offstage` lo saca de la pintura,
de los toques y del árbol de semántica (R10: el lector de pantalla no lee la
copia guardada que queda detrás).

Casos concretos:

- **Pantalla SOS en "¿Enviar alerta SOS?"**: queda tapada. Al volver la
  conexión aparece igual que estaba (R14).
- **SOS en "Enviando…" y se corta la red**: `crearAlerta` falla con error de
  red, el repositorio **no** guarda nada (R16), dispara una comprobación
  (R4) y el `SosViewModel` pasa a `PasoSos.error` (R17). La compuerta tapa
  la pantalla; al volver la conexión el vecino ve "No pudimos enviar la
  alerta. Probá de nuevo o llamá al 911." con "Volver a intentar". En la
  pantalla sin conexión ya tiene "Llamar al 911" mientras tanto (R11).
- **SOS ya enviado ("Alerta enviada")**: queda tapada; al volver, "Ya estoy
  a salvo" y "Fue una falsa alarma" funcionan como siempre.
- **Inicio, mapa, turnos con datos ya cargados**: quedan tapados. Al volver,
  el ViewModel de conexión publica `AlertasActualizadas` y
  `TurnosActualizados` (R15). `InicioViewModel` escucha todos los eventos,
  `MapaViewModel` y `MisAlertasViewModel` escuchan `AlertasActualizadas` y
  `TurnosViewModel` escucha `TurnosActualizados`: todos recargan solos.
  Si la carga inicial había fallado (estado de error), así se recupera.
- **Login o registro a medio escribir**: el texto sigue en los campos al
  volver (los `TextEditingController` no se destruyen).

### Ventana entre que se cae la red y aparece la compuerta

Entre el corte y la próxima comprobación (como mucho 30 s, o lo que tarde
en fallar el primer pedido) la app puede seguir mostrando lo que ya tenía.
Si en esa ventana un pedido falla, el repositorio devuelve la copia
guardada con `sinConexion` (R20), la pantalla muestra la franja
`AvisoSinConexion` que ya existe y se dispara la comprobación (R4), que
pone la compuerta. Por eso la franja **se mantiene**: sigue siendo honesta
en esa ventana y cuando la API responde `/salud` pero falla en otra ruta.

### Arranque

El estado inicial del ViewModel es `comprobando`. Mientras dura la primera
comprobación se muestra la app normal (lo común es tener conexión: no se
quiere un parpadeo de "Necesitás conexión" en cada arranque). Si da sin
conexión, la compuerta aparece en ≤ 5 s.

## Archivos a crear o cambiar

| Capa | Archivo | Cambio |
|---|---|---|
| data | `lib/data/services/conexion_service.dart` | **Nuevo.** `abstract class ConexionService`. |
| data | `lib/data/services/http/conexion_service_http.dart` | **Nuevo.** `ConexionServiceHttp` (`GET /salud`, 5 s). |
| data | `lib/data/services/simulados/conexion_service_simulado.dart` | **Nuevo.** `ConexionServiceSimulado` con `conectado` mutable. |
| data | `lib/data/repositories/conexion_repository.dart` | **Nuevo.** `ConexionRepository` + `ConexionRepositoryRemoto`. |
| data | `lib/data/repositories/alertas_repository.dart` | Quitar `estaPendiente`, `enviarPendientes`, `_pendientes`, `_tareas`, `_reloj`, `_prefijoPendiente`, `_leerPendientes`, `_guardarPendiente` y la rama pendiente de `cambiarEstado`. `crearAlerta` relanza cualquier error. Recibe `ConexionRepository? conexion` y lo avisa ante fallas de red (R4). |
| data | `lib/data/repositories/turnos_repository.dart` | Recibe `ConexionRepository? conexion` y lo avisa ante fallas de red en `obtenerTurnos` (R4). La copia local sigue igual (R20). |
| data | `lib/data/services/local/base_de_datos.dart` | `versionDelEsquema = 3`; quitar `sqlCrearPendientes`; `onCreate` sin la tabla; `onUpgrade` con `DROP TABLE IF EXISTS alertas_pendientes` (R18, R19). |
| data | `lib/data/services/local/pendientes_dao.dart` | **Se borra.** |
| data | `lib/data/services/tareas/envio_de_pendientes.dart` | **Se borra.** |
| data | `lib/data/services/tareas/tarea_de_fondo.dart` | **Se borra.** |
| data | `lib/data/services/tareas/tareas_service.dart` | **Se borra** (y la carpeta `tareas/`). |
| plataforma | `lib/plataforma/capacidades.dart` | Quitar `correTareasEnSegundoPlano`. Corregir el comentario de `tieneBaseDeDatosLocal` ("copia para usar sin conexión" → "caché"). |
| ui | `lib/ui/conexion/view_models/conexion_view_model.dart` | **Nuevo.** `ConexionViewModel` + `EstadoConexion`. |
| ui | `lib/ui/conexion/widgets/compuerta_de_conexion.dart` | **Nuevo.** `CompuertaDeConexion` (Offstage del `child` + `SinConexionScreen`, escucha el ciclo de vida). |
| ui | `lib/ui/conexion/widgets/sin_conexion_screen.dart` | **Nuevo.** `SinConexionScreen`. |
| ui | `lib/ui/principal/vigilante_de_alertas.dart` | Quitar la llamada a `enviarPendientes()` y la mención en el comentario. Los avisos locales siguen igual. |
| ui | `lib/ui/sos/view_models/sos_view_model.dart` | Quitar `pendiente` / `_pendiente`. Borrar el comentario duplicado de `enviar()`. |
| ui | `lib/ui/sos/widgets/sos_screen.dart` | `_VistaSosEnviada` sin `pendiente`: se van "Alerta guardada" y "No hay señal. La alerta se va a enviar sola…". |
| armado | `lib/dependencias.dart` | Ver "Armado". |
| armado | `lib/main.dart` | Quitar `workmanager`, `PendientesDao`, `TareasService` y `callbackDispatcher`. `BarrioSeguroApp` arma la compuerta en `MaterialApp.builder`. |
| paquetes | `pubspec.yaml` / `pubspec.lock` | Quitar `workmanager` (ver "Paquetes"). |
| docs | `docs/architecture.md` | Principio 7 nuevo, sacar `tareas/` del árbol, agregar `ui/conexion/`. |
| pruebas | `test/ayudas/falsos.dart` | `ConexionFalsa` (servicio) y `ConexionRepositoryFalsa`; quitar `TareasFalsas`, `enviosDePendientes`, `estaPendiente`, `enviarPendientes` y `correTareasEnSegundoPlano`. |
| pruebas | `test/ayudas/bases_de_prueba.dart` | `baseEnMemoria()` sin `sqlCrearPendientes`. |
| pruebas | `test/ayudas/app_de_prueba.dart` | Parámetro `ConexionService? conexion` (por defecto `ConexionServiceSimulado()`). |
| pruebas | `test/unit/conexion_test.dart` | **Nuevo.** Servicio HTTP, repositorio y ViewModel de conexión. |
| pruebas | `test/unit/notificaciones_test.dart` | Borrar los grupos "Alertas sin señal", "Tarea de envío", la prueba de migración a la v2 y "cada revisión intenta mandar las alertas pendientes". El resto (avisos locales y push) queda. |
| pruebas | `test/unit/persistencia_test.dart` | Migración v2 → v3 y "sin tabla de pendientes" (R18, R19); prueba de `crearAlerta` sin red (R16). |
| pruebas | `test/widget_test.dart` | Compuerta sobre login, principal y SOS; volver con estado; 911 (R9–R15, R17). |
| pruebas | `test/accesibilidad_test.dart` | Guías y texto al 200 % de `SinConexionScreen` (R21–R24). |
| pruebas | `test/unit/plataforma_test.dart`, `test/capacidades_politicas_test.dart` | Quitar lo que use `correTareasEnSegundoPlano`, si hay algo. |
| backend | — | **Sin cambios.** `GET /salud` ya existe y responde `{"estado": "ok"}`. |

## Firmas nuevas

```dart
// lib/data/services/conexion_service.dart
/// Pregunta si la app llega a su servidor. No mira el wifi: hay wifi sin
/// internet (portales de acceso) e internet sin servidor.
abstract class ConexionService {
  /// true solo si el servidor respondió que está bien. Nunca lanza: ante
  /// cualquier falla devuelve false.
  Future<bool> hayConexion();
}

// lib/data/services/http/conexion_service_http.dart
class ConexionServiceHttp implements ConexionService {
  ConexionServiceHttp(this._api, {this.espera = const Duration(seconds: 5)});
  final ClienteApi _api;
  final Duration espera;
  @override
  Future<bool> hayConexion(); // _api.get('/salud').timeout(espera)
}

// lib/data/services/simulados/conexion_service_simulado.dart
class ConexionServiceSimulado implements ConexionService {
  ConexionServiceSimulado({this.conectado = true});
  bool conectado;
  @override
  Future<bool> hayConexion() async => conectado;
}

// lib/data/repositories/conexion_repository.dart
abstract class ConexionRepository {
  /// null hasta que termina la primera comprobación.
  bool? get hayConexion;

  /// Emite el resultado de cada comprobación que CAMBIA [hayConexion].
  Stream<bool> get cambios;

  /// Comprueba ahora. Si ya hay una comprobación en vuelo, devuelve esa
  /// (no dispara pedidos duplicados).
  Future<bool> comprobar();
}

class ConexionRepositoryRemoto implements ConexionRepository {
  ConexionRepositoryRemoto({required this._service});
  final ConexionService _service;
  // StreamController<bool>.broadcast(); Future<bool>? _enCurso;
  // comprobar(): _enCurso ??= _service.hayConexion().then(...)
  //   .whenComplete(() => _enCurso = null)
  Future<void> cerrar(); // cierra el StreamController
}

// lib/ui/conexion/view_models/conexion_view_model.dart
enum EstadoConexion { comprobando, conectado, sinConexion }

class ConexionViewModel extends ChangeNotifier {
  ConexionViewModel({
    required this._conexion,
    required this._bus,
    this.revisarCada = const Duration(seconds: 30),
    this.reintentarCada = const Duration(seconds: 5),
  });

  EstadoConexion get estado;
  bool get sinConexion; // estado == EstadoConexion.sinConexion

  /// Primera comprobación (R1) y reloj periódico. Se suscribe a
  /// _conexion.cambios para enterarse de las comprobaciones que disparan
  /// los repositorios (R4).
  void empezar();

  /// Corta el reloj (R7).
  void alPasarASegundoPlano();

  /// Comprueba ya y vuelve a encender el reloj (R8).
  void alVolverAPrimerPlano();

  // Al pasar de sinConexion a conectado: _bus.publicar(AlertasActualizadas())
  // y _bus.publicar(TurnosActualizados()) (R15). El reloj se reprograma
  // con revisarCada o reintentarCada según el estado (R5, R6).
  @override
  void dispose(); // cancela Timer y suscripción
}

// lib/ui/conexion/widgets/compuerta_de_conexion.dart
class CompuertaDeConexion extends StatefulWidget {
  const CompuertaDeConexion({
    super.key,
    required this.viewModel,
    required this.capacidades,
    required this.telefono,
    required this.child,
  });
  // initState: AppLifecycleListener(onPause: vm.alPasarASegundoPlano,
  //   onResume: vm.alVolverAPrimerPlano). dispose: listener.dispose().
  // build: ListenableBuilder → Stack(children: [
  //   Offstage(offstage: vm.sinConexion,
  //     child: TickerMode(enabled: !vm.sinConexion, child: child)),
  //   if (vm.sinConexion) Navigator(onGenerateRoute: … SinConexionScreen),
  // ])
}

// lib/ui/conexion/widgets/sin_conexion_screen.dart
class SinConexionScreen extends StatelessWidget {
  const SinConexionScreen({
    super.key,
    required this.capacidades,
    required this.telefono,
  });
}
```

El `ViewModel` no importa `widgets` ni recibe `BuildContext`: el
`AppLifecycleListener` vive en `CompuertaDeConexion` y solo llama a los dos
métodos del ViewModel. El `Navigator` propio de la compuerta hace falta
porque `MaterialApp.builder` queda **por encima** del `Navigator` de la app,
y `mostrarDialogo911` usa `showDialog`, que necesita un `Navigator` (el
`Theme` y el `ScaffoldMessenger` de `MaterialApp` sí están por encima del
`builder`, así que el aviso "No pudimos abrir el teléfono…" funciona).

### Cambios de firma en lo existente

```dart
// AlertasRepository: se quitan
bool estaPendiente(String id);
Future<void> enviarPendientes();

// AlertasRepositoryRemoto
AlertasRepositoryRemoto({
  required AlertasService service,
  AlertasDao? dao,
  ConexionRepository? conexion,
});

// TurnosRepositoryRemoto
TurnosRepositoryRemoto({
  required TurnosService service,
  TurnosDao? dao,
  ConexionRepository? conexion,
});
```

En los dos repositorios, en el `catch` del pedido al servicio: si el error
**no** es `ErrorDelServidor`, se llama `unawaited(_conexion?.comprobar())`
antes de leer la copia (R4). `crearAlerta` queda: si falla, relanza (R16);
no hay más `catch` que guarde. `cambiarEstado` pierde la rama pendiente.

## Armado en `lib/dependencias.dart`

- `Dependencias` gana `final ConexionRepository conexion;`.
- `Dependencias.simuladas` gana `ConexionService? conexion` (por defecto
  `ConexionServiceSimulado()`); pierde `TareasService tareas` y
  `PendientesDao? pendientesDao`.
- `Dependencias.conApi` arma `ConexionServiceHttp(api)` con el mismo
  `ClienteApi` (así una prueba con `MockClient` controla también `/salud`);
  pierde `tareas` y `pendientesDao`.
- `_armar` crea `ConexionRepositoryRemoto(service: …)` **antes** que los
  repositorios de alertas y turnos y se lo pasa a los dos.
- `main.dart` deja de crear `PendientesDao`, `TareasService` y de llamar a
  `Workmanager().initialize`.
- `BarrioSeguroApp.build`:

```dart
MaterialApp(
  …,
  builder: (context, child) => ConViewModel(
    crear: () => ConexionViewModel(
      conexion: dependencias.conexion,
      bus: dependencias.bus,
    )..empezar(),
    builder: (_, vm) => CompuertaDeConexion(
      viewModel: vm,
      capacidades: dependencias.capacidades,
      telefono: dependencias.telefono,
      child: child ?? const SizedBox.shrink(),
    ),
  ),
  home: …, // igual que hoy
)
```

## API y datos

- **Rutas:** ninguna nueva. Se usa `GET /salud` → `200 {"estado": "ok"}`
  (ya existe, sin token).
- **JSON de los modelos:** sin cambios.
- **sqflite:** `versionDelEsquema` pasa de 2 a 3.
  - `onCreate`: `alertas` y `turnos` (sin `alertas_pendientes`).
  - `onUpgrade`: `if (anterior < 3) await db.execute('DROP TABLE IF EXISTS alertas_pendientes');`
    Cubre 1 → 3 (no existía: no pasa nada) y 2 → 3 (se borra). `alertas` y
    `turnos` no se tocan.
  - El comentario de versiones queda: 1 alertas y turnos; 2
    alertas_pendientes; 3 se quita alertas_pendientes (la app requiere
    conexión).
  - **Las alertas que hubieran quedado pendientes en un teléfono al
    actualizar se descartan sin enviarse.** Es a propósito: un SOS de hace
    horas mandado tarde confunde más de lo que ayuda (ver feature 16
    `avisos_tardios`).

## Plataforma

- La detección no depende de la plataforma: es un pedido HTTP con
  `package:http`, que anda en Android, iOS, escritorio y web. No se agrega
  nada a `Capacidades` ni a `Politicas`.
- `Capacidades.correTareasEnSegundoPlano` **se quita**: su único uso era
  inicializar `workmanager` y elegir `TareasConWorkmanager`. Se quita
  también de `CapacidadesFalsas`.
- `Capacidades.puedeHacerLlamadas` se sigue usando en la pantalla sin
  conexión a través de `mostrarDialogo911` (R13).
- La llamada al 911 con `tel:` (`TelefonoServiceUrlLauncher`) usa la red de
  voz del celular, no datos: funciona sin internet.
- Android ya declara `android.permission.INTERNET` en el manifiesto
  principal. No hace falta `ACCESS_NETWORK_STATE` porque no se consulta el
  estado de la red del sistema. `workmanager` no tenía configuración propia
  en `android/` ni en `ios/`: no hay nada que limpiar ahí.
- `Politicas`: sin cambios.

## Qué cambia de la feature 10 `avisos_y_segundo_plano`

| Parte de la feature 10 | Queda |
|---|---|
| Avisos locales de alertas nuevas con la app abierta (`VigilanteDeAlertas`, `NotificacionesService`) | **Sí**, igual. Solo se quita la llamada a `enviarPendientes()` en `revisar()`. |
| Pausar la revisión en segundo plano y revisar al volver (ciclo de vida) | **Sí.** |
| Alertas sin señal guardadas en `alertas_pendientes` | **No.** Se borran el DAO, la tabla (migración) y la rama del repositorio. |
| Envío con `workmanager` al volver la señal (`tarea_de_fondo.dart`, `TareasService`) | **No.** Se borra, con el paquete. |
| Envío al volver a primer plano (`enviarPendientes`) | **No.** |
| Texto "Alerta guardada / se va a enviar sola" en el SOS | **No.** |

Los avisos push con la app cerrada (feature 12) no cambian.

## Accesibilidad

`SinConexionScreen` es un `Scaffold` con `SafeArea` y
`SingleChildScrollView` (texto al 200 % sin desbordar, R23):

- Ícono `Icons.wifi_off` dentro de `ExcludeSemantics` (decorativo).
- Título "Necesitás conexión a internet para usar la app" con
  `Semantics(header: true, liveRegion: true)` (R22), texto grande con
  `AppColors.texto` sobre `AppColors.fondo`/`superficie` (contraste ya
  verificado en la feature 2, R24).
- Texto de ayuda: "Conectate a un wifi o activá los datos del celular. La
  app sigue sola cuando vuelva la conexión. Si estás en peligro, llamá al
  911." El estado se comunica con texto, no con color (R24).
- Botón `FilledButton.icon` "Llamar al 911" con `minimumSize: Size(64, 64)`,
  fondo `AppColors.emergencia`, texto con etiqueta propia (R21). Es el
  elemento tocable más grande de la pantalla.
- No muestra el botón SOS: sin conexión no se puede mandar una alerta, y
  mostrarlo sería prometer algo que la app no puede cumplir. El 911 ocupa
  ese lugar.

Pruebas: `meetsGuideline` con `androidTapTargetGuideline`,
`iOSTapTargetGuideline`, `labeledTapTargetGuideline` y
`textContrastGuideline`, más texto al 200 % sin excepciones de desborde,
como el resto de `test/accesibilidad_test.dart`.

## Paquetes

- **Nuevos: ninguno.** La detección usa `package:http`, que ya está.
- **Se quita `workmanager: ^0.10.3`** de `pubspec.yaml` (y su comentario),
  con `flutter pub get` para actualizar `pubspec.lock`. Es un cambio de
  dependencias: lo respalda la decisión del equipo de quitar el envío
  diferido "y lo que quede sin uso" (consigna de la feature 15). El
  implementer lo anota en `progress/history.md` al cerrar.

## Alternativas descartadas

**`connectivity_plus` (paquete nuevo).** Avisa al instante cuando cambia la
red, pero solo dice si hay wifi o datos, no si hay internet ni si llega al
servidor: igual habría que hacer el `GET /salud`. Además es un paquete
nuevo, que según `AGENTS.md` obliga a bloquear y consultar al equipo. La
consulta periódica a `/salud` resuelve lo mismo con lo que ya hay. Si más
adelante se quiere reaccionar al instante, se puede sumar como disparador
extra de `comprobar()` sin cambiar el resto.

**`InternetAddress.lookup` de `dart:io` (DNS).** No anda en la web, obliga
a mirar la plataforma y un DNS que responde no garantiza que el servidor
responda (ni descarta un portal de acceso que intercepta el DNS).

**Reemplazar `home` por la pantalla sin conexión.** Destruiría el
`Navigator` y todas las rutas abiertas: el vecino perdería lo que estaba
haciendo y no se cumpliría R14.

**Quitar la copia local (DAOs de alertas y turnos).** El `acceptance` pide
que quede como caché, y sigue sirviendo para la ventana entre el corte y la
compuerta y para abrir más rápido. Se mantiene.

**Mandar las alertas pendientes que hubiera al migrar a la v3.** Serían SOS
viejos que llegarían tarde y sin contexto; se descartan.

## Riesgos y notas

- **Si el servidor está caído, la app dice "Necesitás conexión a
  internet"**, aunque el teléfono tenga internet. Es una simplificación
  aceptada: para el vecino el efecto es el mismo (no puede usar la app) y
  el 911 sigue a mano. Si el equipo quiere distinguirlo, es otra feature.
- **Modo simulado:** no detecta la falta de internet real (ver arriba). Las
  pruebas usan `ConexionServiceSimulado(conectado: false)` o `ConexionFalsa`.
- **Pruebas con tiempo:** los relojes de 5 s y 30 s se prueban con
  `testWidgets` y `tester.pump(const Duration(seconds: …))` (tiempo
  falso de `flutter_test`), sin agregar `fake_async` como dependencia.
- **Pruebas existentes de la app completa** (`appDePrueba`) siguen andando
  sin cambios porque `ConexionServiceSimulado` arranca conectado. La
  compuerta deja un `Timer.periodic` vivo: `ConViewModel` lo libera al
  desmontar la app, así que no quedan timers pendientes al final de cada
  `testWidgets`.
- El `ClienteApi` agrega el token también al `GET /salud`; la ruta no lo
  mira, así que no molesta.
- Feature 16 `avisos_tardios` depende de esta: con el envío diferido
  quitado, la única demora posible es la de los avisos que llegan tarde al
  teléfono.
