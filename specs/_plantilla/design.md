# Design — <name>

> Decisiones técnicas tomadas antes de escribir código. Se apoya en
> `docs/architecture.md` y `docs/conventions.md`; acá solo va lo que esta
> feature agrega o donde roza sus límites.

## Archivos a crear o cambiar

| Capa | Archivo | Cambio |
|---|---|---|
| domain | `lib/domain/…` | … |
| data | `lib/data/repositories/…` | … |
| data | `lib/data/services/…` | … |
| ui | `lib/ui/<pantalla>/view_models/…` | … |
| ui | `lib/ui/<pantalla>/widgets/…` | … |
| armado | `lib/dependencias.dart` | … |
| backend | `backend/lib/src/…` | … |
| pruebas | `test/…`, `backend/test/…` | … |

## Firmas nuevas

```dart
// clases, métodos y getters nuevos, con sus tipos
```

## API y datos

- Rutas nuevas o cambiadas (método, ruta, cuerpo, respuesta, errores): …
- Cambios en el JSON de los modelos: …
- Cambios en sqflite (tabla, columna, versión y migración en `onUpgrade`): …
- Ninguno, si no aplica.

## Plataforma

Qué pregunta a `Capacidades` o `Politicas`, o "no depende de la plataforma".

## Accesibilidad

Cómo cumple 48 dp, etiquetas, texto al 200 % y estados sin depender del
color. "No tiene pantalla", si no aplica.

## Paquetes nuevos

Ninguno. (O cuál, y dónde quedó anotada la decisión del equipo.)

## Alternativa descartada

**<Alternativa>.** Se descarta porque …

## Riesgos y notas

- …
