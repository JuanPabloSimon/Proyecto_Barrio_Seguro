# Design — rol_comision

> Decisiones técnicas tomadas antes de escribir código. Se apoya en
> `docs/architecture.md` y `docs/conventions.md`; acá solo va lo que esta
> feature agrega o donde roza sus límites.

## Resumen

- El vecino gana un campo `rol` (`vecino` | `comision`) que viaja en el JSON
  de la API con el nombre `rol`.
- **Nadie cambia un rol desde la API.** Registrarse siempre da `vecino`;
  `PUT /vecinos/<id>` responde 403 si el pedido trae un `rol` distinto del
  actual. El rol `comision` lo designa **el equipo de desarrollo**, editando
  los datos del servidor: en los datos de ejemplo (Clara Medina) o en el
  archivo de datos con el servidor apagado (procedimiento en
  `backend/README.md`). Ni los vecinos ni la comisión asignan roles.
- **El rol no viaja en los turnos.** Los vecinos dentro de un turno
  (`patrulleros` y `guardia_ventana`) se mandan sin `rol`, en la API real y
  en el servidor simulado, y la copia de turnos en sqflite tampoco lo guarda
  (R21–R23). El rol solo aparece con los datos del propio vecino y su sesión.
- **Valor por defecto `vecino`** en todos los lugares donde puede faltar el
  campo: JSON de la app (incluida la sesión vieja guardada en preferencias) y
  archivo de datos viejo del servidor.
- **Mecanismo para la feature 14:** un sub-router montado en `/comision/`
  detrás de un middleware `soloComision` (401 sin sesión, 403 si el rol es
  `vecino`). Hoy está vacío: cualquier pedido de la comisión a `/comision/…`
  responde 404 "Esa dirección no existe." y el de un vecino común, 403. Así
  se prueba el 403 sin inventar una ruta. La feature 14 solo agrega su ruta
  dentro de `_rutasDeLaComision` (por ejemplo `GET /comision/informes/alertas`)
  y en la app pregunta `sesion.usuario?.esComision` para mostrar la opción.

## Archivos a crear o cambiar

| Capa | Archivo | Cambio |
|---|---|---|
| domain | `lib/domain/models/vecino.dart` | Enum `RolVecino`, campo `rol` (por defecto `RolVecino.vecino`), getter `esComision`, `fromJson`/`toJson` con `rol`. `copyWith` **no** permite cambiar el rol. |
| domain | `lib/domain/models/turno.dart` | `toMap` guarda cada vecino del turno (patrulleros y guardia) con `toJson()` sin la clave `rol` (R23). `fromJson`/`fromMap` sin cambios. |
| data | `lib/data/repositories/sesion_repository.dart` | `actualizarDatos` quita `rol` del cuerpo además de `id`. Sin otros cambios: `_abrirSesion` y `restaurar` ya guardan/leen el vecino entero con `toJson`/`fromJson`, así que el rol viaja solo. |
| data | `lib/data/services/simulados/servidor_simulado.dart` | `registrar` fuerza `'rol': 'vecino'`; `actualizarVecino` lanza `ErrorDelServidor` si `datos['rol']` existe y es distinto del actual; datos de ejemplo con `rol` (Clara `comision`, el resto `vecino`); `_turnoCompleto` arma cada vecino con `Map.of(_vecinos[id]!)..remove('rol')` (R22). |
| data | `lib/data/repositories/turnos_repository.dart`, `lib/data/services/local/turnos_dao.dart` | Sin cambios: el DAO guarda con `Turno.toMap`, que ya deja afuera el `rol`. |
| data | `lib/data/services/local/preferencias.dart` | Sin cambios de código (el valor por defecto vive en `Vecino.fromJson`). Solo se prueba. |
| data | `lib/data/services/http/*` | Sin cambios: `ClienteApi` ya convierte el 403 en `ErrorDelServidor` con el mensaje del servidor. |
| ui | — | Sin cambios. Ninguna pantalla muestra el rol en esta feature. |
| armado | `lib/dependencias.dart` | Sin cambios. |
| backend | `backend/lib/src/almacen.dart` | Clase `Roles` con las constantes; `_leer` normaliza el rol de cada vecino (falta o desconocido → `vecino`). |
| backend | `backend/lib/src/datos_de_ejemplo.dart` | Campo `rol` en cada vecino de ejemplo: `clara` → `comision`, el resto → `vecino`. Actualizar el comentario de cuentas de prueba. |
| backend | `backend/lib/src/api.dart` | `_registrar` guarda `'rol': Roles.vecino`; `_actualizarVecino` responde 403 si piden otro rol y nunca copia `rol` del cuerpo; middleware público `soloComision`; sub-router `_rutasDeLaComision` montado en `/comision/` antes del comodín final; `_turnoCompleto` usa la ayuda nueva `_vecinoDelTurno(id)`, que devuelve una copia del vecino sin `rol` (R21). |
| backend | `backend/README.md` | Columna "Rol" de las cuentas de prueba renombrada a "Turnos" y nueva columna "Rol en la app"; fila de rutas `/comision/…`; sección "Asignar el rol de la comisión" (lo hace el equipo de desarrollo); 403 para rutas de la comisión en la tabla de errores; nota en la descripción de los turnos: sus vecinos no traen `rol`. |
| pruebas | `test/unit/dominio_test.dart`, `test/unit/persistencia_test.dart`, `test/unit/servicios_http_test.dart`, `test/unit/repositorios_test.dart` | Ver `tasks.md`. |
| pruebas | `backend/test/api_test.dart` | Grupos nuevos `Rol` y `Rutas de la comisión`; prueba nueva en el grupo `Turnos`. |

