# Design — sos_mejorado

> Decisiones técnicas tomadas antes de escribir código. Se apoya en
> `docs/architecture.md` y `docs/conventions.md`; acá solo va lo que esta
> feature agrega o donde roza sus límites.

## Punto de partida (código actual)

- `SosViewModel.enviar()` (`lib/ui/sos/view_models/sos_view_model.dart`)
  llama a `AlertasRepository.crearAlerta` con `categoria: CategoriaAlerta.sos`,
  `tipo: 'Pedido de ayuda (SOS)'`, `descripcion: 'Un vecino pidió ayuda con
  el botón SOS.'`, la dirección y ubicación exacta o de zona, y
  `reportadaPor: _sesion.usuario?.id`. La hora (`creada_en`) la pone el
  servidor (`backend/lib/src/api.dart` › `_crearAlerta`, y el servidor
  simulado). El backend no valida el `tipo`: lo guarda tal cual (`trim`).
- `SosViewModel.cerrarAlerta()` cambia la alerta a `resuelta` y devuelve
  `true`/`false`. "Fue una falsa alarma" también termina en `resuelta` (no
  hay estado propio; igual que en el detalle, `marcarFalsaAlarma`).
- `SosScreen` (`lib/ui/sos/widgets/sos_screen.dart`) es un
  `StatelessWidget` que se abre con `MaterialPageRoute(fullscreenDialog:
  true)` desde `PrincipalScreen._abrirSos`. En el paso `enviada` muestra
  `_VistaSosEnviada` con "Llamar al 911", "Ya estoy a salvo" y "Fue una
  falsa alarma"; estos dos llaman directo a `_cerrarAlerta`, sin confirmar.
  No tiene `AppBar` ni `PopScope`: hoy el botón Atrás del sistema cierra la
  pantalla y la alerta queda activa sin ningún aviso.
- Sin conexión, `AtrasSinConexion` (`lib/ui/conexion/`) atiende el Atrás
  antes que el `Navigator` de la app. Esta feature no lo toca.
