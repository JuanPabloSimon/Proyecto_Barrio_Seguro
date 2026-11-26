# Barrio Seguro: API

API REST de Barrio Seguro, escrita en Dart con [shelf](https://pub.dev/packages/shelf) y [shelf_router](https://pub.dev/packages/shelf_router). Vive en el mismo repositorio que la app, pero es un proyecto de Dart aparte: no usa Flutter.

## Ponerla en marcha

Desde esta carpeta (`backend/`):

```bash
dart pub get
dart run bin/servidor.dart
```

La API queda escuchando en `http://localhost:8080`. Para comprobarlo, abrí `http://localhost:8080/salud` en el navegador: tiene que responder `{"estado":"ok","ahora":...}` (`ahora` es la hora del servidor en milisegundos).

La primera vez crea `datos/barrio.json` con los mismos vecinos, turnos y alertas de ejemplo que muestra la app. Esa carpeta no se sube al repositorio. Para volver a los datos de ejemplo, borrá el archivo y reiniciá el servidor.

Variables de entorno (opcionales):

| Variable | Para qué | Por defecto |
|---|---|---|
| `PORT` | Puerto | `8080` |
| `DATOS` | Archivo donde se guardan los datos | `datos/barrio.json` |
| `CODIGO_COMISION` | Código que la comisión vecinal da para registrarse | `SOBERANIA` |
| `FIREBASE_CREDENTIALS` | Archivo JSON de la cuenta de servicio de Firebase para avisos push | _(sin push)_ |

### Conectar la app

Con el servidor andando, desde la carpeta de la app (la raíz del repositorio):

```bash
# Emulador de Android: 10.0.2.2 es la PC vista desde el emulador.
flutter run --dart-define=API_URL=http://10.0.2.2:8080

# Celular en la misma red wifi: la IP de la PC (en Windows, `ipconfig`).
flutter run --dart-define=API_URL=http://192.168.0.10:8080
```

Sin `--dart-define`, la app usa el servidor simulado y no necesita la API. En Windows, la primera vez el firewall puede pedir permiso para que Dart acepte conexiones: hay que permitirlo en redes privadas.

### Cuentas de prueba

| Vecino | Teléfono | Contraseña | Turnos | Rol en la app |
|---|---|---|---|---|
| Clara Medina, 45 años | 261 555-0142 | barrio1234 | patrullaje | `comision` (miembro de la comisión) |
| Rosa Ibáñez, 78 años | 261 555-0177 | barrio1234 | guardia de ventana (arranca con `guardia_normal: false`; puede activarla desde el perfil) | `vecino` (vecina común) |

### Asignar el rol de la comisión

Cada vecino tiene un rol: `vecino` (vecino común) o `comision` (miembro de la comisión vecinal). Quien se registra queda siempre como `vecino`, y ninguna ruta de la API cambia un rol: ni los vecinos ni la comisión pueden asignarlo desde la app.

El rol `comision` lo asigna **el equipo de desarrollo**, editando los datos del servidor:

1. Apagá el servidor (si queda andando, el próximo cambio pisa lo que edites).
2. Abrí `datos/barrio.json` (o el archivo de `DATOS`) y, en el vecino que corresponda dentro de `vecinos`, poné `"rol": "comision"`. Para quitárselo, `"rol": "vecino"`.
3. Volvé a arrancar el servidor.
4. El vecino tiene que cerrar sesión e ingresar de nuevo para que la app vea el rol nuevo.

Un vecino sin `rol` o con un valor desconocido se lee como `vecino`.

## Pruebas

```bash
dart test
```

Las pruebas le pasan pedidos al handler directamente, sin abrir un puerto.

## Rutas

Todo va y viene en JSON, con los mismos nombres de campo que usa la app (`fecha_nacimiento`, `creada_en`, etc.). Salvo `/salud`, `POST /sesiones` y `POST /vecinos`, todas las rutas piden el encabezado `Authorization: Bearer <token>`.

Cada alerta (en `GET /alertas`, `POST /alertas` y `PATCH /alertas/<id>`) trae `reportada_por_nombre`: el primer nombre de quien la reportó (`""` si el vecino ya no existe). No se guarda en `datos/barrio.json`: se calcula al responder. El aviso push de una alerta nueva lleva en sus datos las mismas claves de la alerta, incluido `reportada_por_nombre`; ningún otro dato de quien la reportó.

Cuando `PATCH /alertas/<id>` pasa una alerta de `resuelta` a `activa` o `en_atencion`, el servidor manda otro aviso push al tópico `alertas`: las mismas claves de la alerta (con el estado nuevo) más `aviso: "reabierta"` y `reabierta_en` (la hora del servidor de la reapertura, en milisegundos). No lleva quién la reabrió. Ningún otro cambio de estado manda aviso, y si FCM falla el estado nuevo queda guardado igual.

El vecino (en `{token, vecino}`, `GET /vecinos/yo` y `PUT /vecinos/<id>`) trae el campo `rol`: `"vecino"` o `"comision"`. Los vecinos que aparecen dentro de un turno (`patrulleros` y `guardia_ventana`) **no** traen `rol`.

El vecino también trae `guardia_normal` (booleano, `false` por defecto): si un vecino de 70 años o más eligió hacer guardia normal (patrulla) en lugar de guardia de ventana. Quien se registra arranca con `false`, mande lo que mande, y un archivo de datos viejo sin el campo (o con un valor que no es booleano) se lee con `false`.

| Método y ruta | Qué hace | Respuesta |
|---|---|---|
| `GET /salud` | Comprueba que la API está andando. `ahora` es la hora del servidor en milisegundos: la app la usa para medir el desfase de su reloj (avisos tardíos) | `{"estado": "ok", "ahora": 1759330800000}` |
| `POST /sesiones` | Ingresar con `{usuario, clave}` (usuario = teléfono) | `{token, vecino}` |
| `DELETE /sesiones` | Cerrar la sesión (el token deja de servir) | 204 |
| `POST /vecinos` | Registrarse: `{nombre, fecha_nacimiento, telefono, calle, cuadra, codigo_comision, clave}` | 201 `{token, vecino}` |
| `GET /vecinos/yo` | Los datos del vecino de la sesión | vecino |
| `PUT /vecinos/<id>` | Cambiar nombre, teléfono, calle, cuadra o `guardia_normal` (solo los propios). Si trae un `rol` distinto del actual, 403. Si `guardia_normal` no es booleano, 400 "La opción de guardia normal no es válida."; si es `true` y el vecino tiene menos de 70, 409 "Solo los vecinos de 70 años o más pueden elegir la guardia normal.". En los dos casos no se cambia ningún dato. Si no trae `guardia_normal`, queda la que estaba | vecino |
| `GET /alertas` | Todas, de la más nueva a la más vieja | lista de alertas |
| `POST /alertas` | Crear: `{categoria, tipo, descripcion, direccion, latitud, longitud}`. `categoria`: `sos`, `actividad_sospechosa`, `vehiculo`, `robo` o `ruidos` (`arrebato` ya no se crea: 400 "Elegí qué tipo de alerta es."; las viejas se siguen leyendo). `tipo` (el título) es obligatorio, hasta 60 letras; `descripcion` hasta 500 y `direccion` hasta 120, las dos opcionales. Las letras se cuentan sin los espacios de los extremos. Mismas reglas y mensajes que la app | 201 alerta |
| `PATCH /alertas/<id>` | Cambiar el estado: `{estado}` (quien la reportó o la comisión). Si reabre una alerta resuelta (a `activa` o `en_atencion`), manda un aviso push | alerta |
| `GET /turnos?anio=2026&mes=10` | Turnos del mes, con los vecinos adentro (sin `rol`) | lista de turnos |
| `PUT /turnos/<fecha>/<franja>/vecinos/<id>` | Anotarse (solo uno mismo). Un vecino de 70 o más va a `guardia_ventana`; con `guardia_normal` en `true` va a `patrulleros`, con las mismas reglas que el resto (cupo de 2 y máximo de 2 turnos por mes). Cambiar `guardia_normal` no mueve los turnos ya tomados | turno |
| `DELETE /turnos/<fecha>/<franja>/vecinos/<id>` | Salir del turno | turno |
| `/comision/…` (cualquier método) | Rutas solo para los miembros de la comisión. Todavía no hay ninguna: responden 404 a la comisión, 403 a un vecino común y 401 sin sesión | según la ruta |

Si algo sale mal, la respuesta trae `{"error": "..."}` con un mensaje para mostrarle al vecino tal cual:

| Código | Cuándo |
|---|---|
| 400 | Faltan datos o no son válidos |
| 401 | No hay sesión o el token venció |
| 403 | No está permitido (por ejemplo, cambiar el estado de una alerta ajena sin ser de la comisión, cambiarse el rol o entrar a una ruta de la comisión sin ser de la comisión) |
| 404 | No existe |
| 409 | Choca con una regla (por ejemplo, el máximo de 2 turnos por mes, o un menor de 70 que pide la guardia normal) |

## Cómo está hecha

- `bin/servidor.dart`: arranca el servidor y lee las variables de entorno.
- `lib/src/api.dart`: las rutas, las validaciones y los permisos.
- `lib/src/reglas.dart`: las reglas de los turnos. Son las mismas que aplica la app, con los mismos mensajes. El servidor las vuelve a aplicar porque no puede confiar solo en la app.
- `lib/src/almacen.dart`: los datos en memoria, guardados en un archivo JSON después de cada cambio. Las contraseñas se guardan con hash SHA-256 y sal, nunca en texto plano.
- `lib/src/datos_de_ejemplo.dart`: los datos con los que arranca la primera vez.

Para un prototipo alcanza con un archivo JSON. Si hace falta una base de datos, se reemplaza `Almacen` y las rutas no cambian.
