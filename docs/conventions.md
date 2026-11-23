# Convenciones

> Homogeneidad: cuanto más se parece el repositorio a sí mismo, mejor lo
> entienden las personas y los agentes.

## Idioma

- Código, comentarios, pruebas, specs, commits y textos de la app en
  **español**. Términos técnicos que ya son nombres propios quedan en inglés
  (`ViewModel`, `dispose`, `token`).
- Los textos para el vecino van en **voseo** ("Tocá", "Anotate"), cortos y
  sin tecnicismos.

## Estilo Dart

- `dart format .` antes de cada commit. `flutter analyze` sin avisos (reglas
  de `flutter_lints`).
- `const` siempre que se pueda.
- Parámetros con nombre para todo booleano y para funciones de más de dos
  parámetros.
- Imports: primero `dart:`, después paquetes, después relativos del proyecto.
  En `test/` se importa con `package:barrio_seguro/...`.

## Nombres

| Tipo | Convención | Ejemplo |
|---|---|---|
| Archivos | `snake_case` | `turnos_view_model.dart` |
| Clases y enums | `UpperCamelCase` | `TurnosViewModel`, `EstadoAlerta` |
| Variables, métodos y constantes | `lowerCamelCase` | `maxTurnosPorMes`, `cargar()` |
| Privados | prefijo `_` | `_repositorio` |
| Booleanos | como pregunta | `sinConexion`, `esGuardiaVentanaEn()` |
| Métodos | verbo | `cargar()`, `enviar()`, `cerrarAlerta()` |

Sufijos por capa: `…Screen`, `…ViewModel`, `…Repository`, `…Service`,
`…Dao`. Las implementaciones llevan el cómo: `…Http`, `…Simulado`,
`…Falso` / `…Falsas`.

## Estructura de una pantalla nueva

```
lib/ui/<pantalla>/
├── view_models/<pantalla>_view_model.dart
└── widgets/<pantalla>_screen.dart
```

- El ViewModel expone un `EstadoCarga` y getters de solo lectura.
- La pantalla se arma con `ConViewModel` y `ListenableBuilder`.
- Si un `build` crece, se parte en **clases** de widget, no en métodos
  `_buildX()`.

## Errores

- Un error de la API llega como `ErrorDelServidor` con un mensaje para
  mostrarle al vecino tal cual.
- Un error de red no se muestra como error: el repositorio usa la copia
  local y la pantalla muestra `AvisoSinConexion`.
- El backend responde `{"error": "..."}` con 400, 401, 403, 404 o 409.

## Comentarios

`///` para documentar lo público. `//` solo para explicar un **porqué** que
el código no dice. El código comentado se borra.

## Git

- Ramas: `main` (entregas), `develop` (integración) y una rama por feature:
  `feature/<name>` con el mismo `name` que en `feature_list.json`.
- El spec se commitea en la rama **antes** del código: así queda en el PR.
- Mensajes de commit en español, en infinitivo y concretos:
  `Agregar informe mensual de alertas`, `Actualizar pubspec.lock con …`.
- Se integra a `develop` con un pull request que menciona la feature.