## Firmas nuevas

```dart
// lib/domain/models/vecino.dart
enum RolVecino {
  vecino,
  comision;

  /// El rol que viene en el JSON. Si falta o no se conoce, `vecino`: ante la
  /// duda, el vecino tiene menos permisos, no más.
  static RolVecino desdeJson(Object? valor) =>
      valor == 'comision' ? RolVecino.comision : RolVecino.vecino;

  String get json => name; // 'vecino' | 'comision'
}

class Vecino {
  const Vecino({
    required this.id,
    required this.nombre,
    required this.fechaNacimiento,
    this.telefono = '',
    this.calle = '',
    this.cuadra = '',
    this.vecinoDesde,
    this.rol = RolVecino.vecino,
  });

  final RolVecino rol;

  /// Si es miembro de la comisión vecinal (ve las opciones de la comisión).
  bool get esComision => rol == RolVecino.comision;
  // fromJson: rol: RolVecino.desdeJson(json['rol'])
  // toJson:   'rol': rol.json
  // copyWith: conserva rol (no recibe parámetro rol)
}
```

```dart
// backend/lib/src/almacen.dart
abstract final class Roles {
  static const vecino = 'vecino';
  static const comision = 'comision';
  static const todos = {vecino, comision};
}
```

```dart
// backend/lib/src/api.dart
static const mensajeRolFijo = 'El rol no se puede cambiar desde la app.';
static const mensajeSoloComision =
    'Esta opción es solo para la comisión vecinal.';

/// Deja pasar el pedido solo si el vecino de la sesión es de la comisión.
/// Sin sesión válida lanza 401; con rol `vecino`, 403. Los errores los
/// convierte en JSON `_manejarErrores`, que envuelve todo el handler.
Middleware get soloComision => (interno) => (pedido) {
  final id = _vecinoDe(pedido);
  if (_almacen.vecinos[id]!['rol'] != Roles.comision) {
    throw const ErrorDeApi.noPermitido(mensajeSoloComision);
  }
  return interno(pedido);
};

/// Rutas solo para la comisión, relativas a `/comision/`. La feature
/// informe_alertas agrega acá su ruta.
Router get _rutasDeLaComision => Router()
  ..all('/<_|.*>', (Request _) {
    throw const ErrorDeApi.noExiste('Esa dirección no existe.');
  });

// En _rutas, antes del comodín `..all('/<_|.*>', …)`:
//   ..mount(
//     '/comision/',
//     const Pipeline()
//         .addMiddleware(soloComision)
//         .addHandler(_rutasDeLaComision.call),
//   )

/// Los datos de un vecino como aparecen dentro de un turno: una copia, sin
/// `rol`. Copia para no borrar el rol del vecino guardado en `Almacen`.
Map<String, dynamic> _vecinoDelTurno(String id) =>
    Map<String, dynamic>.of(_almacen.vecinos[id]!)..remove('rol');

// _turnoCompleto: 'patrulleros': [for (final id in …) _vecinoDelTurno(id)],
//                 'guardia_ventana': guardia == null ? null : _vecinoDelTurno(guardia)
```

```dart
// lib/domain/models/turno.dart
/// Objeto -> fila de la tabla `turnos`. Los vecinos van sin `rol`: en un
/// turno no hace falta saber quién es de la comisión.
Map<String, Object?> toMap() {
  // 'patrulleros': jsonEncode([for (final p in patrulleros) _sinRol(p)]),
  // 'guardia_ventana': guardia == null ? null : jsonEncode(_sinRol(guardia)),
}

static Map<String, dynamic> _sinRol(Vecino v) => v.toJson()..remove('rol');
```

```dart
// lib/data/services/simulados/servidor_simulado.dart
Map<String, dynamic> _vecinoDelTurno(String id) =>
    Map<String, dynamic>.of(_vecinos[id]!)..remove('rol');
// _turnoCompleto usa _vecinoDelTurno en vez de Map.of(_vecinos[id]!).
```