- La alerta propia aparece en Inicio (lista de cercanas, no resueltas) y en
  Perfil › "Mis alertas reportadas" (`MisAlertasScreen`), desde donde se
  abre el detalle y se puede cerrar ("Marcar como resuelta" / "Fue una falsa
  alarma"). Las dos listas se recargan con `AlertasActualizadas`, que
  `enviar()` ya publica.
- Cómo se presenta hoy una alerta (pedido del equipo, R22 a R31):
  - `TarjetaAlerta` (`lib/ui/core/widgets/tarjeta_alerta.dart`, usada en
    Inicio y en `MisAlertasScreen`) muestra el ícono de la categoría
    (`PresentacionCategoria.icono` de `lib/ui/core/presentacion_alerta.dart`:
    `campaign` para `sos`, `lock_open` para `robo`), el `tipo`, la
    dirección, el "hace" y `ChipEstado`. Va dentro de `TarjetaTocable`, que
    excluye la semántica de los hijos y anuncia solo
    `TarjetaAlerta.descripcion`: `'Alerta de ${tipo.toLowerCase()}, …'`. La
    categoría no aparece ni en texto ni en la etiqueta.
  - `PinAlerta` dibuja el **estado** (color e ícono del estado), no la
    categoría. Su etiqueta es `MapaBarrio.etiquetaDe`:
    `'Alerta: ${tipo}, ${estado}, ${direccion}. Ver resumen'`.
  - El resumen del mapa (`MapaScreen`, hoja inferior) y el detalle
    (`DetalleAlertaScreen`) muestran un `Wrap` con `ChipEstado`, el "hace" y
    `MarcaTardia`, y abajo `Text(alerta.tipo)` como título. Ninguno muestra
    la categoría.
  - Los datos de ejemplo `a3` (servidor simulado y
    `backend/lib/src/datos_de_ejemplo.dart`) son una alerta `robo` con tipo
    "Intento de robo". Las pruebas de las features 15 y 16 la buscan por ese
    texto (`widget_test.dart`, `accesibilidad_test.dart`,
    `capacidades_politicas_test.dart`, `api_test.dart`: más de 20 lugares).
- `InformeAlertas.delMes` (`lib/domain/informe_alertas.dart`, feature 14)
  agrupa "Por tipo" por `alerta.tipo.trim()` ("Sin tipo" si está vacío),
  sin mirar la categoría: un SOS "Intento de robo" y un robo "Intento de
  robo" caen en la misma fila. Ninguna prueba del informe usa alertas de
  categoría `sos` (el helper `crearAlerta` de `dominio_test.dart` fija
  `categoria: robo`; la prueba del CSV usa el tipo "Pedido de ayuda (SOS)"
  pero con categoría `robo`).
- Estilo de diálogos existente: `mostrarDialogo911` y `_cerrarSesion` del
  perfil usan `AlertDialog(scrollable: true, actionsOverflowButtonSpacing: 8)`,
  ícono arriba, cancelar a la izquierda y confirmar a la derecha.

## Archivos a crear o cambiar

| Capa | Archivo | Cambio |
|---|---|---|
| ui | `lib/ui/sos/view_models/sos_view_model.dart` | Constantes `tipoAlertaSos` y `descripcionAlertaSos`; `enviar()` usa `tipoAlertaSos` ("Intento de robo"). `cerrarAlerta()` no cambia. |
| ui | `lib/ui/sos/widgets/confirmar_cierre_sos.dart` (nuevo) | `enum CierreSos` y `Future<bool> confirmarCierreSos(...)`: los dos diálogos de confirmación. |
| ui | `lib/ui/sos/widgets/sos_screen.dart` | `PopScope` en el paso `enviada`; `_volver`; botón "Volver"; "Ya estoy a salvo" y "Fue una falsa alarma" confirman antes de cerrar. |
| domain | `lib/domain/models/alerta.dart` | Constante `prefijoSos = 'SOS: '` y getter `Alerta.tituloConCategoria` ("SOS: Intento de robo" si la categoría es `sos`; el `tipo` tal cual si no) (R27, R28). `nombreCorto` de `CategoriaAlerta.sos` ya es "SOS" (R4 se cumple sin tocar código; se agrega la prueba). |
| domain | `lib/domain/informe_alertas.dart` | Constante `filaSosInforme = 'SOS'`; en `delMes`, las alertas `sos` se cuentan en un contador aparte que da una sola fila "SOS" en "Por tipo" (R32); las demás siguen por título, y la que se titula "SOS" va como "SOS (Robo)" (R33). El orden y `toCsv()` no cambian (R34). |
| ui | `lib/ui/core/widgets/marca_sos.dart` (nuevo) | `MarcaSos`: pastilla con `Icons.campaign` y el texto "SOS", fuera de la semántica (R22 a R25, R30, R31). |
| ui | `lib/ui/core/widgets/tarjeta_alerta.dart` | `MarcaSos` junto a `ChipEstado` si la alerta es `sos`; `descripcion` empieza con "Alerta SOS: " para `sos` (R22, R26, R29). |
| ui | `lib/ui/core/widgets/mapa_barrio.dart` | `etiquetaDe` empieza con "Alerta SOS: " para `sos` (R27, R29). |
| ui | `lib/ui/mapa/widgets/mapa_screen.dart` | Resumen: `MarcaSos` primero en el `Wrap`; el título con `semanticsLabel: alerta.tituloConCategoria` (R23, R28). |
| ui | `lib/ui/alerta_detalle/widgets/detalle_alerta_screen.dart` | Igual que el resumen: `MarcaSos` en el `Wrap` y `semanticsLabel` del título (R24, R28). |
| ui | `lib/ui/core/tema/app_colors.dart` | Dos pares nuevos en `paresDeContraste`: texto sobre `emergenciaSuave` y rojo de emergencia sobre `emergenciaSuave` (R31). |
| data | — | Sin cambios en repositorios ni servicios. |
| armado | `lib/dependencias.dart` | Sin cambios. |
| backend | `backend/lib/src/` | Sin cambios de código. `a3` conserva el tipo "Intento de robo" (ver "El título de la alerta de robo de ejemplo"). Lo mismo en `lib/data/services/simulados/servidor_simulado.dart`. |
| pruebas | `test/ayudas/falsos.dart` | `AlertasFalsas.crearAlerta` guarda `categoria`, `tipo`, `descripcion` y `direccion` recibidos (hoy los descarta), y cuenta `cambiosDeEstado`. `alertaDePrueba` suma parámetros opcionales `categoria`, `tipo`, `descripcion`, `direccion` con los valores actuales por defecto. |
| pruebas | `test/unit/view_models_test.dart`, `test/widget_test.dart`, `test/accesibilidad_test.dart`, `test/unit/avisos_tardios_test.dart`, `test/unit/dominio_test.dart`, `backend/test/api_test.dart` | Ver "Pruebas". |

## Firmas nuevas

```dart
// lib/ui/sos/view_models/sos_view_model.dart
/// Título de la alerta que crea el botón SOS (R1).
const tipoAlertaSos = 'Intento de robo';

/// Descripción de la alerta del SOS, igual que antes de la feature 17 (R2).
const descripcionAlertaSos = 'Un vecino pidió ayuda con el botón SOS.';

// lib/ui/sos/widgets/confirmar_cierre_sos.dart
/// Por qué el vecino quiere cerrar su SOS.
enum CierreSos { aSalvo, falsaAlarma }

/// Pide confirmación antes de cerrar la alerta del SOS (R9, R13).
/// Devuelve true solo si el vecino toca el botón de confirmar; cancelar,
/// Atrás o tocar fuera devuelven false (R12, R16).
Future<bool> confirmarCierreSos(BuildContext context, CierreSos cierre);

// lib/ui/sos/widgets/sos_screen.dart (privados)
void _volver(BuildContext context);                       // R6, R7, R8
Future<void> _confirmarYCerrar(BuildContext context, CierreSos cierre);
```

```dart
// lib/domain/models/alerta.dart
/// Lo que se antepone al título de una alerta SOS (R27, R28). El informe
/// no lo usa: cuenta los SOS en una fila "SOS" (R32).
const prefijoSos = 'SOS: ';

// dentro de class Alerta
/// "SOS: Intento de robo" si la categoría es sos; el tipo tal cual si no.
String get tituloConCategoria =>
    categoria == CategoriaAlerta.sos ? '$prefijoSos$tipo' : tipo;

// lib/ui/core/widgets/marca_sos.dart
/// Marca visible de una alerta SOS: ícono y texto, nunca solo color (R22 a
/// R25). Fuera de la semántica: el "SOS" lo dice la etiqueta o el título
/// (R30).
class MarcaSos extends StatelessWidget {
  const MarcaSos({super.key});
}
```

`_VistaSosEnviada` cambia `onCerrarAlerta: ValueChanged<String>` por
`onCerrar: ValueChanged<CierreSos>` y suma `onVolver: VoidCallback`.

## Comportamiento de la pantalla

### Volver y el botón Atrás (R5 a R8)

- `_VistaSosEnviada` suma, al final y separado 24 dp de "Fue una falsa
  alarma", un `OutlinedButton.icon` con `Icons.arrow_back` y el texto
  "Volver", con el mismo estilo de contorno blanco (`_crearEstiloContornoSos`,
  alto mínimo 64 dp). Va último porque es la acción menos urgente: primero
  911, después cerrar la alerta, al final salir sin cerrarla.
- `SosScreen.build` envuelve el `Scaffold` en un `PopScope` dentro del
  `ListenableBuilder` (para que se recalcule con el paso):
  - `canPop: viewModel.paso != PasoSos.enviada`. En los pasos `confirmar`,
    `enviando` y `error` el Atrás sigue cerrando como hoy (la prueba
    "con conexión el botón Atrás cierra el SOS como siempre" no cambia).
  - `onPopInvokedWithResult: (didPop, _) { if (!didPop) _volver(context); }`.
    Así el Atrás del sistema en el paso `enviada` hace exactamente lo mismo
    que "Volver" (R7).
- `_volver(context)` toma `Navigator` y `ScaffoldMessenger` antes de cerrar,
  hace `pop()` y muestra con `mostrarAvisoEn` el aviso de R8:
  `Tu alerta sigue activa. La encontrás en Perfil, en "Mis alertas reportadas".`
  No llama al ViewModel: la alerta no cambia (R6).
- Los cierres por "Sí, estoy a salvo" / "Sí, fue una falsa alarma" usan
  `Navigator.pop()` directo (como hoy `_cerrar`). `pop()` no pasa por
  `canPop`, así que no se dispara `_volver` ni el aviso de "sigue activa".
- Con la compuerta de conexión arriba, `AtrasSinConexion` atiende el Atrás
  primero y no llega al `PopScope`: sin cambios en ese caso.

Cómo vuelve a encontrar el vecino su alerta: el aviso de R8 le dice dónde
está (Perfil › "Mis alertas reportadas", el mismo texto del menú del
perfil). Además la alerta aparece en la lista de Inicio, porque `enviar()`
ya publica `AlertasActualizadas`. Desde el detalle de su alerta puede
marcarla resuelta o falsa alarma, como hoy. No se agrega ningún banner ni
acceso nuevo.

### Confirmaciones (R9 a R17)

`_confirmarYCerrar(context, cierre)`:

1. `final confirmo = await confirmarCierreSos(context, cierre);`
2. Si `!confirmo || !context.mounted`, no hace nada (R12, R16): no llama al
   ViewModel y la pantalla queda como estaba.
3. Si confirmó, llama a `viewModel.cerrarAlerta()` y, con el resultado,
   reutiliza el `_cerrar(context, mensaje)` actual:
   - `ok` y `aSalvo` → "Marcaste la alerta como resuelta" (R11).
   - `ok` y `falsaAlarma` → "Cancelaste la alerta: fue una falsa alarma" (R15).
   - `!ok` → "No pudimos cerrar la alerta. Hacelo desde "Mis alertas"." (R17).

### Textos de los diálogos

`confirmarCierreSos` arma un `AlertDialog` con el mismo esqueleto que
`mostrarDialogo911`:

| | `CierreSos.aSalvo` | `CierreSos.falsaAlarma` |
|---|---|---|
| Ícono (decorativo) | `Icons.check_circle_outline`, `AppColors.resuelta`, 32 | `Icons.cancel_outlined`, `AppColors.texto`, 32 |
| Título | ¿Ya estás a salvo? | ¿Fue una falsa alarma? |
| Texto | Tu alerta va a quedar como resuelta. Si todavía necesitás ayuda, tocá "Seguir con la alerta". | Tu alerta se va a cancelar y va a quedar como resuelta. Si de verdad necesitás ayuda, tocá "Seguir con la alerta". |
| Cancelar (`OutlinedButton`) | Seguir con la alerta | Seguir con la alerta |
| Confirmar (`FilledButton`) | Sí, estoy a salvo (fondo `AppColors.resuelta`) | Sí, fue una falsa alarma (fondo `AppColors.primary`) |

Por qué estos textos:

- Voseo y frases cortas, sin tecnicismos.
- El botón de cancelar **no** dice "Cancelar": en el diálogo de falsa alarma
  "cancelar" se confunde con "cancelar la alerta" (el aviso final dice
  justamente "Cancelaste la alerta"). "Seguir con la alerta" dice qué pasa.
- Los botones de confirmar repiten la pregunta ("Sí, estoy a salvo"), así
  se entienden solos, sin leer el título (lector de pantalla, memoria).
- Confirmar es relleno y cancelar es contorno: se distinguen por la forma
  y por el texto, no solo por el color (R20). El verde de "a salvo" es el
  mismo de "resuelta" en el resto de la app; para falsa alarma se usa el
  azul principal y no el rojo, porque no es una acción de emergencia.
- `showDialog<bool>`; `barrierDismissible` queda en `true` (por defecto).
  Atrás o tocar fuera devuelven `null`, que se toma como `false` (R12, R16).

## SOS y robo con el mismo título (pedido del equipo, R22 a R31)

### Qué se ve

`MarcaSos` copia la forma de `MarcaTardia` (radio 8, borde, ícono + texto)
para que no se confunda con `ChipEstado` (pastilla redonda de color
sólido):

- `Container` con `padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4)`,
  fondo `AppColors.emergenciaSuave`, borde `AppColors.emergencia` de 1.5 y
  radio 8.
- `Row(mainAxisSize: min)`: `Icon(Icons.campaign, size: 16, color:
  AppColors.emergencia)` y `Flexible(Text('SOS'))` en `AppColors.texto`,
  negrita, 14.
- Todo envuelto en `ExcludeSemantics` (R30).

Dónde va:

- **Tarjeta** (`TarjetaAlerta`): el `ChipEstado` de abajo pasa a un
  `Wrap(spacing: 8, runSpacing: 8)` con `if (sos) const MarcaSos()` primero
  y `ChipEstado` después. Con texto al 200 % el `Wrap` baja la marca o el
  chip de renglón (R31). El ícono `campaign` del avatar no cambia.
- **Resumen del mapa** y **detalle**: `if (sos) const MarcaSos()` como
  primer hijo del `Wrap` que ya tienen (antes de `ChipEstado`).
- **Pin del mapa**: no cambia su dibujo. El pin representa el estado (es la
  convención de la leyenda del mapa); el SOS se distingue en su etiqueta
  (R27) y en el resumen que abre al tocarlo (R23, R28).

Alertas de otras categorías: no llevan marca (R25) y sus etiquetas no
cambian (R29), así que las pruebas actuales que buscan
`'Alerta de intento de robo, …'` o `RegExp('^Alerta: Intento')` siguen
encontrando solo `a3`.

### Qué dice el lector de pantalla

| Lugar | Alerta `sos` | Otra categoría (sin cambios) |
|---|---|---|
| Tarjeta (`TarjetaAlerta.descripcion` + ". Ver detalle") | `Alerta SOS: intento de robo, hace 5 minutos, activa. Calle Plantamura. Ver detalle` | `Alerta de intento de robo, hace 1 hora, activa. …` |
| Pin (`MapaBarrio.etiquetaDe`) | `Alerta SOS: Intento de robo, activa, Calle Plantamura. Ver resumen` | `Alerta: Intento de robo, activa, …` |
| Título del resumen y del detalle | `SOS: Intento de robo` | `Intento de robo` |

Implementación:

```dart
// TarjetaAlerta.descripcion (el resto del texto igual)
final titulo = alerta.categoria == CategoriaAlerta.sos
    ? 'Alerta SOS: ${alerta.tipo.toLowerCase()}'
    : 'Alerta de ${alerta.tipo.toLowerCase()}';

// MapaBarrio.etiquetaDe (el resto del texto igual)
final titulo = alerta.categoria == CategoriaAlerta.sos
    ? 'Alerta ${alerta.tituloConCategoria}' // "Alerta SOS: Intento de robo"
    : 'Alerta: ${alerta.tipo}';

// Resumen del mapa y detalle
Text(alerta.tipo, semanticsLabel: alerta.tituloConCategoria, style: …)
```

"Alerta SOS: …" y no "Alerta de sos: …" ni "Alerta: SOS: …": se lee de
corrido, no repite los dos puntos y "SOS" queda en mayúsculas, como en el
botón SOS.

Los SOS viejos con tipo "Pedido de ayuda (SOS)" se anuncian "Alerta SOS:
pedido de ayuda (sos)". Es redundante pero correcto; no se migran.

### El título de la alerta de robo de ejemplo (`a3`)

Se **mantiene** "Intento de robo" en el servidor simulado y en
`backend/lib/src/datos_de_ejemplo.dart`. Motivos:

- El problema no es de los datos de ejemplo: cuando un vecino reporte un
  robo real (feature 18) puede ponerle el mismo título que el SOS. La
  distinción tiene que salir de la categoría, que es lo que resuelven R22 a
  R31; cambiar `a3` solo escondería el caso en la demo.
- `a3` es la alerta que usan más de 20 pruebas de las features 15 y 16
  (tardías, "Reportada por", accesibilidad, backend). Renombrarla obliga a
  tocar pruebas de otras personas sin verificar nada nuevo.
- Con la marca y las etiquetas nuevas, un SOS enviado y `a3` ya no se ven
  ni se escuchan iguales.

## Informe mensual: todos los SOS en una fila "SOS" (pedido del equipo, R32 a R34)

### Opción elegida: contador aparte para los SOS

En `lib/domain/informe_alertas.dart` (que ya importa `models/alerta.dart`;
suma `import 'avisos_tardios.dart';` para `nombreCorto`):

```dart
/// Nombre de la fila de "Por tipo" que cuenta todas las alertas SOS (R32).
const filaSosInforme = 'SOS';

// dentro de delMes, antes del for
var sos = 0;

// dentro del for, en lugar de la línea de hoy que calcula `tipo`
if (alerta.categoria == CategoriaAlerta.sos) {
  sos++;                                                  // R32
} else {
  final tipo = _nombreDeTipo(alerta);                     // R33
  tipos[tipo] = (tipos[tipo] ?? 0) + 1;
}

// después del for, antes de _ordenar
if (sos > 0) tipos[filaSosInforme] = sos;                 // R32

// privado de InformeAlertas
/// El título tal cual ("Sin tipo" si está vacío); si una alerta que no es
/// SOS se titula "SOS", se le suma la categoría para no confundirla con la
/// fila de los SOS (R33).
static String _nombreDeTipo(Alerta alerta) {
  final titulo = alerta.tipo.trim();
  if (titulo.isEmpty) return 'Sin tipo';
  if (titulo.toLowerCase() == filaSosInforme.toLowerCase()) {
    return '$titulo (${alerta.categoria.nombreCorto ?? 'otra categoría'})';
  }
  return titulo;
}
```

- Un mes con un SOS "Intento de robo", un SOS "Pedido de ayuda (SOS)" y
  dos robos "Intento de robo" da `Intento de robo · 2` y `SOS · 2` (R32,
  R33). El título del SOS no importa: los SOS viejos ("Pedido de ayuda
  (SOS)") y los nuevos ("Intento de robo") van a la misma fila.
- La fila "SOS" entra en el mismo mapa `tipos` y se ordena con las demás
  por `_ordenar` (de mayor a menor y, a igual cantidad, alfabético), como
  pide R3 de `informe_alertas`.
- `toCsv()` no cambia: escribe `Por tipo,SOS,2` (R34).
- La pantalla del informe no cambia: `_FilaTablaInforme` muestra
  `fila.nombre`, así que se ve y se lee "SOS".
- `tituloConCategoria` y `prefijoSos` no se usan en el informe; siguen
  solo para el detalle, el resumen del mapa y el lector (R27, R28).

### Un robo titulado "SOS" no se mezcla con la fila de los SOS

Puede pasar: `POST /alertas` (`backend/lib/src/api.dart`, `_crearAlerta`)
guarda el `tipo` que mande la app sin validarlo, y la feature 18
(`reportar_alerta`) deja que el vecino ajuste el título de una alerta que
no es SOS. Por eso el diseño no depende de que "SOS" nunca llegue como
título:

1. **El conteo no se mezcla nunca.** Los SOS se suman en `sos`, no en el
   mapa por título; una alerta de otra categoría jamás toca ese contador,
   se llame como se llame (R32).
2. **El nombre de la fila tampoco se confunde.** Si una alerta que no es
   SOS se titula "SOS" (comparando sin mayúsculas y sin espacios al borde:
   "SOS", "sos", " Sos "), su fila se llama "<título> (<categoría>)", por
   ejemplo "SOS (Robo)" (R33). Así la clave `'SOS'` del mapa queda
   reservada para el contador de los SOS, y en la tabla y el CSV nunca hay
   dos filas "SOS" (ni una "sos" que el lector de pantalla lea igual). Si
   la categoría no tiene nombre corto (arrebato), se usa "otra categoría".
3. Un título que solo contiene "SOS" ("Pedido de ayuda (SOS)" en un robo)
   no es "SOS" y se cuenta tal cual (R33).

Impacto sobre la feature 14 (`done`): cambia el cálculo de `tipo` dentro
de `delMes` y se suman el contador y `_nombreDeTipo`. Ninguna de sus
pruebas usa alertas `sos` ni alertas tituladas "SOS", así que **ninguna se
rompe ni se cambia**, y sus R1 a R13 siguen cumplidos (R3 se refina solo
para la categoría `sos` y para el título "SOS"). Las pruebas nuevas van en
el mismo grupo `Informe de alertas` de `test/unit/dominio_test.dart`; para
eso el helper `crearAlerta` suma un parámetro opcional `categoria` (por
defecto `CategoriaAlerta.robo`, como hoy), lo que no cambia ninguna prueba
existente. El widget de la feature 14 (`widget_test.dart`,
`find.text('Intento de robo')` `findsOneWidget` en el informe) sigue verde:
no envía ningún SOS y los datos de ejemplo no tienen alertas `sos`.

### Alternativa descartada: prefijo "SOS: <título>" en la clave

Era la versión anterior de este spec: una fila "SOS: Intento de robo" por
cada título de SOS. Se descarta por pedido del equipo: la comisión quiere
un solo número de SOS en el mes, y con el prefijo los SOS viejos ("SOS:
Pedido de ayuda (SOS)") y los nuevos quedaban en filas distintas. Además,
al ser solo un texto en la clave, un robo titulado "SOS: Intento de robo"
se habría sumado a la fila de los SOS.

También se descarta **guardar los SOS en el mapa con la clave "SOS" sin
contador aparte**: un robo titulado "SOS" caería en la misma clave y se
sumaría a los SOS, justo lo que R32 prohíbe. Y se descarta **agrupar "Por
tipo" por categoría para todas las alertas**: cambia el sentido de R3 de
`informe_alertas` y rompe su prueba de "Por tipo", que cuenta títulos
distintos de la misma categoría por separado.

## API y datos

- Rutas: ninguna cambia. `POST /alertas` recibe `tipo: "Intento de robo"`
  en vez de `"Pedido de ayuda (SOS)"`; el backend ya lo acepta y lo guarda.
- JSON de los modelos: sin cambios.
- sqflite: sin cambios (ni tabla ni versión).
- Alertas SOS ya guardadas con "Pedido de ayuda (SOS)" quedan como están;
  no se migran.
- `tituloConCategoria` y `prefijoSos` son solo de lectura: no viajan en el
  JSON ni se guardan en sqflite. Datos de ejemplo: sin cambios.

## Plataforma

No depende de la plataforma. No pregunta nada nuevo a `Capacidades` ni a
`Politicas`; el 911 sigue con `mostrarDialogo911`.

## Accesibilidad

- **48 dp:** "Volver" tiene alto mínimo 64 dp y ancho completo (estilo de
  contorno del SOS). En los diálogos, los dos botones llevan
  `minimumSize: const Size(0, 48)` (más que los 44 de `mostrarDialogo911`),
  y el tema ya da 52 de alto a `FilledButton` y `OutlinedButton`.
  Verificado con `androidTapTargetGuideline` e `iOSTapTargetGuideline` (R18).
- **Lector de pantalla:** los botones usan su texto visible como etiqueta
  (`labeledTapTargetGuideline`); el ícono de "Volver" y los de los diálogos
  quedan fuera de la semántica (el de "Volver" ya lo absorbe
  `OutlinedButton.icon`; los del diálogo son `icon:` del `AlertDialog`,
  decorativos). El título del diálogo lo anuncia `AlertDialog` como nombre
  de la ruta (R21).
- **Texto al 200 %:** la vista enviada ya está dentro de
  `SingleChildScrollView` + `IntrinsicHeight`; "Volver" suma un botón más
  y se alcanza desplazando. Los diálogos usan `scrollable: true` y
  `actionsOverflowButtonSpacing: 8`: si los botones no entran en una fila,
  se apilan (R19).
- **Sin depender del color:** confirmar/cancelar por forma y texto (R20).
  El estado de la alerta después de cerrar se dice con texto en el aviso.
- **Marca SOS (R22 a R31):** ícono y texto "SOS", nunca solo el color, y
  forma distinta de `ChipEstado` (radio 8 con borde vs. pastilla sólida).
  No es tocable: no suma objetivos táctiles y la tarjeta sigue siendo un
  solo botón de `TarjetaTocable`. Queda fuera de la semántica para que el
  lector diga "SOS" una sola vez: en la etiqueta de la tarjeta o del pin, o
  en el título del resumen y del detalle (R26 a R28, R30). Contraste:
  `AppColors.texto` sobre `AppColors.emergenciaSuave` (texto normal, 4,5) y
  `AppColors.emergencia` sobre `AppColors.emergenciaSuave` (ícono y borde,
  componente, 3) se suman a `AppColors.paresDeContraste`, que ya recorre
  `accesibilidad_test.dart`. Con texto al 200 % el `Wrap` la pasa de
  renglón y el texto es `Flexible`.
- **Contraste:** `AppColors.resuelta` y `AppColors.primary` con texto
  blanco ya pasan `textContrastGuideline` en otras pantallas (el detalle
  usa el mismo verde en "Marcar como resuelta"). El contorno blanco sobre
  `AppColors.emergencia` es el de los botones que ya existen.

## Pruebas

### Nuevas

- `test/unit/view_models_test.dart` (grupo `SosViewModel`):
  - `enviar crea una alerta sos con el título "Intento de robo"` (R1).
  - `enviar manda la descripción, la dirección y quien reporta como antes`
    (R2).
  - `si falla cerrarAlerta devuelve false y la alerta sigue activa` (R17).
- `test/unit/avisos_tardios_test.dart`:
  `el aviso tardío de un SOS "Intento de robo" dice "SOS de Marta 15:10"` (R4).
- `backend/test/api_test.dart`: en `la alerta nueva queda a nombre de quien
  tiene la sesión`, el cuerpo manda `'tipo': 'Intento de robo'` y se
  verifica `alerta['tipo'] == 'Intento de robo'` y `alerta['categoria'] ==
  'sos'` (R3; `creada_en` y `estado` ya se verifican).
- `test/widget_test.dart` (grupo nuevo `SOS enviado`, con `SosScreen`
  dentro de una ruta empujada sobre una pantalla base, para poder verificar
  el cierre y el aviso):
  - `la pantalla del SOS enviado muestra "Volver"` (R5).
  - `"Volver" cierra el SOS, deja la alerta activa y avisa dónde
    encontrarla` (R6, R8).
  - `el botón Atrás en el SOS enviado hace lo mismo que "Volver"` (R7, R8),
    con `tester.binding.handlePopRoute()`.
  - `"Ya estoy a salvo" pide confirmación con los textos acordados` (R9,
    R20).
  - `confirmar "Sí, estoy a salvo" resuelve la alerta y cierra con aviso`
    (R10, R11).
  - `"Seguir con la alerta" en "Ya estoy a salvo" no cambia nada` (R12),
    y la variante con Atrás dentro del diálogo.
  - `"Fue una falsa alarma" pide confirmación con los textos acordados`
    (R13, R20).
  - `confirmar "Sí, fue una falsa alarma" resuelve la alerta y cierra con
    aviso` (R14, R15).
  - `"Seguir con la alerta" en "Fue una falsa alarma" no cambia nada` (R16),
    y la variante tocando fuera del diálogo.
  - `si falla el cierre se avisa que se haga desde "Mis alertas"` (R17).
- `test/accesibilidad_test.dart`, lista `pantallas` (corre con las guías y
  también al 200 %):
  - `SOS: confirmar "Ya estoy a salvo" (diálogo)` (R18, R19, R21).
  - `SOS: confirmar "Fue una falsa alarma" (diálogo)` (R18, R19, R21).
  - La entrada existente `SOS: alerta enviada` suma
    `expect(find.text('Volver'), findsOneWidget)` (R18, R19).
  - Prueba nueva `el botón "Volver" y los botones de los diálogos se
    anuncian con su texto` con `tester.getSemantics` (R21).

- `test/unit/dominio_test.dart`:
  - `tituloConCategoria antepone "SOS: " solo a las alertas sos` (R28,
    R29).
  - Grupo `Informe de alertas` (helper `crearAlerta` con `categoria`
    opcional):
    - `cuenta todos los SOS en una sola fila "SOS"`: un `sos` "Intento de
      robo", un `sos` "Pedido de ayuda (SOS)" y dos `robo` "Intento de
      robo" → `porTipo` `['Intento de robo:2', 'SOS:2']` (R32, R33).
    - `un robo titulado "SOS" no se suma a la fila de los SOS`: un `sos`
      "Intento de robo", un `robo` "SOS", un `robo` " sos " y un `robo`
      "Pedido de ayuda (SOS)" → `['Pedido de ayuda (SOS):1', 'SOS:1',
      'SOS (Robo):1', 'sos (Robo):1']` (R32, R33).
    - `el CSV trae una sola fila de los SOS`: dos `sos` con títulos
      distintos → `toCsv()` `contains('Por tipo,SOS,2')` y
      `isNot(contains('Por tipo,SOS: '))` (R34).
- `test/widget_test.dart` (grupo nuevo `SOS y robo con el mismo título`,
  con `appDePrueba`: enviar un SOS, tocar "Volver" y mirar Inicio, Mapa,
  detalle y "Mis alertas reportadas", donde también está `a3`):
  - `la tarjeta del SOS lleva la marca SOS y la de robo no` (R22, R25):
    `find.descendant(of: tarjetaSos, matching: find.byType(MarcaSos))`
    `findsOneWidget`, y `findsNothing` dentro de la tarjeta de `a3`.
  - `la tarjeta del SOS se anuncia "Alerta SOS: intento de robo, …" y la
    de robo como antes` (R26, R29), con `tester.getSemantics`.
  - `el pin del SOS se anuncia "Alerta SOS: Intento de robo, …" y su
    resumen muestra la marca y lee "SOS: Intento de robo"` (R23, R27, R28);
    el pin y el resumen de `a3` siguen como hoy, sin marca (R25, R29).
  - `el detalle del SOS muestra la marca y lee "SOS: Intento de robo"`
    (R24, R28); el de `a3` no tiene marca y lee "Intento de robo" (R25,
    R29).
  - `"Mis alertas reportadas" muestra la marca SOS en la alerta enviada`
    (R22).
  - `la marca SOS no se anuncia aparte` (R30): en Inicio, el resumen y el
    detalle, `find.bySemanticsLabel('SOS')` (etiqueta exacta)
    `findsNothing`.
- `test/accesibilidad_test.dart`, lista `pantallas` (guías y 200 %):
  `Inicio con una alerta SOS`, `Resumen de una alerta SOS en el mapa` y
  `Detalle de una alerta SOS` (envían un SOS, tocan "Volver" y abren cada
  vista buscando por `RegExp('^Alerta SOS: ')`) (R31). Los pares nuevos de
  `AppColors.paresDeContraste` los recorre la prueba de contraste existente
  (R31).

### Existentes que cambian

- `test/unit/dominio_test.dart` › helper `crearAlerta` del grupo `Informe
  de alertas`: suma `CategoriaAlerta categoria = CategoriaAlerta.robo`. Las
  pruebas del informe (feature 14) no cambian.

- `test/unit/view_models_test.dart` › `"Ya estoy a salvo" deja la alerta
  resuelta`: sigue igual (prueba `cerrarAlerta`, que no cambia).
- `test/unit/view_models_test.dart` › `enviar crea una alerta SOS y avisa
  al resto de la app`: suma la verificación de `categoria` y `tipo` (o se
  deja y la nueva de R1 lo cubre).
- `test/ayudas/falsos.dart` › `AlertasFalsas.crearAlerta`: hoy descarta
  `categoria`, `tipo`, `descripcion` y `direccion`; pasa a guardarlos. Las
  pruebas que usan `AlertasFalsas.crearAlerta` (`repositorios_test.dart`
  línea ~322, `ubicacion_test.dart`) deben seguir verdes: revisarlas, porque
  la alerta creada deja de ser siempre `robo`/"Intento de robo"/"Prueba".
- Datos de prueba con `'Pedido de ayuda (SOS)'` en
  `test/unit/persistencia_test.dart`, `test/unit/notificaciones_test.dart`,
  `test/unit/avisos_tardios_test.dart`, `test/unit/dominio_test.dart` y
  `backend/test/api_test.dart` (salvo el caso de R3): **no** se cambian. Son
  alertas armadas a mano para probar otra cosa; el texto del tipo no es lo
  que verifican.
- Ninguna prueba existente toca "Ya estoy a salvo" o "Fue una falsa alarma"
  en `SosScreen` a nivel de widget, así que ninguna se rompe por el diálogo
  nuevo.

## Paquetes nuevos

Ninguno.

## Alternativas descartadas

**Cambiar la categoría del SOS a `robo`.** Haría coincidir el ícono con el
título, pero el equipo decidió que siga siendo `sos`: el SOS tiene su color,
su ícono y su prioridad, y el aviso tardío tiene que seguir diciendo "SOS".

**Bloquear el Atrás del sistema en el SOS enviado (`canPop: false` sin
hacer nada).** Obligaría a elegir un botón, pero deja al vecino "trabado"
en una pantalla roja si no encuentra "Volver" (texto grande, desplazamiento)
y va contra lo que espera de Android. Se descarta: Atrás hace lo mismo que
"Volver".

**Dejar el Atrás como hoy (cierra sin aviso).** Funciona, pero entonces
"Volver" avisa dónde está la alerta y Atrás no: dos salidas iguales con
resultados distintos. Se descarta por coherencia.

**Un diálogo genérico en `lib/ui/core/widgets/`** (título, texto y botones
por parámetro), reutilizable por el perfil. Se descarta por ahora: hoy solo
lo usa el SOS y la feature no debe tocar el diálogo de cerrar sesión.
`confirmarCierreSos` queda en `lib/ui/sos/widgets/`; si otra feature lo
necesita, se mueve.

**Mover la confirmación al ViewModel** (por ejemplo un estado
`confirmandoCierre`). Se descarta: la confirmación es UI pura (un diálogo
modal que devuelve `bool`) y el ViewModel no debe conocer diálogos ni
`BuildContext`; el patrón ya usado en la app (`_cerrarSesion`,
`mostrarDialogo911`) lo resuelve en el widget.

**Mostrar "SOS: Intento de robo" como texto visible del título.** Resuelve
la confusión con una sola cadena, pero cambia el título visible que el
equipo fijó ("Intento de robo") y rompe las búsquedas por `find.text` del
título. Se descarta: el título visible sigue siendo el `tipo` y la
categoría se dice con la marca SOS y con la semántica.

**Dibujar el ícono de la categoría en el pin del mapa.** Haría visible el
SOS sin abrir el resumen, pero el pin representa el estado (ícono y color)
y la leyenda del mapa se apoya en eso; mezclar categoría y estado en 32 dp
lo vuelve ilegible. Se descarta: el pin se distingue por su etiqueta y el
resumen por la marca.

**Renombrar la alerta de robo de ejemplo (`a3`)**, por ejemplo a "Robo en
vivienda", en el servidor simulado y en el backend. Se descarta (ver "El
título de la alerta de robo de ejemplo").

## Riesgos y notas

- **Pruebas que buscan "Intento de robo".** `accesibilidad_test.dart`
  (`Detalle de alerta`, `Inicio con una alerta tardía`) usa
  `find.widgetWithText(TarjetaAlerta, 'Intento de robo')`. Hoy no envían un
  SOS antes, así que siguen encontrando una sola. Las pruebas nuevas que
  envían un SOS y después buscan su tarjeta o su pin van a encontrar dos
  "Intento de robo": tienen que buscar por etiqueta
  (`RegExp('^Alerta SOS: ')` para el SOS; `RegExp('^Alerta de intento')` o
  `RegExp('^Alerta: Intento')` para `a3`).
- La feature 18 (`reportar_alerta`) y la 19 no se tocan.
