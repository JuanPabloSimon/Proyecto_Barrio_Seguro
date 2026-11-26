# Design — estado_alerta

> Decisiones técnicas tomadas antes de escribir código. Se apoya en
> `docs/architecture.md` y `docs/conventions.md`; acá solo va lo que esta
> feature agrega o donde roza sus límites.

## Punto de partida (código actual, verificado en `feature/estado_alerta`)

- **Detalle** (`lib/ui/alerta_detalle/`): `DetalleAlertaViewModel` recibe
  la `Alerta` por constructor (la pantalla se abre desde el inicio, el
  mapa, "Mis alertas" y el aviso push con `DetalleAlertaScreen.abrir`).
  `puedeCerrarla => esMia && estado != resuelta` (comentario "RF-05").
  `marcarResuelta()` y `marcarFalsaAlarma()` llaman a `_cerrar()`, que
  hace `cambiarEstado(id, resuelta)`, publica `AlertasActualizadas` y
  devuelve `true`; si falla, `error = 'No pudimos cerrar la alerta. Probá
  de nuevo.'`. La pantalla, si sale bien, hace `pop` y muestra un aviso
  ("Marcaste la alerta como resuelta" / "Cancelaste la alerta: falsa
  alarma"). Arriba del título ya se ve `ChipEstado` (ícono + texto +
  color) para todos.
- **Repositorio** (`AlertasRepositoryRemoto.cambiarEstado`): llama al
  servicio, guarda la alerta en la copia local y la **reemplaza en la
  caché**. No llama a `_avisarSiFueLaRed` (a diferencia de `crearAlerta`).
- **Refresco**: `InicioViewModel` recarga con cualquier evento del bus;
  `MapaViewModel` y `MisAlertasViewModel` con `AlertasActualizadas`. Como
  la caché ya tiene la alerta nueva, recargar alcanza. El inicio muestra en
  "Alertas cerca tuyo" solo las no resueltas (`cercanas`). La tarjeta y el
  pin dicen el estado en su etiqueta de lector y con ícono.
- **API** (`backend/lib/src/api.dart`, `_cambiarEstado`): valida el
  estado ("Ese estado no existe.", 400), que la alerta exista (404) y
  después `reportada_por == vecinoId`; si no, 403 "Solo quien reportó la
  alerta puede cambiar su estado.". El rol está en
  `_almacen.vecinos[id]['rol']` (`Roles.comision`), como lo usa
  `soloComision`. No envía push al cambiar el estado.
- **Push del backend** (`backend/lib/src/push_service.dart`):
  `PushService.enviarAlerta(alerta)`; `PushServiceFcm` manda un mensaje
  **de datos** (sin bloque `notification`) al tópico `alertas` con cada
  clave de la alerta como texto y `android.priority: HIGH`, y descarta las
  resueltas. `Api._crearAlerta` llama a `notificarAlerta`, que lo envuelve
  en `try/catch` (si FCM falla, la alerta queda creada).
- **Push en la app** (`lib/data/services/push_service.dart`): solo se
  registra `onBackgroundMessage` (app cerrada o en segundo plano); con la
  app en primer plano los mensajes de FCM no se procesan y el
  `VigilanteDeAlertas` (cada 45 s y al volver a primer plano) avisa las
  alertas nuevas. `procesarAvisoPush` arma la `Alerta` con
  `alertaDesdeDatosPush`, descarta resueltas, avisos apagados y propias,
  guarda la llegada (`AvisosRecibidosRepository.registrarLlegada`, que no
  pisa una llegada anterior) y clasifica con `clasificarAviso(creadaEn,
  llegada)`: a tiempo (`avisarAlerta`), tardío (`avisarAlertaTardia`) o
  nada (más de 2 h). Las notificaciones usan un id por alerta
  (`alerta.id.hashCode`) y el payload `alerta:<id>`; tocarlas abre el
  detalle. Un push de una alerta reabierta tal cual llegaría con un
  `creada_en` viejo y una llegada ya guardada: se descartaría.
- **Servidor simulado** (`cambiarEstadoDeAlerta`): no valida el estado ni
  permisos. No sabe quién tiene la sesión: `ingresar` siempre devuelve a
  Clara (`idVecinaDeEjemplo`, rol `comision`) y el token simulado no viaja
  en los pedidos.
- **SOS** (`SosViewModel.cerrarAlerta`): cierra su propia alerta con
  `cambiarEstado`; no cambia.
- **Pruebas**: `vecinaDePrueba` (falsos) es Clara con rol `vecino` por
  defecto. En la app de prueba (servidor simulado) Clara es `comision`.
  En el backend Clara es `comision` y Rosa `vecino`; `solo quien la
  reportó puede cerrarla (RF-05)` usa a Rosa contra `a1` (de Clara) y
  sigue valiendo.

## Decisiones

### 1. Una sola regla de permiso, en los tres lados

```
puede cambiar el estado  ⇔  vecino.id == alerta.reportadaPor  ||  vecino es comisión
```