`anotarse` y `_cantidadEnElMes` del servidor simulado arman un `Turno` con
`Turno.fromJson(_turnoCompleto(…))`; sin `rol`, esos vecinos quedan como
`vecino`, y no pasa nada porque `ReglasTurnos` no mira el rol. El vecino que
se anota sale de `Vecino.fromJson(_vecinos[vecinoId])`, con su rol real.

`Router.mount('/comision/', …)` de shelf_router 1.1.5 (la versión del
`pubspec.lock`) registra `'/comision/<path|[^]*>'` para todos los métodos, así
que el middleware corre antes de buscar la ruta interna: un vecino común
recibe 403 aunque la ruta no exista, y no puede averiguar qué rutas hay.

## API y datos

- **JSON del vecino** (app y API): campo nuevo `"rol": "vecino" | "comision"`.
  Aparece en `POST /sesiones`, `POST /vecinos`, `GET /vecinos/yo` y
  `PUT /vecinos/<id>`.
- **JSON de los turnos** (`GET /turnos`, `PUT` y `DELETE
  /turnos/<fecha>/<franja>/vecinos/<id>`): los vecinos de `patrulleros` y
  `guardia_ventana` **no** traen `rol` (R21). Hoy `_turnoCompleto` mete el
  mapa entero del vecino guardado en `Almacen`, que desde esta feature tiene
  `rol`; pasa a usar `_vecinoDelTurno(id)`, una copia sin esa clave. Es una
  copia y no un `remove` sobre el mapa guardado, para no borrarle el rol al
  vecino en `Almacen` (la prueba lo verifica con `GET /vecinos/yo` después
  de `GET /turnos`). Lo mismo en el servidor simulado (R22). La app no
  cambia al leer: `Turno.fromJson` ya arma cada vecino con
  `Vecino.fromJson`, que sin `rol` da `vecino`; ninguna pantalla de turnos
  mira el rol.
- **`POST /vecinos`**: ignora cualquier `rol` del cuerpo; la cuenta nace con
  `"rol": "vecino"`. No responde 403 porque el registro no "cambia" un rol
  existente y la app nunca manda ese campo; así no se rompe un cliente viejo.
- **`PUT /vecinos/<id>`**: si `datos.containsKey('rol')` y
  `datos['rol'] != vecino actual['rol']` → 403 `mensajeRolFijo`, antes de
  validar o tocar cualquier otro campo. Si el `rol` es igual al actual, se
  ignora. El `rol` nunca se copia del cuerpo (la lista de campos editables
  sigue siendo `nombre`, `telefono`, `calle`, `cuadra`). La regla es la misma
  para los dos roles: en esta feature no existe ninguna vía de la API para
  cambiar un rol; la del requisito es la del vecino común (R13) y la prueba
  con un miembro de la comisión cubre R14.
- **Rutas nuevas**: `ALL /comision/<cualquier cosa>` → 401 sin sesión, 403 a
  un vecino común, 404 a un miembro de la comisión (hasta que la feature 14
  agregue su ruta).
- **Archivo de datos del servidor (`datos/barrio.json`)**: sin cambio de
  formato. `Almacen._leer` normaliza: para cada vecino, si `rol` falta o no
  está en `Roles.todos`, queda `Roles.vecino`. El archivo se reescribe con el
  rol en el próximo `guardar()`.
- **Copia local de la app**: la sesión vive en preferencias (`claveVecino`,
  JSON de `Vecino.toJson`). Sin clave nueva ni migración explícita: una
  sesión guardada antes de esta feature no tiene `rol` y `Vecino.fromJson` la
  lee como `vecino`.
- **sqflite (tabla `turnos`)**: sin cambio de esquema ni de versión. Los
  vecinos de cada turno se guardan como texto JSON en las columnas
  `patrulleros` y `guardia_ventana`, armado por `Turno.toMap` con
  `Vecino.toJson`. Como `toJson` ahora incluye `rol` (R4), sin cambios cada
  vecino de un turno quedaría guardado con `"rol": "vecino"` (el valor por
  defecto con que se leyó), que además sería falso para Clara. `Turno.toMap`
  le quita `rol` a cada vecino antes de codificarlo (R23); `Turno.fromMap`
  lo lee como `vecino` por defecto. Las filas guardadas antes de esta
  feature no tienen `rol` y siguen igual: no hace falta migración.

### Cómo se asigna el rol `comision`

1. **Datos de ejemplo**: Clara Medina (`261 555-0142`) arranca como
   `comision` en el servidor real (cuando se crea `datos/barrio.json`) y en
   el servidor simulado (que siempre ingresa como Clara). Rosa Ibáñez queda
   como cuenta de prueba de vecino común.
