# Design — guardia_normal_mayores

> Decisiones técnicas tomadas antes de escribir código. Se apoya en
> `docs/architecture.md` y `docs/conventions.md`; acá solo va lo que esta
> feature agrega o donde roza sus límites.

## Punto de partida (código actual, verificado en `feature/guardia_normal_mayores`)

- **Regla de la app** (`lib/domain/reglas_turnos.dart`):
  `edadGuardiaVentana = 70`, `cupoPatrulla = 2`, `maxTurnosPorMes = 2`,
  `esGuardiaVentana(int edad) => edad >= 70` y
  `motivoNoDisponible({vecino, turno, turnosEnElMes, hoy})`, que pregunta
  `vecino.esGuardiaVentanaEn(hoy)` para decidir si mira el lugar de guardia
  ("Este turno ya tiene guardia de ventana.") o el cupo de la patrulla ("La
  patrulla de este turno ya está completa.").
- **`Vecino`** (`lib/domain/models/vecino.dart`): `esGuardiaVentanaEn(hoy)`
  llama a `ReglasTurnos.esGuardiaVentana(edadEn(hoy))`. Tiene `rol`
  (feature 13), que viaja en el JSON; `copyWith` no recibe `rol` a
  propósito.
- **Quién usa `esGuardiaVentanaEn`**: `PerfilViewModel.esGuardiaVentana` y
  `rol` (el chip "Turnos: patrullaje" / "Turnos: guardia de ventana");
  `TurnosViewModel.esGuardiaVentana` (texto del botón "Anotarme" / "Anotarme
  como guardia de ventana", `_ResumenCupo`, ícono propio del calendario y
  `detalleDe` de "Mis turnos"); `InicioViewModel._resumir` (título y líneas
  del próximo turno); `ServidorSimulado.anotarse` (dónde lo pone).
  `RegistroViewModel` usa `ReglasTurnos.esGuardiaVentana(edad)` directo
  para el aviso "Vas a participar como guardia de ventana" (no cambia).
- **Regla del backend** (`backend/lib/src/reglas.dart`): copia de la de la
  app con `esGuardiaVentana(DateTime nacimiento, DateTime hoy)` y
  `motivoNoDisponible({vecinoId, nacimiento, patrulleros, guardiaVentana,
  turnosEnElMes, hoy})`. `_anotarse` en `backend/lib/src/api.dart` llama a
  `motivoNoDisponible` y después decide con `esGuardiaVentana` si va a
  `guardia_ventana` o a `patrulleros`.
- **Datos del vecino en el servidor**: `Almacen.vecinos[id]` (mapa JSON,
  el mismo que ve la app). `_leer` normaliza el `rol`; `_cargarEjemplos`
  copia `vecinosDeEjemplo` tal cual. `_registrar` arma el mapa a mano.
  `_actualizarVecino` (`PUT /vecinos/<id>`) solo copia `nombre`,
  `telefono`, `calle` y `cuadra` y rechaza con 403 un `rol` distinto.
- **Sesión en la app**: `SesionRepositoryRemoto` guarda el vecino entero en
  `Preferencias` con `toJson` y lo lee con `fromJson`; `actualizarDatos`
  quita `id` y `rol` del cuerpo y guarda lo que devuelve el servidor.
- **Servidor simulado**: `actualizarVecino` copia `...datos` encima del
  vecino guardado (salvo `id`, `fecha_nacimiento`, `vecino_desde`, `rol`);
  `anotarse` usa `Vecino.fromJson` y `esGuardiaVentanaEn`. La sesión del
  simulado es siempre Clara (45 años).
- **Perfil** (`lib/ui/perfil/`): chip "Turnos: …", sección "Privacidad y
  avisos" (dos `SwitchListTile` que guardan en el teléfono) y "Cuenta".
  `PerfilViewModel` recibe `bus` pero no lo guarda; escucha
  `PerfilActualizado` para redibujarse.
- **Eventos**: `TurnosViewModel` escucha solo `TurnosActualizados`;
  `InicioViewModel` escucha todos los eventos y recarga.
- **Copia local**: el vecino de la sesión va en preferencias (JSON); los
  vecinos de cada turno van como JSON en columnas de texto de la tabla
  `turnos` (`Turno.toMap` quita `rol`).

## Decisiones

### 1. Dónde vive la preferencia: en el servidor, en los datos del vecino

Campo `guardia_normal` (booleano, `false` por defecto) en
`Almacen.vecinos[id]`, el mismo mapa que la API devuelve como "vecino". El
servidor es quien aplica la regla al anotar, así que lee el valor de su
almacén, nunca del pedido de anotarse. La app lo recibe con el vecino
(ingresar, registrarse, `GET /vecinos/yo`, `PUT /vecinos/<id>`) y lo guarda
con la sesión, como el rol. No se guarda en `Preferencias` como dato
aparte.

Valor por defecto `false` en todos los lugares donde puede faltar: JSON de
la app (`Vecino.fromJson`), sesión vieja en el teléfono (sale de
`fromJson`), archivo de datos viejo del servidor (`Almacen._leer`), datos
de ejemplo y registro (R2, R29 a R31, R46).

### 2. Una sola regla: "hace guardia de ventana"

Hoy "guardia de ventana" significa "70 o más". Pasa a significar "70 o más
y sin guardia normal". Se agrega la regla en `ReglasTurnos` (app y backend)
y `Vecino.esGuardiaVentanaEn(hoy)` la usa. Como todos los consumidores de la
app (perfil, turnos, inicio, servidor simulado, `motivoNoDisponible`) ya
pasan por `esGuardiaVentanaEn`, siguen la preferencia sin tocarlos uno por
uno. `ReglasTurnos.esGuardiaVentana(int edad)` queda como está ("por la
edad") porque lo usa el registro, donde todavía no hay preferencia.

Con la guardia normal activada, `motivoNoDisponible` mira el cupo de la
patrulla y el máximo por mes, igual que para un menor: "las mismas reglas
que el resto" (R6, R23, R24, R38, R40, R41).

### 3. Cómo se cambia: `PUT /vecinos/<id>` con `{"guardia_normal": bool}`

Se reutiliza la ruta de los datos propios (ya controla que sea el mismo
vecino, 403 si no). Reglas nuevas, en este orden y **antes** de tocar nada
(R36):

1. Si el cuerpo trae `guardia_normal` y no es `bool` → 400 "La opción de
   guardia normal no es válida." (R35).
2. Si trae `true` y el vecino tiene menos de 70 hoy → 409 "Solo los vecinos
   de 70 años o más pueden elegir la guardia normal." (R34). 409 porque
   choca con una regla de negocio (`docs/conventions.md`); el 403 queda
   para permisos.
3. Si trae un `bool` válido → se guarda (R32, R33). Si no lo trae, queda el
   que estaba (R37).

`false` siempre se acepta, también para un menor: es el valor por defecto y
no cambia nada.

En la app, un método aparte de la sesión (`cambiarGuardiaNormal`) manda
**solo** `{"guardia_normal": activa}`. `actualizarDatos` (editar perfil)
deja de mandar `guardia_normal` (R21), igual que hace con `rol`: así editar
el nombre con un vecino viejo en memoria nunca pisa la preferencia.
`Vecino.copyWith` no recibe `guardiaNormal`, por la misma razón.

### 4. Turnos ya tomados: no se mueven (pregunta abierta P1, opción asumida)

Cambiar la opción vale para los turnos que el vecino tome **desde ahí**.
Los que ya tomó siguen en su lugar: si era guardia de ventana, sigue siendo
guardia de ventana en ese turno; si estaba en la patrulla, sigue en la
patrulla (R42). Si quiere cambiar un turno ya tomado, sale y se vuelve a
anotar. Razones: mover a un vecino de la guardia a una patrulla completa
no es posible sin sacar a otro; sacarlo de la guardia en silencio deja
turnos sin cubrir; y el `acceptance` habla de "al anotarse".

Consecuencia en la app: "Mis turnos" y el resumen del inicio describen cada
turno por el lugar que el vecino **ocupa** en él (`turno.guardiaVentana?.id
== usuario.id`), no por la preferencia actual (R25 a R27). Hoy usan
`esGuardiaVentana` del usuario: se cambia. El texto del interruptor lo
avisa: "Los turnos que ya tomaste no cambian." (R11, R12).

Lo que sí sigue la preferencia actual en la pestaña Turnos (porque habla de
anotarse de acá en adelante): el texto del botón "Anotarme" / "Anotarme
como guardia de ventana", el motivo de no disponible, `_ResumenCupo` y el
ícono propio del calendario.

### 5. Con la opción activada no se anota como guardia de ventana (pregunta abierta P2, opción asumida)

Un mayor con la guardia normal activada se anota solo en la patrulla. Si la
patrulla está completa, recibe "La patrulla de este turno ya está
completa." aunque el lugar de guardia esté libre (R23, R40). Para volver a
hacer guardia de ventana, apaga la opción. Así cada vecino tiene un solo
lugar posible por turno, la regla no necesita saber "en qué lugar quiere
anotarse" y la ruta de anotarse no cambia.

### 6. El interruptor del perfil

- Sección nueva "Turnos" (`_TituloSeccion`, encabezado) entre el chip y
  "Privacidad y avisos", **solo** si `puedeElegirGuardiaNormal` (R8, R9).
  Una `Card` con un `SwitchListTile`:
  - título: "Hacer guardia normal (patrulla)";
  - texto: "Guardando el cambio" mientras espera (R14); si no, "Te anotás
    en la patrulla, como el resto. Los turnos que ya tomaste no cambian."
    (prendido, R12) o "Hacés guardia de ventana desde tu casa. Los turnos
    que ya tomaste no cambian." (apagado, R11);
  - `value: viewModel.guardiaNormal` (R10, R15);
  - `onChanged: null` mientras `cambiandoGuardiaNormal` (R14).
- **El servidor primero.** A diferencia de "Compartir ubicación" (que se
  guarda en el teléfono y cambia al instante), esta opción la guarda el
  servidor: el interruptor no cambia hasta que confirma. Si falla, queda
  como estaba (R20) y se muestra un aviso con `mostrarAvisoEn` (R18, R19).
- Sin confirmación previa (pregunta abierta P3, opción asumida): el texto
  ya explica qué pasa y el cambio se deshace tocando otra vez.
- Al confirmar, el ViewModel publica `PerfilActualizado`: el perfil se
  redibuja (ya lo escucha; el chip pasa a "Turnos: patrullaje", R16), el
  inicio recarga (escucha todo, R27) y `TurnosViewModel` pasa a escucharlo
  para redibujarse (R22).

### 7. Servidor simulado

Las mismas reglas de `PUT /vecinos/<id>` en `actualizarVecino`, con los
mismos mensajes (constantes de `ReglasTurnos` de la app), y `registrar`
fuerza `guardia_normal: false`. `anotarse` no cambia de código: usa
`Vecino.fromJson` + `esGuardiaVentanaEn`, que ya siguen la preferencia. La
sesión del simulado sigue siendo Clara (45 años): en la app sin API la
opción no se ve; se prueba contra `ServidorSimulado` directo con Rosa (78).

### 8. MVVM estricto

`PerfilViewModel` y `TurnosViewModel` siguen importando solo
`package:flutter/foundation.dart` y archivos puros. Los textos nuevos que
arma un ViewModel (el mensaje de error de conexión) son `String` en el
propio ViewModel, como ya hace `TurnosViewModel._accion`; los textos del
interruptor son de la vista (`perfil_screen.dart`). Los mensajes de la
regla viven en `lib/domain/reglas_turnos.dart` (puro Dart).
`test/unit/arquitectura_test.dart` no cambia y tiene que seguir verde.

## Archivos a crear o cambiar

| Capa | Archivo | Cambio |
|---|---|---|
| domain | `lib/domain/reglas_turnos.dart` | `puedeElegirGuardiaNormal(int edad)`, `haceGuardiaVentana({edad, guardiaNormal})`, constantes `mensajeGuardiaNormalSoloMayores` y `mensajeGuardiaNormalInvalida`. `motivoNoDisponible` sin cambio de firma (usa `vecino.esGuardiaVentanaEn`). |
| domain | `lib/domain/models/vecino.dart` | Campo `guardiaNormal` (por defecto `false`), `fromJson` (`json['guardia_normal'] == true`), `toJson` (`'guardia_normal'`), `esGuardiaVentanaEn` usa `haceGuardiaVentana`, getter nuevo `puedeElegirGuardiaNormalEn(hoy)`. `copyWith` conserva el valor y no lo recibe. |
| domain | `lib/domain/models/turno.dart` | Sin cambios. Los vecinos del turno traen `guardia_normal` como cualquier otro dato del vecino; nadie lo usa desde el turno (ver alternativas). |
| data | `lib/data/repositories/sesion_repository.dart` | Método nuevo `cambiarGuardiaNormal({required bool activa})` en `SesionRepository` y en `SesionRepositoryRemoto` (manda `{'guardia_normal': activa}` con `_service.actualizar`, guarda el vecino devuelto en preferencias y en `_usuario`). `actualizarDatos` quita también `guardia_normal`. |
| data | `lib/data/services/vecinos_service.dart`, `http/vecinos_service_http.dart`, `simulados/vecinos_service_simulado.dart` | Sin cambios: se reutiliza `actualizar(id, datos)`. |
| data | `lib/data/services/simulados/servidor_simulado.dart` | `actualizarVecino`: valida `guardia_normal` (no booleano → `ErrorDelServidor(mensajeGuardiaNormalInvalida)`; `true` con menos de 70 → `ErrorDelServidor(mensajeGuardiaNormalSoloMayores)`) antes de tocar nada; si no viene, conserva el guardado. `registrar` fuerza `'guardia_normal': false`. `_vecinosDeEjemplo` con `'guardia_normal': false`. |
| data | `lib/data/services/local/preferencias.dart`, `turnos_dao.dart`, `base_de_datos.dart` | Sin cambios: el vecino de la sesión ya se guarda como JSON entero; la base no cambia de versión. |
| ui | `lib/ui/perfil/view_models/perfil_view_model.dart` | Guarda `_bus`. Getters `puedeElegirGuardiaNormal`, `guardiaNormal`, `cambiandoGuardiaNormal`; comando `cambiarGuardiaNormal(bool activa)`. `esGuardiaVentana` y `rol` no cambian de código (siguen a `esGuardiaVentanaEn`). |
| ui | `lib/ui/perfil/widgets/perfil_screen.dart` | Sección "Turnos" con el interruptor (clase de widget `_OpcionGuardiaNormal`), solo para mayores; `_PerfilScreenState._cambiarGuardiaNormal` muestra el aviso si el comando devuelve un mensaje. |
| ui | `lib/ui/turnos/view_models/turnos_view_model.dart` | Segunda suscripción a `PerfilActualizado` → `notifyListeners()`, cancelada en `dispose`. `detalleDe` decide por el lugar que el vecino ocupa en ese turno. |
| ui | `lib/ui/inicio/view_models/inicio_view_model.dart` | `_resumir`: con turnos, el título y las líneas salen del lugar que el vecino ocupa en el próximo turno; sin turnos, de `esGuardiaVentanaEn` (preferencia actual). `ResumenTurno.esGuardiaVentana` lleva lo mismo que el título. |
| ui | `lib/ui/turnos/widgets/turnos_screen.dart`, `lib/ui/inicio/widgets/inicio_screen.dart` | Sin cambios de código: ya leen `viewModel.esGuardiaVentana` / `resumen.esGuardiaVentana`. |
| armado | `lib/dependencias.dart`, `lib/ui/principal/widgets/principal_screen.dart` | Sin cambios: `PerfilViewModel` ya recibe `bus` y `sesion`. |
| backend | `backend/lib/src/reglas.dart` | `puedeElegirGuardiaNormal(nacimiento, hoy)`, `haceGuardiaVentana(nacimiento, hoy, {required bool guardiaNormal})`, mensajes nuevos con el mismo texto que la app; `motivoNoDisponible` recibe `required bool guardiaNormal` y usa `haceGuardiaVentana`. |
| backend | `backend/lib/src/almacen.dart` | `_leer`: `guardia_normal` que falta o no es `bool` → `false`. |
| backend | `backend/lib/src/datos_de_ejemplo.dart` | `'guardia_normal': false` en cada vecino de `vecinosDeEjemplo`. |
| backend | `backend/lib/src/api.dart` | `_registrar` guarda `'guardia_normal': false`; `_actualizarVecino` valida y copia `guardia_normal` (decisión 3); `_anotarse` lee `vecino['guardia_normal'] == true`, lo pasa a `motivoNoDisponible` y decide el lugar con `haceGuardiaVentana`. |
| backend | `backend/README.md` | Campo `guardia_normal` en la descripción del vecino; `PUT /vecinos/<id>` acepta `guardia_normal` (409 a menores con `true`, 400 si no es booleano); regla de turnos de los mayores con la opción; 409 de la tabla de errores con el ejemplo nuevo; nota en la cuenta de Rosa. |
| pruebas | `test/ayudas/falsos.dart` | `SesionFalsa.cambiarGuardiaNormal` con `ErrorDelServidor? errorAlCambiarGuardia`, `Object? falloAlCambiarGuardia` y `Completer<void>? demoraAlCambiarGuardia`; registra los valores pedidos en `cambiosDeGuardiaNormal`. |
| pruebas | `test/unit/dominio_test.dart`, `persistencia_test.dart`, `servicios_http_test.dart`, `repositorios_test.dart`, `view_models_test.dart`, `test/widget_test.dart`, `test/accesibilidad_test.dart` | Ver `tasks.md`. |
| pruebas | `backend/test/reglas_test.dart`, `backend/test/api_test.dart` | Ver `tasks.md`. Las llamadas existentes a `motivoNoDisponible` en `reglas_test.dart` suman `guardiaNormal: false`. |

## Firmas nuevas

```dart
// lib/domain/reglas_turnos.dart
class ReglasTurnos {
  // ... lo que ya está ...

  /// Desde [edadGuardiaVentana] el vecino puede elegir hacer guardia normal
  /// (patrulla) en lugar de guardia de ventana.
  static bool puedeElegirGuardiaNormal(int edad) => edad >= edadGuardiaVentana;

  /// Si al anotarse va a la guardia de ventana: mayor y sin guardia normal.
  static bool haceGuardiaVentana({
    required int edad,
    required bool guardiaNormal,
  }) => esGuardiaVentana(edad) && !guardiaNormal;

  static const mensajeGuardiaNormalSoloMayores =
      'Solo los vecinos de $edadGuardiaVentana años o más pueden elegir la '
      'guardia normal.';
  static const mensajeGuardiaNormalInvalida =
      'La opción de guardia normal no es válida.';
}
```

```dart
// lib/domain/models/vecino.dart
class Vecino {
  const Vecino({
    // ... los que ya están ...
    this.rol = RolVecino.vecino,
    this.guardiaNormal = false,
  });

  /// Un mayor de 70 que eligió hacer guardia normal (patrulla) en lugar de
  /// guardia de ventana. Lo guarda el servidor; para un menor no cambia
  /// nada.
  final bool guardiaNormal;

  // fromJson: guardiaNormal: json['guardia_normal'] == true
  // toJson:   'guardia_normal': guardiaNormal
  // copyWith: conserva guardiaNormal (no recibe parámetro)

  /// Si al anotarse va a la guardia de ventana.
  bool esGuardiaVentanaEn(DateTime hoy) => ReglasTurnos.haceGuardiaVentana(
    edad: edadEn(hoy),
    guardiaNormal: guardiaNormal,
  );

  /// Si ve la opción de guardia normal en el perfil.
  bool puedeElegirGuardiaNormalEn(DateTime hoy) =>
      ReglasTurnos.puedeElegirGuardiaNormal(edadEn(hoy));
}
```

```dart
// lib/data/repositories/sesion_repository.dart
abstract class SesionRepository {
  // ... lo que ya está ...

  /// Le pide al servidor que guarde la guardia normal del vecino de la
  /// sesión. Devuelve el vecino que confirmó el servidor y lo guarda con la
  /// sesión. Lanza [ErrorDelServidor] si el servidor lo rechaza.
  Future<Vecino> cambiarGuardiaNormal({required bool activa});
}

// SesionRepositoryRemoto:
@override
Future<Vecino> cambiarGuardiaNormal({required bool activa}) async {
  final vecino = Vecino.fromJson(
    await _service.actualizar(_usuario!.id, {'guardia_normal': activa}),
  );
  await _preferencias.guardarVecino(vecino);
  _usuario = vecino;
  return vecino;
}
// actualizarDatos: ..remove('id')..remove('rol')..remove('guardia_normal')
```

```dart
// lib/ui/perfil/view_models/perfil_view_model.dart
/// Si el vecino ve la opción de guardia normal (70 años o más).
bool get puedeElegirGuardiaNormal =>
    usuario?.puedeElegirGuardiaNormalEn(_reloj.ahora()) ?? false;

/// El valor que confirmó el servidor.
bool get guardiaNormal => usuario?.guardiaNormal ?? false;

/// True mientras se espera al servidor: el interruptor se desactiva.
bool get cambiandoGuardiaNormal => _cambiandoGuardiaNormal;

/// Pide el cambio al servidor. Devuelve null si salió bien o el mensaje
/// para el vecino si no. Si falla, todo queda como estaba.
Future<String?> cambiarGuardiaNormal(bool activa) async {
  // _cambiandoGuardiaNormal = true; notifyListeners();
  // try { await _sesion.cambiarGuardiaNormal(activa: activa);
  //       _bus.publicar(const PerfilActualizado()); return null; }
  // on ErrorDelServidor catch (e) { return e.mensaje; }
  // catch (_) { return 'No pudimos guardar el cambio. Revisá tu conexión '
  //                    'y probá de nuevo.'; }
  // finally { _cambiandoGuardiaNormal = false; notifyListeners(); }
}
```

```dart
// lib/ui/turnos/view_models/turnos_view_model.dart
// constructor: además de TurnosActualizados,
//   _suscripcionPerfil = _bus.de<PerfilActualizado>().listen((_) => notifyListeners());
// dispose: _suscripcionPerfil?.cancel();

/// Si el vecino es la guardia de ventana de [turno] (no la preferencia).
bool esGuardiaEn(Turno turno) => turno.guardiaVentana?.id == usuario?.id;
// detalleDe(turno) usa esGuardiaEn(turno) en lugar de esGuardiaVentana.
```

```dart
// backend/lib/src/reglas.dart
static bool puedeElegirGuardiaNormal(DateTime nacimiento, DateTime hoy) =>
    edad(nacimiento, hoy) >= edadGuardiaVentana;

static bool haceGuardiaVentana(
  DateTime nacimiento,
  DateTime hoy, {
  required bool guardiaNormal,
}) => esGuardiaVentana(nacimiento, hoy) && !guardiaNormal;

static const mensajeGuardiaNormalSoloMayores =
    'Solo los vecinos de $edadGuardiaVentana años o más pueden elegir la '
    'guardia normal.';
static const mensajeGuardiaNormalInvalida =
    'La opción de guardia normal no es válida.';

static String? motivoNoDisponible({
  required String vecinoId,
  required DateTime nacimiento,
  required bool guardiaNormal, // nuevo
  required List<String> patrulleros,
  required String? guardiaVentana,
  required int turnosEnElMes,
  required DateTime hoy,
});
```

## API y datos

- **Vecino (JSON)**: campo nuevo `guardia_normal` (booleano). Viaja en
  `{token, vecino}`, `GET /vecinos/yo` y `PUT /vecinos/<id>` (R28). Los
  vecinos dentro de un turno lo traen como cualquier otro dato del vecino
  (sin `rol`, como ya estaba).
- **`PUT /vecinos/<id>`**: acepta `guardia_normal` (decisión 3).
  Errores nuevos: 400 `{"error": "La opción de guardia normal no es
  válida."}` y 409 `{"error": "Solo los vecinos de 70 años o más pueden
  elegir la guardia normal."}`. Sin rutas nuevas.
- **`PUT /turnos/<fecha>/<franja>/vecinos/<id>`**: misma ruta y misma
  respuesta; cambia dónde queda un mayor con la opción activada
  (`patrulleros`) y qué 409 recibe.
- **`datos/barrio.json`**: cada vecino gana `guardia_normal`. Un archivo
  viejo se lee con `false` (R30). No hace falta migrar a mano.
- **sqflite**: sin cambios de esquema ni de versión. El vecino de la sesión
  vive en preferencias como JSON; los vecinos de cada turno, en columnas de
  texto JSON.

## Plataforma

No depende de la plataforma: no pregunta a `Capacidades` ni a `Politicas`.

## Accesibilidad

- `SwitchListTile` ocupa todo el ancho y más de 48 dp de alto; la fila
  entera es tocable (R47).
- El lector anuncia el título como etiqueta y el estado "prendido/apagado"
  del interruptor (`toggled`), sin `Semantics` extra (R48).
- El estado no se comunica solo con color: el texto del interruptor cambia
  con el valor (R11, R12) y con la espera ("Guardando el cambio", R14).
- "Turnos" usa `_TituloSeccion`, que ya marca `header: true` (R49).
- Al 200 % el título y el texto del `SwitchListTile` se parten en varias
  líneas; sin alturas fijas (R50).
- El aviso de error usa `mostrarAvisoEn`, igual que los otros interruptores
  del perfil.
- Prueba: el perfil de un mayor se arma con `PerfilScreen` +
  `SesionFalsa(vecinoMayor)` y `AppTheme.light` (el login del simulado
  entra siempre como Clara, de 45), y se le pasan `verificarGuias` y la
  prueba al 200 %.

## Paquetes nuevos

Ninguno.

## Preguntas abiertas (con la opción asumida)

- **P1 — ¿Qué pasa con los turnos ya tomados como guardia de ventana al
  activar la opción (y con los de patrulla al desactivarla)?** Asumido:
  **no se mueven**; la opción vale para los turnos que tome desde ahí. Para
  cambiar uno ya tomado, sale y se vuelve a anotar (decisión 4; R25 a R27,
  R42). Otra opción: pasarlo a la patrulla en los turnos futuros donde haya
  lugar y avisar en cuáles no; es más código y puede dejar turnos sin
  guardia sin que nadie lo note.
- **P2 — ¿Un mayor con la opción activada puede igual anotarse como guardia
  de ventana?** Asumido: **no**; se anota solo en la patrulla y para volver
  a la guardia apaga la opción (decisión 5; R23, R24, R40). Otra opción:
  dos botones por turno ("Anotarme en la patrulla" / "Anotarme como guardia
  de ventana"), que cambia la ruta de anotarse (habría que decir el lugar) y
  vuelve la opción del perfil casi innecesaria.
- **P3 — ¿Pedir confirmación antes de cambiar la opción?** Asumido: **no**;
  el texto del interruptor explica el efecto y se deshace tocando de nuevo.
  No agrega requisitos.
- **P4 — ¿Un vecino que cumple 70 con la opción ya prendida?** No puede
  pasar: un menor no puede activarla (R34). Si el equipo edita el archivo a
  mano y le pone `true` a un menor, no tiene efecto hasta los 70 (R7).

## Alternativas descartadas

**Guardar la preferencia solo en el teléfono (`Preferencias`), como
"Compartir ubicación".** Se descarta porque el servidor es quien decide el
lugar al anotarse y no puede confiar en la app (`docs/architecture.md`,
principio 6); además se perdería al cambiar de teléfono.

**Una ruta aparte (`PUT /vecinos/<id>/guardia-normal`).** Se descarta
porque `PUT /vecinos/<id>` ya es "mis datos", ya controla que sea el propio
vecino y ya devuelve el vecino entero que la app guarda con la sesión. Una
ruta nueva duplicaría ese control y el armado de la respuesta.

**Cambiarla con `actualizarDatos` (`copyWith(guardiaNormal: …)`).** Se
descarta porque `actualizarDatos` manda todos los datos: editar el nombre
con un vecino viejo en memoria podría pisar la preferencia, y la pantalla
de editar perfil podría cambiarla por error. Un método que manda solo
`guardia_normal` evita las dos cosas, como ya se hizo con `rol`.

**Mandar el lugar en el pedido de anotarse (`?lugar=patrulla`).** Se
descarta porque el `acceptance` pide la opción en el perfil, y dejaría la
regla del lado de la app. Es la variante de P2 si se decide distinto.

**Quitar `guardia_normal` de los vecinos de los turnos (como `rol`).** Se
descarta porque nadie lo lee desde un turno (el lugar ya viene en
`patrulleros` / `guardia_ventana`), los turnos ya traen datos del vecino del
mismo tipo (fecha de nacimiento) y el `acceptance` no lo pide; sería código
y pruebas de más.

**Mover los turnos ya tomados al cambiar la opción.** Ver P1.

## Pruebas existentes que cambian

- `backend/test/reglas_test.dart`: las llamadas a `motivoNoDisponible`
  agregan `guardiaNormal: false` (el parámetro es obligatorio a propósito,
  para que el servidor nunca se olvide de pasarlo). Mismos resultados.
- `test/ayudas/falsos.dart`: `SesionFalsa` implementa el método nuevo. Las
  pruebas que la usan no cambian.
- Las pruebas de `detalleDe` y del resumen del inicio con `vecinoMayor`
  como guardia siguen dando lo mismo (es guardia en ese turno).
- `un mayor de 70 queda como guardia de ventana` (backend) no cambia: Rosa
  tiene `guardia_normal: false` en los datos de ejemplo.

## Riesgos y notas

- **Otro teléfono con la sesión abierta.** `restaurar()` lee el vecino de
  preferencias y no consulta al servidor: si el vecino cambia la opción en
  otro teléfono, este sigue mostrando el valor viejo hasta que vuelva a
  ingresar (o hasta que la cambie acá, que devuelve el valor del
  servidor). El servidor igual anota con su propio dato, así que el turno
  queda bien; lo que puede no coincidir es el texto del botón. Mismo caso
  que el rol en la feature 13.
- `TurnosViewModel.motivoNoDisponible` sale de la sesión del teléfono: si
  está desactualizada (punto anterior), el servidor puede responder un 409
  que la app no anticipó; ya se muestra el mensaje del servidor tal cual.
- En la app sin API la opción no se ve (la sesión simulada es Clara, de
  45). Para probarla a mano hay que usar la API con la cuenta de Rosa.
- La regla vuelve a estar copiada en dos lados (app y backend): las
  pruebas de los dos lados cubren R5 a R7 con los mismos casos.
- La feature 21 (`aviso_turno_incompleto`) cuenta personas anotadas en un
  turno; un mayor con guardia normal en la patrulla cuenta como un
  patrullero más. No hay conflicto, pero su spec debería tenerlo en cuenta.