- App: `ReglasAlertas.puedeCambiarEstado` en `lib/domain/reglas_alertas.dart`
  (la usan el ViewModel y el servidor simulado).
- Backend: `ReglasAlertas.puedeCambiarEstado` en
  `backend/lib/src/reglas.dart`, con el rol como texto.
- Mismo mensaje en los dos lados:
  `ReglasAlertas.mensajeSinPermisoEstado = 'Solo quien reportó la alerta o la comisión vecinal pueden cambiar su estado.'`.
- El rol se lee **del almacén**, nunca del pedido (igual que
  `soloComision`). En la app, del `Vecino` de la sesión (`SesionRepository.usuario`);
  sin sesión, `false`.
- No se usa el middleware `soloComision` ni una ruta bajo `/comision/`:
  la ruta es la misma para el autor y para la comisión.

### 2. Transiciones libres

Cualquier estado → cualquier otro, también reabrir una resuelta (R6, R24):
el `acceptance` dice "entre Activa, En atención y Resuelta" sin orden.
Reabrir (de Resuelta a Activa o En atención) **manda un aviso push** al
barrio (decisión P3, ver punto 8); ningún otro cambio lo manda. Elegir el
estado actual no hace nada (R8).

### 3. El control: `RadioGroup` con tres `RadioListTile`

Igual que los tipos de "Reportar alerta" (feature 18):

- Encabezado "Estado de la alerta" (`Semantics(header: true)`).
- `RadioGroup<EstadoAlerta>(groupValue: vm.alerta.estado, onChanged: …)`
  con un `RadioListTile` por `EstadoAlerta.values` (orden Activa, En
  atención, Resuelta): `title: Text(estado.etiqueta)`, `secondary:` un
  círculo `estado.colorSuave` con `Icon(estado.icono, color: estado.color)`
  excluido de la semántica (el nombre ya lo dice).
- Mientras cambia: `enabled: false` en las tres y, debajo, una fila con
  `CircularProgressIndicator(semanticsLabel: 'Cambiando el estado')`.
- Error: `Semantics(liveRegion: true)` con `Icons.error_outline` y el
  texto en `AppColors.emergencia` (como el error de envío de la feature 18).
- Confirmación solo al pasar a Resuelta y al reabrir (decisión P2, ver
  punto 7).
- El detalle **no se cierra** (R10). El aviso "Cambiaste el estado a
  <etiqueta>." se muestra con `mostrarAviso` en el mismo `Scaffold`.

Ubicación en la pantalla: donde hoy están los botones de cierre, después
de "Llamar al 911" (que no se mueve) y antes de "Fue una falsa alarma"
(R32).

### 4. "Marcar como resuelta" y "Fue una falsa alarma"

- **"Marcar como resuelta" se quita** (R19): hace lo mismo que la opción
  Resuelta y tener las dos cosas confunde.
- **"Fue una falsa alarma" queda como hoy** (R20): solo para quien la
  reportó, solo si no está resuelta, deja la alerta resuelta, cierra el
  detalle y muestra "Cancelaste la alerta: falsa alarma". El getter
  `puedeCerrarla` pasa a llamarse `puedeMarcarFalsaAlarma` (misma regla).
  Decisión P1 (a). Sigue sin confirmación, como hoy.

### 5. Servidor simulado: sabe quién tiene la sesión