2. **Datos reales**: los miembros de la comisión los designa **el equipo de
   desarrollo**, editando los datos del servidor: apaga el servidor, edita
   `datos/barrio.json` poniendo `"rol": "comision"` en el vecino que
   corresponda (o `"vecino"` para quitárselo) y lo vuelve a arrancar. Queda
   documentado en `backend/README.md`, en la sección "Asignar el rol de la
   comisión", como tarea del equipo de desarrollo. El vecino tiene que cerrar
   sesión e ingresar de nuevo para que la app vea el rol nuevo (ver Riesgos).
3. **Ninguna ruta de la API asigna roles.** Ni un vecino ni la comisión
   pueden asignarlos desde la app: el registro ignora el `rol` (R10) y el
   `PUT` rechaza cambiarlo (R13).

## Plataforma

No depende de la plataforma.

## Accesibilidad

No tiene pantalla. La feature 14 es la que agrega la opción visible para la
comisión.

## Paquetes nuevos

Ninguno. `Middleware`, `Pipeline` y `Router.mount` ya vienen en `shelf` y
`shelf_router`, que el backend ya usa.

## Alternativas descartadas

**Un segundo código de registro para la comisión** (por ejemplo,
`CODIGO_COMISION_MIEMBROS`). Se descarta porque el código de registro se
reparte de boca en boca y cualquiera que lo escuche se daría el rol; además
el `acceptance` no lo pide.

**Una ruta `PUT /comision/vecinos/<id>/rol` para que la comisión asigne
roles.** Se descarta porque el `acceptance` no la pide y el equipo definió
que los roles los designa el equipo de desarrollo, no la comisión. Si algún
día cambia, queda como feature aparte; el sub-router `/comision/` ya la
dejaría protegida.

**Un parámetro `incluirRol` en `Vecino.toJson`** para no mandar ni guardar
el rol en los turnos. Se descarta porque obliga a cada llamador a acordarse
del parámetro y mezcla en el modelo una decisión de cómo se arma el turno.
Quitar la clave en los dos lugares que arman turnos (`_turnoCompleto` del
servidor y del simulado) y en `Turno.toMap` deja la regla junto al turno.

**Una clase aparte para el vecino de un turno** (sin `rol`). Se descarta
porque duplicaría `Vecino` (nombre, edad, guardia de ventana) que las reglas
de turnos y las pantallas ya usan; alcanza con no mandar el campo.

**Una ruta de prueba (`GET /comision/ping`) para probar el 403.** Se
descarta porque sería código de producción solo para las pruebas. El montaje
del prefijo con su middleware ya se prueba con cualquier ruta bajo
`/comision/` (403 al vecino común, 404 a la comisión) y el middleware
público `soloComision` se prueba además envolviendo un handler falso.

**Chequear el rol dentro de cada handler** (como `_soloElMismoVecino`). Se
descarta porque cada ruta nueva de la comisión dependería de que alguien se
acuerde de llamarlo; con el prefijo montado, ninguna ruta bajo `/comision/`
puede quedar abierta por olvido.

## Riesgos y notas

- **Sesión vieja de un miembro de la comisión.** `restaurar()` lee el vecino
  de preferencias y no consulta al servidor, así que quien ya tenía sesión
  abierta antes de que el equipo de desarrollo le asignara el rol sigue
  viéndose como `vecino` hasta
  que cierre sesión e ingrese de nuevo. Es seguro (tiene menos permisos, no
  más; el servidor igual decide con su propio dato) y alcanza para el
  `acceptance`. Si la feature 14 necesita que se vea al instante, puede
  refrescar con `GET /vecinos/yo` al abrir la app; queda anotado para su spec.
- El servidor no confía en el rol que guarda la app: `soloComision` lee el rol
  de `Almacen`, nunca del pedido.
- Los `Vecino` que la app arma desde un turno tienen siempre rol `vecino`
  (el campo no viene). La feature 14 no debe usar `turno.patrulleros[i]
  .esComision` para nada: el rol confiable es el de `sesion.usuario`.
- Asignar o quitar el rol es tarea del equipo de desarrollo y exige apagar
  el servidor un momento; si en algún momento se vuelve frecuente, se evalúa
  una feature aparte.
- `copyWith` no recibe `rol` a propósito: la pantalla de editar perfil no
  puede cambiarlo ni por error.
- `test/ayudas/falsos.dart`: `vecinaDePrueba` sigue con el rol por defecto
  (`vecino`); las pruebas de la comisión construyen su propio `Vecino` con
  `rol: RolVecino.comision` para no cambiar el comportamiento de las pruebas
  existentes.
- La prueba existente `ingresar devuelve el token y los datos del vecino`
  del backend no cambia; Clara ahora trae `"rol": "comision"` además.
- Las pruebas existentes de turnos (`devuelve los turnos del mes con los
  vecinos adentro`, `TurnosDao`, `Turnos contra el servidor simulado`) no
  cambian: miran nombres e ids, no el rol.
