# Arquitectura — Qué significa "hacer un buen trabajo" en Barrio Seguro

> Este es el estándar de calidad. El `reviewer` evalúa contra este archivo.
> Si no está acá ni en `docs/conventions.md`, no es un requisito.

## Las piezas

```
lib/
├── main.dart              arranca la app y arma Dependencias
├── dependencias.dart      ÚNICO lugar donde se crean y conectan las piezas
├── configuracion.dart     constantes de compilación (API_URL)
├── domain/                modelos y reglas puras, sin Flutter
│   ├── models/            Alerta, Vecino, Turno (fromJson/toJson/fromMap/toMap)
│   ├── reglas_turnos.dart reglas de negocio de los turnos
│   ├── barrio.dart        datos geográficos del barrio
│   └── evento_de_app.dart eventos del bus (sealed class)
├── plataforma/            Capacidades (qué PUEDE el dispositivo) y Politicas (qué DEBE hacer la app)
├── data/
│   ├── repositories/      fuente de verdad por tipo de dato (alertas, turnos, sesión)
│   └── services/          hablan con el exterior y devuelven datos crudos
│       ├── http/          contra la API real (package:http)
│       ├── simulados/     servidor simulado en memoria (sin internet)
│       └── local/         preferencias, almacenamiento seguro, sqflite (DAOs)
└── ui/
    ├── core/              tema, widgets compartidos, EstadoCarga, formato,
    │                      textos_estado (nombres de los estados, puro Dart)
    ├── conexion/          compuerta y pantalla sin conexión (tapa a todas)
    └── <pantalla>/
        ├── view_models/   un ViewModel (ChangeNotifier) por pantalla
        └── widgets/       la pantalla y sus partes

backend/                   proyecto de Dart aparte (shelf), con sus propias pruebas
```

## Principios

1. **Capas y dirección de las dependencias.**
   `ui` → `data/repositories` → `data/services`. `domain` lo usan todos y no
   importa nada de Flutter (salvo `latlong2` para coordenadas).
   - La pantalla solo habla con su ViewModel.
   - El ViewModel habla con repositorios, el bus de eventos y servicios de
     plataforma (ubicación, teléfono). Nunca recibe `BuildContext` ni
     llega, directamente ni por la cadena de `import`/`export` de archivos
     de `lib/`, a `dart:ui` ni a ningún `package:flutter/` que no sea
     `foundation.dart` (`material`, `widgets`, `painting`, `services`, …).
     Lo controla `test/unit/arquitectura_test.dart`, que corre en
     `./init.sh`. Los textos de pantalla que necesite un ViewModel van en
     archivos puros de `lib/ui/core/` (como `textos_estado.dart`); los
     íconos y colores, solo en archivos de vista
     (`presentacion_alerta.dart`).
   - El repositorio convierte el JSON a modelos, guarda caché y copia local.
   - El servicio solo habla con el exterior y devuelve `Map`/`List` crudos.

2. **Todo llega por constructor.** Las piezas se crean una sola vez en
   `lib/dependencias.dart` (de abajo hacia arriba) y se pasan por
   constructor. Nada de singletons ni `static` con estado.

3. **Cada servicio es una clase abstracta con más de una implementación.**
   Mínimo la real y una falsa o simulada. Así `Dependencias.simuladas` y
   `Dependencias.conApi` comparten todo lo demás, y las pruebas usan falsos.

4. **Decisiones de plataforma en un solo lugar.** "¿Puede llamar?",
   "¿tiene GPS?", "¿exige aviso antes del permiso?" se preguntan a
   `Capacidades` o `Politicas`. Se usa `defaultTargetPlatform` y `kIsWeb`,
   nunca `Platform.isX` de `dart:io`.

5. **El tiempo se inyecta.** Quien necesita la hora recibe un `Reloj`
   (`RelojDelSistema` en la app, `RelojFijo` en las pruebas).

6. **Reglas de negocio duplicadas a propósito.** Las reglas de turnos viven
   en `lib/domain/reglas_turnos.dart` y en `backend/lib/src/reglas.dart`, con
   los mismos mensajes: el servidor no confía en la app. Si cambia una regla,
   cambia en los dos lados y en las pruebas de los dos lados.

7. **Requiere conexión.** La app se usa solo si llega a su servidor
   (`GET /salud`). Mientras no llega, la compuerta de `ui/conexion/`
   (montada en `MaterialApp.builder`) tapa todas las pantallas con "Necesitás
   conexión a internet para usar la app" y deja a mano "Llamar al 911"; al
   volver la conexión se ve de nuevo lo que estaba abierto. La copia local
   de alertas y turnos queda solo como caché: si un pedido falla, el
   repositorio la muestra con `sinConexion` hasta que aparece la compuerta.
   Una alerta que no se pudo enviar no se guarda para mandarla después.

8. **Privacidad por defecto.** Compartir la ubicación exacta y recibir avisos
   arrancan apagados y se activan desde el perfil, con aviso propio y permiso
   del sistema. La ubicación se pide solo "mientras se usa la app".

9. **Accesibilidad no negociable.** La usan personas mayores:
   - Elementos tocables de 48 x 48 dp como mínimo (`ObjetivoTactil`).
   - Etiquetas para lector de pantalla en todo lo que no tenga texto.
   - Texto que escala hasta 200 % sin cortarse.
   - El estado nunca se comunica solo con color.
   - El botón SOS es el más grande de cada pantalla principal.

10. **Sin dependencias nuevas sin discutirlo.** Agregar un paquete a
    `pubspec.yaml` o `backend/pubspec.yaml` es una decisión de equipo: la
    feature pasa a `blocked` hasta que se acuerde y se anote en
    `progress/history.md`.

## Flujo de datos

```
Pantalla ──toca──▶ ViewModel.comando()
   ▲                    │ estado = cargando; notifyListeners()
   │                    ▼
   │              Repositorio ──▶ caché / DAO local
   │                    │
   │                    ▼
   │              Servicio (http | simulado) ──▶ backend/
   │                    │
   └──ListenableBuilder─┘ estado = exito | error; notifyListeners()
```

## Qué NO hacer

- Llamar a un servicio o hacer cuentas desde un widget.
- Crear el ViewModel dentro de `build()` (usar `ConViewModel`).
- Importar en un ViewModel `material.dart`, `widgets.dart` o un archivo que
  los importe (por ejemplo, `presentacion_alerta.dart`).
- Crear un `Future` o un `Stream` dentro de `build()`.
- Dejar suscripciones, listeners u observers sin cancelar en `dispose`.
- Usar el `context` después de un `await` sin `context.mounted`.
- Concatenar datos del usuario en SQL (usar `whereArgs`).
- Guardar el token fuera de `AlmacenSeguro`.
- Mostrar en la UI un dato que la app no puede confirmar (por ejemplo,
  cuántos vecinos recibieron un aviso).