`ServidorSimulado` guarda `_vecinoDeLaSesion` (empieza en
`idVecinaDeEjemplo`, igual que `ingresar`). `ingresar` lo pone en
`idVecinaDeEjemplo` y `registrar` en el id nuevo. `cambiarEstadoDeAlerta`
aplica, en el mismo orden que la API: estado válido ("Ese estado no
existe."), alerta existente ("No encontramos esa alerta.") y
`ReglasAlertas.puedeCambiarEstado` (`ErrorDelServidor(mensajeSinPermisoEstado)`).

Así se prueba el rol vecino común contra el simulado: `registrar` deja la
sesión en un vecino común.

### 6. Errores

`cambiarEstado(EstadoAlerta nuevo)` del ViewModel:

- `ErrorDelServidor` → `error = e.mensaje` (R16; por ejemplo el 403 si a
  alguien le sacaron el rol de comisión con el detalle abierto).
- Otro error → `error = 'No pudimos cambiar el estado. Probá de nuevo.'`
  (R17).
- En los dos casos `_alerta` no cambia (R18). El `RadioGroup` lee
  `vm.alerta.estado`, así que la opción vuelve sola a la anterior.

No se cambia el repositorio: que `cambiarEstado` también pida una
comprobación de la conexión ante un error de red queda fuera (ver Riesgos).

### 7. Confirmación (decisión P2)

**Cuándo.** Se confirma en dos casos y en ninguno más:

| Estado actual | Elige | Confirma | Por qué |
|---|---|---|---|
| Activa / En atención | Resuelta | Sí, diálogo "resolver" (R33) | La saca de "Alertas cerca tuyo" de todo el barrio: es el cierre, igual que "Ya estoy a salvo" del SOS |
| Resuelta | Activa / En atención | Sí, diálogo "reabrir" (R34) | Manda un aviso push a todo el barrio (punto 8), que no se puede deshacer |
| Activa ↔ En atención | — | No (R7) | No saca la alerta de ningún lado ni avisa a nadie; se deshace con otro toque |
| Igual al actual | — | No, no pasa nada (R8) | — |

La regla es pura y vive en el archivo del ViewModel:
`confirmacionParaCambio(actual, nuevo)` devuelve
`ConfirmacionCambioEstado.resolver`, `.reabrir` o `null`.

**El diálogo** sigue el patrón de `confirmar_cierre_sos.dart` y
`confirmar_descarte.dart`, en
`lib/ui/alerta_detalle/widgets/confirmar_cambio_estado.dart`:
`showDialog<bool>` con `AlertDialog(scrollable: true,
actionsOverflowButtonSpacing: 8)`, `OutlinedButton` (no) y `FilledButton`
(sí), los dos con `minimumSize: Size(0, 48)`; devuelve `confirmo ?? false`.

| | Resolver (R33) | Reabrir (R34) |
|---|---|---|
| Ícono (32 dp) | `Icons.check_circle_outline`, `AppColors.resuelta` | `Icons.notifications_active_outlined`, `AppColors.texto` |
| Título | "¿Marcar la alerta como resuelta?" | "¿Volver a abrir la alerta?" |
| Texto | "Va a dejar de aparecer en "Alertas cerca tuyo". Si hace falta, la podés volver a abrir desde acá." | "Va a quedar como <etiqueta> y se les va a avisar a los vecinos del barrio." |
| No (`OutlinedButton`) | "No, dejarla como está" | "No, dejarla resuelta" |
| Sí (`FilledButton`) | "Sí, está resuelta" (fondo `AppColors.resuelta`, como "Sí, estoy a salvo") | "Sí, volver a abrirla" (color por defecto, `AppColors.primary`) |

Ningún botón dice "Cancelar" (mismo motivo que en el SOS: se confunde con
cancelar la alerta).

**Cancelar.** "No, …", tocar fuera (`barrierDismissible` por defecto) y
Atrás devuelven `false`: no se llama a `vm.cambiarEstado`, no hay aviso
ni error (R36, R37). El `RadioGroup` lee `vm.alerta.estado`, así que la
opción elegida nunca se movió: durante el diálogo y después sigue el
estado actual. Confirmar llama a `vm.cambiarEstado(nuevo)` y sigue el
camino de R9 a R18 (R35).

**Dónde.** La confirmación es de la pantalla (necesita `BuildContext`),
no del ViewModel: `vm.cambiarEstado` no pregunta nada, y así las pruebas
del ViewModel no cambian. "Fue una falsa alarma" sigue sin confirmación
(P1 (a): queda como hoy).

### 8. Aviso push al reabrir: backend (decisión P3)

- `PushService` suma
  `enviarReapertura(Map<String, dynamic> alerta, {required DateTime reabiertaEn})`.
  `PushServiceNinguno` no hace nada. `PushServiceFcm` descarta las
  resueltas y manda el mismo mensaje de datos que `enviarAlerta` (tópico
  `alertas`, `android.priority: HIGH`) con dos claves más:
  `aviso: "reabierta"` (`PushServiceFcm.avisoReabierta`) y
  `reabierta_en: "<ms>"`. El armado del mensaje se comparte en un método
  privado `_enviar(Map<String, String> datos)`.
- `Api._cambiarEstado` guarda el estado anterior; después de guardar,
  si `anterior == 'resuelta' && estado != 'resuelta'`, llama a
  `_notificarReapertura(_conNombre(alerta))`, que hace
  `await _push.enviarReapertura(alerta, reabiertaEn: _reloj.ahora())`
  dentro de `try/catch` (como `notificarAlerta`): si FCM falla, el estado
  ya quedó guardado y responde 200 (R44).
- El push sale **después** de todas las validaciones; un 400, 401, 403 o
  404 no llega hasta ahí (R43). Cualquier otro cambio, incluido elegir el
  mismo estado, no lo llama (R42).
- Datos: las claves de la alerta con `reportada_por_nombre` (como el push
  de una alerta nueva) más `aviso` y `reabierta_en`. **No** viaja quién la
  reabrió (R45; además, P4 dice que eso no se guarda).
- No se guarda nada nuevo en el almacén: `reabierta_en` solo viaja en el
  push.
- El servidor simulado de la app no manda push (como hoy al crear).

### 9. Aviso de reapertura en la app (decisión P3)

**Con la app cerrada o en segundo plano** (`procesarAvisoPush`): si
`datos['aviso'] == avisoPushReabierta` (`'reabierta'`), va por otro
camino:

1. `alertaDesdeDatosPush(datos)` y `reabiertaEnDesdeDatosPush(datos)`
   (entero o texto en ms); si alguno es null o la alerta está resuelta,
   no avisa (R51).
2. Avisos apagados → no avisa (R50). Alerta reportada por el vecino de la
   sesión → no avisa (R49). Es la misma regla que el aviso de alerta
   nueva: quien reabre está con la app en primer plano (acaba de tocar
   el control) y el push no se procesa ahí; quien la reportó ya la
   conoce y, si la reabrió la comisión, la ve en "Mis alertas".
3. **No** se llama a `registrarLlegada` (R52): la llegada guardada es la
   del aviso original y es la que decide la marca de "tardía" de la
   alerta. Para medir la demora se usa
   `AvisosRecibidosRepository.horaDelServidor()` (nuevo: hora del
   teléfono + desfase guardado, sin guardar nada).
4. `clasificarAviso(creadaEn: reabiertaEn, llegada: horaDelServidor)`
   (mismos umbrales de 5 min y 2 h): a tiempo →
   `notificaciones.avisarReapertura(alerta)` (R46); tardío →
   `notificaciones.avisarReaperturaTardia(alerta, reabiertaEn)` (R47);
   demasiado tardío → nada (R48).

Un mensaje sin `aviso` sigue exactamente el camino de hoy.

**Textos** (puros, en `lib/domain/avisos_tardios.dart`, junto a los del
aviso tardío):

- `tituloAvisoReapertura(alerta)` → "Se reabrió una alerta: <tipoParaAviso>"
  ("Se reabrió una alerta: SOS", "Se reabrió una alerta: Robo").
- `tituloAvisoReaperturaTardia(alerta, reabiertaEn)` → el anterior +
  " " + `horaYMinutos(reabiertaEn)` ("Se reabrió una alerta: Robo 15:10").
- `cuerpoAvisoReapertura(alerta)` → "<dirección>. Tocá para ver dónde.";
  con la dirección vacía, "Tocá para ver dónde.".
- El cuerpo del tardío es `cuerpoAvisoTardio`, sin cambios.

`NotificacionesServiceLocales` los muestra con el mismo `_mostrar`: mismo
canal "Alertas del barrio", mismo id por alerta (reemplaza a la
notificación anterior de esa alerta, no se apila) y mismo payload
`alerta:<id>`, así que tocarla abre el detalle por el camino de hoy
(`alertasTocadas` → `DetalleAlertaScreen.abrir`).

**Con la app abierta** (`VigilanteDeAlertas.revisar`): además de
`_conocidas`, guarda `_resueltas` (ids resueltas en la revisión
anterior). Reabiertas = alertas que estaban en `_resueltas` y ahora no
están resueltas. Si hay alguna, publica `AlertasActualizadas` (R54, como
con las nuevas) y, con los avisos activos, llama a
`avisarReapertura(alerta)` por cada una que no reportó el vecino de la
sesión (R53, R55). No clasifica demora (el vigilante no conoce
`reabierta_en`; revisa cada 45 s) y no toca las llegadas.
`revisar()` sigue devolviendo solo las alertas nuevas avisadas; las
reaperturas avisadas se ven en `NotificacionesFalsas.reaperturas`.

## Archivos a crear o cambiar

| Capa | Archivo | Cambio |
|---|---|---|
| domain | `lib/domain/reglas_alertas.dart` | `mensajeSinPermisoEstado` y `puedeCambiarEstado`; importa `models/vecino.dart` |
| domain | `lib/domain/avisos_tardios.dart` | `tituloAvisoReapertura`, `tituloAvisoReaperturaTardia`, `cuerpoAvisoReapertura` |
| data | `lib/data/services/simulados/servidor_simulado.dart` | `_vecinoDeLaSesion`; `ingresar`/`registrar` lo fijan; `cambiarEstadoDeAlerta` valida estado, existencia y permiso |
| data | `lib/data/repositories/avisos_recibidos_repository.dart` | `horaDelServidor()` en la interfaz y en `AvisosRecibidosRepositoryLocal` |
| data | `lib/data/services/notificaciones_service.dart` | `avisarReapertura` y `avisarReaperturaTardia` en la interfaz, `NotificacionesServiceLocales` (con `_mostrar`) y `NotificacionesServiceNinguno` |
| data | `lib/data/services/push_service.dart` | `avisoPushReabierta`, `reabiertaEnDesdeDatosPush`; `procesarAvisoPush` con el camino de reapertura |
| ui | `lib/ui/alerta_detalle/view_models/detalle_alerta_view_model.dart` | `puedeCambiarEstado`, `cambiandoEstado`, `cambiarEstado(EstadoAlerta)`, `mensajeErrorCambioEstado`, `ConfirmacionCambioEstado`, `confirmacionParaCambio`; `puedeCerrarla` → `puedeMarcarFalsaAlarma`; se borra `marcarResuelta` |
| ui | `lib/ui/alerta_detalle/widgets/confirmar_cambio_estado.dart` | Nuevo: `confirmarCambioDeEstado` (los dos diálogos) |
| ui | `lib/ui/alerta_detalle/widgets/detalle_alerta_screen.dart` | Control de estado (`_ControlDeEstado`, clase de widget aparte) que confirma según `confirmacionParaCambio`; se quita "Marcar como resuelta"; "Fue una falsa alarma" con `puedeMarcarFalsaAlarma` |
| ui | `lib/ui/principal/vigilante_de_alertas.dart` | `_resueltas`; detecta reaperturas, publica `AlertasActualizadas` y avisa con `avisarReapertura` |
| armado | `lib/dependencias.dart` | Sin cambios: `DetalleAlertaScreen.abrir` ya pasa `sesion`, `alertas` y `bus`; el vigilante ya recibe `notificaciones`, `preferencias`, `sesion` y `bus` |
| backend | `backend/lib/src/reglas.dart` | `ReglasAlertas.mensajeSinPermisoEstado` y `puedeCambiarEstado` |
| backend | `backend/lib/src/push_service.dart` | `enviarReapertura` en `PushService`, `PushServiceNinguno` y `PushServiceFcm` (`avisoReabierta`, `_enviar` compartido); comentario de la clase: "alerta nueva o reabierta" |
| backend | `backend/lib/src/api.dart` | `_cambiarEstado` usa `ReglasAlertas.puedeCambiarEstado` con el rol del almacén; comentario "RF-05 ampliado: también la comisión"; `_notificarReapertura` al pasar de `resuelta` a `activa`/`en_atencion` |
| backend | `backend/README.md` | Fila de `PATCH /alertas/<id>`: "quien la reportó o la comisión; si reabre una resuelta, manda un aviso push"; fila 403 del cuadro de errores; párrafo del push con las claves `aviso` y `reabierta_en` |
| pruebas | `test/ayudas/falsos.dart` | `miembroDeLaComision` (id `marta`, rol `comision`); `AlertasFalsas.errorAlCambiar` (`ErrorDelServidor?`) y `demoraAlCambiar` (`Completer?` para demorar la respuesta); `NotificacionesFalsas.reaperturas` y `reaperturasTardias`; `AvisosRecibidosFalsos.horaDelServidor` (devuelve `ahora`) |
| pruebas | `test/unit/dominio_test.dart`, `test/unit/repositorios_test.dart`, `test/unit/notificaciones_test.dart`, `test/unit/view_models_test.dart`, `test/widget_test.dart`, `test/accesibilidad_test.dart`, `backend/test/reglas_test.dart`, `backend/test/api_test.dart` | Ver `tasks.md` |

## Firmas nuevas

```dart
// lib/domain/reglas_alertas.dart
class ReglasAlertas {
  // … lo de la feature 18 sin cambios.

  static const mensajeSinPermisoEstado =
      'Solo quien reportó la alerta o la comisión vecinal pueden cambiar su estado.';

  /// Quien la reportó o un miembro de la comisión. Sin sesión, false.
  static bool puedeCambiarEstado({
    required String reportadaPor,
    required Vecino? vecino,
  });
}

// backend/lib/src/reglas.dart
class ReglasAlertas {
  static const mensajeSinPermisoEstado = '…mismo texto…';

  /// [rol] es el guardado en el almacén ('vecino' o 'comision').
  static bool puedeCambiarEstado({
    required String reportadaPor,
    required String vecinoId,
    required String? rol,
  });
}

// lib/ui/alerta_detalle/view_models/detalle_alerta_view_model.dart
const mensajeErrorCambioEstado = 'No pudimos cambiar el estado. Probá de nuevo.';

/// "Cambiaste el estado a En atención."
String avisoCambioDeEstado(EstadoAlerta estado); // usa la etiqueta en ui/core

class DetalleAlertaViewModel extends ChangeNotifier {
  // constructor sin cambios

  /// R1, R2, R3: quien la reportó o la comisión.
  bool get puedeCambiarEstado;

  /// R20: igual que el `puedeCerrarla` de hoy.
  bool get puedeMarcarFalsaAlarma;

  /// True mientras se espera la respuesta de [cambiarEstado] (R9).
  bool get cambiandoEstado;

  /// Si [nuevo] es el estado actual o no tiene permiso, no hace nada y
  /// devuelve false. Si el servidor confirma, reemplaza [alerta], publica
  /// AlertasActualizadas y devuelve true. Si falla, deja [alerta] como
  /// estaba y llena [error] (R16, R17, R18).
  Future<bool> cambiarEstado(EstadoAlerta nuevo);

  Future<bool> marcarFalsaAlarma(); // sin cambios
}

/// Qué diálogo pide pasar de un estado a otro (decisión P2).
enum ConfirmacionCambioEstado { resolver, reabrir }

/// resolver: de Activa o En atención a Resuelta. reabrir: de Resuelta a
/// Activa o En atención. null: entre Activa y En atención o al mismo
/// estado.
ConfirmacionCambioEstado? confirmacionParaCambio(
  EstadoAlerta actual,
  EstadoAlerta nuevo,
);

// lib/ui/alerta_detalle/widgets/confirmar_cambio_estado.dart
/// True solo con "Sí, está resuelta" / "Sí, volver a abrirla"; el botón
/// "No, …", tocar fuera o Atrás devuelven false. [nuevo] da la etiqueta
/// del texto de "reabrir".
Future<bool> confirmarCambioDeEstado(
  BuildContext context, {
  required ConfirmacionCambioEstado confirmacion,
  required EstadoAlerta nuevo,
});

// lib/domain/avisos_tardios.dart
String tituloAvisoReapertura(Alerta alerta);
String tituloAvisoReaperturaTardia(Alerta alerta, DateTime reabiertaEn);
String cuerpoAvisoReapertura(Alerta alerta);

// lib/data/repositories/avisos_recibidos_repository.dart
abstract class AvisosRecibidosRepository {
  // … lo de hoy sin cambios.

  /// Hora del teléfono + desfase guardado (hora del servidor). No guarda
  /// nada.
  Future<DateTime> horaDelServidor();
}

// lib/data/services/notificaciones_service.dart
abstract class NotificacionesService {
  // … lo de hoy sin cambios.

  /// R46. Mismo id y payload que avisarAlerta.
  Future<void> avisarReapertura(Alerta alerta);

  /// R47. Mismo id y payload que avisarAlerta.
  Future<void> avisarReaperturaTardia(Alerta alerta, DateTime reabiertaEn);
}

// lib/data/services/push_service.dart
const avisoPushReabierta = 'reabierta';

/// `reabierta_en` del mensaje (entero o texto, en ms) o null.
DateTime? reabiertaEnDesdeDatosPush(Map<String, dynamic> datos);

// backend/lib/src/push_service.dart
abstract class PushService {
  Future<void> enviarAlerta(Map<String, dynamic> alerta); // sin cambios

  /// Aviso de una alerta resuelta que se volvió a abrir. [alerta] ya trae
  /// el estado nuevo; si está resuelta, no envía nada.
  Future<void> enviarReapertura(
    Map<String, dynamic> alerta, {
    required DateTime reabiertaEn,
  });
}
// PushServiceFcm: static const avisoReabierta = 'reabierta';
```

`avisoCambioDeEstado` vive en el archivo del ViewModel e importa
`ui/core/presentacion_alerta.dart` para la etiqueta (el ViewModel ya está
en `ui/`, no hay import de widgets). `cambiandoEstado` y el
`EstadoCarga.cargando` de `marcarFalsaAlarma` comparten el mismo
`_estado`: mientras uno corre, el otro está deshabilitado.

La pantalla: `onChanged` del `RadioGroup` toma el `ScaffoldMessenger`
**antes** de cualquier `await`; si `nuevo` es el estado actual, no hace
nada; si `confirmacionParaCambio(actual, nuevo)` no es null, espera
`confirmarCambioDeEstado` y, si da `false` o el `context` ya no está
montado, vuelve sin hacer nada; después llama a `vm.cambiarEstado(nuevo)`
y, si devuelve `true`, `mostrarAvisoEn(mensajero,
avisoCambioDeEstado(nuevo))`.

## Pantalla (orden de lectura, R32)

1. Mapa (imagen con etiqueta, sin cambios).
2. `ChipEstado` + "hace…" + marca de tardía (sin cambios, R4).
3. Título, descripción, ubicación, "Reportada por" (sin cambios).
4. "Llamar al 911" (sin cambios).
5. Si `puedeCambiarEstado`: encabezado "Estado de la alerta", los tres
   `RadioListTile`, el indicador "Cambiando el estado" (si cambia) y el
   error en `liveRegion` (si hay). Al pasar a Resuelta o reabrir, antes
   del cambio se abre el diálogo de confirmación (ruta modal aparte).
6. Si `puedeMarcarFalsaAlarma`: `TextButton` "Fue una falsa alarma".

## API y datos

- `PATCH /alertas/<id>`: mismo cuerpo (`{estado}`) y respuesta (la alerta
  con `reportada_por_nombre`). Cambia **quién** puede: quien la reportó o
  la comisión. 403 al resto con `mensajeSinPermisoEstado` (antes "Solo
  quien reportó la alerta puede cambiar su estado."). Orden de chequeo
  igual que hoy: sesión (401), estado (400), existe (404), permiso (403).
- Aviso push (FCM, mensaje de datos al tópico `alertas`): el de una
  alerta nueva no cambia. Nuevo: el de reapertura, con las mismas claves
  (valores como texto) más `aviso: "reabierta"` y `reabierta_en: "<ms>"`.
  Una app vieja que lo reciba lo trata como un push común: con su
  `creada_en` viejo casi siempre lo descarta por demasiado tardío.
- JSON de los modelos: sin cambios.
- sqflite: sin cambios (el repositorio ya guarda la alerta actualizada).
- Datos de ejemplo: sin cambios.

## Plataforma

El control y los diálogos no dependen de la plataforma. El aviso push de
reapertura llega solo donde hoy llega el de una alerta nueva
(`PushServiceFirebase`); donde se usa `PushServiceNinguno` o
`NotificacionesServiceNinguno`, no hay aviso, igual que hoy. No cambia
`Capacidades` ni `Politicas`.

## Accesibilidad

- **48 dp**: `RadioListTile` mide al menos 56 dp de alto y todo el ancho
  (R27). Lo controlan `androidTapTargetGuideline` e
  `iOSTapTargetGuideline` con las entradas nuevas de
  `test/accesibilidad_test.dart`.
- **Etiquetas**: encabezado con `header: true`; cada opción se anuncia por
  su texto y el estado elegido del radio (R28). El ícono va en
  `ExcludeSemantics`.
- **No solo color**: cada opción tiene ícono y nombre; el `ChipEstado` de
  arriba también (R29). Contraste: solo colores de `AppColors` ya probados
  (`colorSuave` de fondo con `color` encima, como `TarjetaAlerta`).
- **Errores**: `liveRegion` con ícono (R30). El aviso de éxito es un
  `SnackBar`, que el lector anuncia.
- **200 %**: todo sigue en el `ListView` del detalle; los `RadioListTile`
  crecen hacia abajo (R31).
- **Orden**: el del punto "Pantalla" (R32).
- **Diálogos de confirmación** (R38 a R40): botones con
  `minimumSize: Size(0, 48)`; `scrollable: true` y
  `actionsOverflowButtonSpacing: 8` para el 200 % (los botones se apilan);
  `AlertDialog` ya da `scopesRoute`/`namesRoute` con el título, así que el
  lector lo anuncia al abrirse y cada botón por su texto. Mismo patrón y
  mismos colores que `confirmar_cierre_sos.dart` (verde `resuelta` con
  texto blanco ya está en `paresDeContraste`). Se prueban con entradas
  nuevas en `test/accesibilidad_test.dart`.
- **Notificación de reapertura**: título y cuerpo en texto (el lector del
  sistema los lee), mismo canal "Alertas del barrio" que ya se puede
  silenciar desde los ajustes.

## Paquetes nuevos

Ninguno. `RadioGroup` es de Flutter y ya se usa en la feature 18.

## Alternativas descartadas

**`SegmentedButton` con los tres estados.** Se descarta: con el texto al
200 % "En atención" no entra en un tercio de 328 dp y los segmentos cortan
el texto o desbordan.

**`DropdownButton` / menú.** Se descarta: esconde las opciones detrás de
un toque más y el menú desplegable es más difícil de usar con lector de
pantalla y para personas mayores.

**Botones por transición ("Pasar a En atención", "Marcar como resuelta",
"Reabrir").** Se descarta: con tres estados libres son seis transiciones
y la pantalla cambiaría de botones según el estado; tres opciones fijas
muestran siempre lo mismo y marcan cuál es la actual.

**Ruta nueva solo para la comisión (`PATCH /comision/alertas/<id>`).** Se
descarta: duplicaría la ruta y la app tendría que elegir a cuál llamar
según el rol; la regla es una sola y vive en `ReglasAlertas`.

**Cerrar el detalle después de cambiar (como hoy).** Se descarta: el
`acceptance` pide que el estado se actualice "en el detalle", y quien
pone "En atención" suele querer seguir viendo la alerta.

**Que el servidor simulado reciba el id del vecino en el pedido.** Se
descarta: cambiaría la firma de `AlertasService.cambiarEstado`, que
cumplen también el servicio HTTP y los falsos; la API real lo saca del
token, y el simulado imita eso guardando la sesión.

**Confirmar todos los cambios de estado.** Se descarta: entre Activa y En
atención no saca la alerta de ningún lado ni avisa a nadie, y un diálogo
en cada toque cansa (sobre todo a la comisión, que lo usa seguido). Se
confirma solo lo que tiene efecto en todo el barrio.

**Confirmar con un `SnackBar` "Deshacer" en vez de un diálogo.** Se
descarta: el aviso push de la reapertura sale apenas el servidor guarda
y no se puede deshacer; además el proyecto ya confirma con diálogo (SOS,
descarte).

**Push de reapertura con el mismo formato que el de una alerta nueva.**
Se descarta: la app lo clasificaría por `creada_en` (viejo) y con la
llegada ya guardada del aviso original, y lo descartaría casi siempre.
Hacen falta `aviso` y `reabierta_en`.

**Guardar `reabierta_en` en la alerta (almacén y modelo).** Se descarta:
cambiaría el JSON y la base local para algo que solo necesita el push; y
P4 dejó fuera guardar datos del cambio de estado.

**Avisar la reapertura solo con la app cerrada (sin el vigilante).** Se
descarta: con la app abierta FCM no procesa el mensaje y el vecino no se
enteraría; el vigilante ya cumple ese papel para las alertas nuevas.

## Decisiones de la aprobación

Respuestas de la persona a las preguntas abiertas del spec (textual: "1.
a 2. si pedir confirmacion 3. si mandamos un aviso push si se re abre la
alerta"; P4: "no hace falta").

- **P1 — "Fue una falsa alarma" en el detalle → (a).** Queda como hoy:
  solo quien la reportó, solo si no está resuelta, cierra el detalle, sin
  confirmación. R20 sin cambios.
- **P2 — Confirmación → sí.** Al pasar a Resuelta y al reabrir; no entre
  Activa y En atención (punto 7). R7 cambia; nuevos R33 a R40.
- **P3 — Aviso push al reabrir → sí, dentro de esta feature.** Solo al
  pasar de Resuelta a Activa o En atención (puntos 8 y 9). Nuevos R41 a
  R55.
- **P4 — Quién cambió el estado → no.** No se guarda ni se muestra quién
  hizo el último cambio. Queda fuera de alcance; el aviso de reapertura
  tampoco lo lleva (R45).

No quedan preguntas abiertas.

## Pruebas existentes que cambian

- `test/unit/view_models_test.dart` › `DetalleAlertaViewModel`:
  `solo quien la reportó puede cerrarla` pasa a usar
  `puedeMarcarFalsaAlarma`; `marcarla resuelta cambia su estado de verdad`
  y `si falla muestra un mensaje y la alerta sigue abierta` se reescriben
  con `cambiarEstado(EstadoAlerta.resuelta)` (el segundo, con el mensaje
  nuevo).
- `backend/test/api_test.dart` › `solo quien la reportó puede cerrarla
  (RF-05)`: se renombra a `un vecino común no puede cambiar el estado de
  una alerta ajena` y además comprueba el mensaje nuevo. Las otras pruebas
  que hacen `PATCH` con Clara (autora o comisión) siguen pasando.
- `test/unit/repositorios_test.dart:533` (`cambiarEstadoDeAlerta('a1',
  'resuelta')` del simulado): sigue pasando, la sesión empieza en Clara.
- `test/accesibilidad_test.dart` › `Detalle de alerta` y `Detalle de una
  alerta SOS`: con la app de prueba Clara es comisión, así que ya muestran
  el control y pasan a cubrirlo.
- `backend/test/api_test.dart` › `PushServiceFalso`: tiene que implementar
  `enviarReapertura` (lista `reaperturas` con la alerta y `reabiertaEn`;
  con `falla` tira, como `enviarAlerta`). Las pruebas que hoy hacen
  `PATCH` a `resuelta` siguen igual y además no deben enviar nada.
- `test/ayudas/falsos.dart` › `NotificacionesFalsas` y
  `AvisosRecibidosFalsos`: implementan los métodos nuevos; las pruebas de
  `test/unit/notificaciones_test.dart` que ya existen no cambian (los
  mensajes sin `aviso` siguen el camino de hoy).
- Pruebas que hoy eligen Resuelta en el detalle (las nuevas de este spec
  y cualquiera que use "Marcar como resuelta") tienen que tocar "Sí, está
  resuelta" en el diálogo.

## Riesgos y notas

- **RF-05 cambia.** La comisión puede cambiar el estado de cualquier
  alerta. Hay que actualizar el comentario en `api.dart`, el README y el
  nombre de la prueba del backend.
- El detalle muestra la alerta que recibió al abrirse: si otro vecino la
  cambió mientras tanto, se ve el estado viejo hasta que se cambie o se
  vuelva a abrir. El servidor acepta el cambio igual (última escritura
  gana). Es lo que pasa hoy con "Marcar como resuelta".
- Si a un vecino le quitan el rol de comisión con la sesión abierta, la
  app sigue mostrando el control (el rol está en la sesión guardada) y el
  servidor responde 403: se ve el mensaje tal cual (R16).
- `AlertasRepositoryRemoto.cambiarEstado` no pide comprobar la conexión
  ante un error de red; la compuerta igual aparece en el próximo ciclo. Se
  deja así para no ampliar el alcance.
- El servidor simulado arranca con la sesión en Clara (comisión) aunque la
  sesión de la app se haya restaurado de otra cuenta: es la misma
  simplificación que ya tiene `ingresar`.
- **Push y vigilante a la vez.** Si el push de reapertura llega en
  segundo plano y después el vigilante, al volver a primer plano, ve la
  misma reapertura, se muestra dos veces pero con el mismo id de
  notificación: la segunda reemplaza a la primera, no se apilan.
- El vigilante, al volver a primer plano después de horas, avisa como "a
  tiempo" una reapertura vieja (no conoce `reabierta_en`). Es poco
  probable y el aviso abre el detalle con el estado real. Se acepta.
- Reabrir y volver a resolver muchas veces manda un push por cada
  reapertura. No se limita: lo hace solo quien la reportó o la comisión,
  y cada reapertura pide confirmación.
- La reapertura de un SOS avisa con "Se reabrió una alerta: SOS", no con
  el título urgente del SOS nuevo ("SOS: un vecino pidió ayuda").
- `PATCH` espera a que FCM responda antes de contestar (igual que
  `POST /alertas`); si FCM tarda, el indicador "Cambiando el estado" dura
  más.
