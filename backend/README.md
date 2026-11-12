# Barrio Seguro: API

API REST de Barrio Seguro, escrita en Dart con [shelf](https://pub.dev/packages/shelf) y [shelf_router](https://pub.dev/packages/shelf_router). Vive en el mismo repositorio que la app, pero es un proyecto de Dart aparte: no usa Flutter.

## Ponerla en marcha

Desde esta carpeta (`backend/`):

```bash
dart pub get
dart run bin/servidor.dart
```

La API queda escuchando en `http://localhost:8080`. Para comprobarlo, abrí `http://localhost:8080/salud` en el navegador: tiene que responder `{"estado":"ok"}`.

La primera vez crea `datos/barrio.json` con los mismos vecinos, turnos y alertas de ejemplo que muestra la app. Esa carpeta no se sube al repositorio. Para volver a los datos de ejemplo, borrá el archivo y reiniciá el servidor.

Variables de entorno (opcionales):

| Variable | Para qué | Por defecto |
|---|---|---|
| `PORT` | Puerto | `8080` |
| `DATOS` | Archivo donde se guardan los datos | `datos/barrio.json` |
| `CODIGO_COMISION` | Código que la comisión vecinal da para registrarse | `SOBERANIA` |

### Cuentas de prueba

| Vecino | Teléfono | Contraseña | Rol |
|---|---|---|---|
| Clara Medina, 45 años | 261 555-0142 | barrio1234 | patrullaje |
| Rosa Ibáñez, 78 años | 261 555-0177 | barrio1234 | guardia de ventana |

## Pruebas

```bash
dart test
```

Las pruebas le pasan pedidos al handler directamente, sin abrir un puerto.

## Rutas

Todo va y viene en JSON, con los mismos nombres de campo que usa la app (`fecha_nacimiento`, `creada_en`, etc.). Salvo `/salud`, `POST /sesiones` y `POST /vecinos`, todas las rutas piden el encabezado `Authorization: Bearer <token>`.

| Método y ruta | Qué hace | Respuesta |
|---|---|---|
| `GET /salud` | Comprueba que la API está andando | `{"estado": "ok"}` |
| `POST /sesiones` | Ingresar con `{usuario, clave}` (usuario = teléfono) | `{token, vecino}` |
| `DELETE /sesiones` | Cerrar la sesión (el token deja de servir) | 204 |
| `POST /vecinos` | Registrarse: `{nombre, fecha_nacimiento, telefono, calle, cuadra, codigo_comision, clave}` | 201 `{token, vecino}` |
| `GET /vecinos/yo` | Los datos del vecino de la sesión | vecino |
| `PUT /vecinos/<id>` | Cambiar nombre, teléfono, calle o cuadra (solo los propios) | vecino |
| `GET /alertas` | Todas, de la más nueva a la más vieja | lista de alertas |
| `POST /alertas` | Crear: `{categoria, tipo, descripcion, direccion, latitud, longitud}` | 201 alerta |
| `PATCH /alertas/<id>` | Cambiar el estado: `{estado}` (solo quien la reportó) | alerta |
| `GET /turnos?anio=2026&mes=10` | Turnos del mes, con los vecinos adentro | lista de turnos |
| `PUT /turnos/<fecha>/<franja>/vecinos/<id>` | Anotarse (solo uno mismo) | turno |
| `DELETE /turnos/<fecha>/<franja>/vecinos/<id>` | Salir del turno | turno |

Si algo sale mal, la respuesta trae `{"error": "..."}` con un mensaje para mostrarle al vecino tal cual:

| Código | Cuándo |
|---|---|
| 400 | Faltan datos o no son válidos |
| 401 | No hay sesión o el token venció |
| 403 | No está permitido (por ejemplo, cerrar la alerta de otro vecino) |
| 404 | No existe |
| 409 | Choca con una regla (por ejemplo, el máximo de 2 turnos por mes) |

## Cómo está hecha

- `bin/servidor.dart`: arranca el servidor y lee las variables de entorno.
- `lib/src/api.dart`: las rutas, las validaciones y los permisos.
- `lib/src/reglas.dart`: las reglas de los turnos. Son las mismas que aplica la app, con los mismos mensajes. El servidor las vuelve a aplicar porque no puede confiar solo en la app.
- `lib/src/almacen.dart`: los datos en memoria, guardados en un archivo JSON después de cada cambio. Las contraseñas se guardan con hash SHA-256 y sal, nunca en texto plano.
- `lib/src/datos_de_ejemplo.dart`: los datos con los que arranca la primera vez.

Para un prototipo alcanza con un archivo JSON. Si hace falta una base de datos, se reemplaza `Almacen` y las rutas no cambian.
