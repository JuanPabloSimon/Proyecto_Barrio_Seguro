# Implementación — avisos_tardios (feature 16)

- **Rama:** `feature/avisos_tardios` (sin commitear)
- **Spec:** `specs/avisos_tardios/` (R1–R35, T1–T35, todas `[x]`)
- **Estado:** `in_progress`. Falta la revisión del reviewer; no se marcó `done`.
- **Paquetes nuevos:** ninguno.

## Archivos tocados

### App (`lib/`)

| Archivo | Cambio |
|---|---|
| `lib/domain/avisos_tardios.dart` | **Nuevo.** `demoraParaTardia`, `demoraMaximaParaAvisar`, `PuntualidadAviso`, `clasificarAviso`, `esTardia`, `NombreCortoCategoria.nombreCorto`, `tipoParaAviso`, `horaYMinutos`, `tituloAvisoTardio`, `cuerpoAvisoTardio`. |
| `lib/domain/models/alerta.dart` | `reportadaPorNombre` (`''` por defecto) en constructor, `fromJson` y `toJson`. |
| `lib/data/services/local/preferencias.dart` | Claves `avisos_recibidos` y `desfase_reloj` (en `todasLasClaves`) y sus métodos. |
| `lib/data/repositories/avisos_recibidos_repository.dart` | **Nuevo.** `AvisosRecibidosRepository` + `AvisosRecibidosRepositoryLocal` (desfase, primera llegada, borra llegadas de más de 30 días). |
| `lib/data/services/conexion_service.dart` | `Duration? get desfase`. |
| `lib/data/services/http/conexion_service_http.dart` | Recibe `Reloj`; mide el desfase con `ahora` de `/salud` en el punto medio del pedido. |
| `lib/data/services/simulados/conexion_service_simulado.dart` | `desfase = Duration.zero`. |
| `lib/data/repositories/conexion_repository.dart` | `ConexionRepositoryRemoto(avisos:)` guarda el desfase después de cada comprobación buena. |
| `lib/data/services/notificaciones_service.dart` | `avisarAlertaTardia` en la interfaz, `…Locales` (mismo id y payload, por un `_mostrar` común) y `…Ninguno`. `avisarAlerta` sigue con el mismo título y cuerpo. |
| `lib/data/services/push_service.dart` | `alertaDesdeDatosPush` lee `reportada_por_nombre`; `procesarAvisoPush(avisos:)` registra la llegada y elige el aviso normal, el tardío o ninguno; el handler de segundo plano arma su `AvisosRecibidosRepositoryLocal`. |
| `lib/data/services/local/base_de_datos.dart` | Esquema v4: columna `reportada_por_nombre` y migración `anterior < 4`. |
| `lib/data/services/simulados/servidor_simulado.dart` | `_conNombre` en `alertas()`, `crearAlerta` y `cambiarEstadoDeAlerta` (no se guarda). |
| `lib/dependencias.dart` | `Dependencias.avisos`; `_armar` crea `AvisosRecibidosRepositoryLocal` y se lo pasa a `ConexionRepositoryRemoto`; `conApi` arma `ConexionServiceHttp(api, reloj: reloj)`. |
| `lib/ui/core/formato.dart` | `marcaTardia({creadaEn, ahora})`. |
| `lib/ui/core/widgets/marca_tardia.dart` | **Nuevo.** `MarcaTardia`. |
| `lib/ui/core/widgets/pin_alerta.dart` | `tardia`: distintivo de reloj. |
| `lib/ui/core/widgets/tarjeta_alerta.dart` | `tardia`: marca y texto en `descripcion`. |
| `lib/ui/core/widgets/mapa_barrio.dart` | `tardias` (id → marca): pin con reloj y `etiquetaDe(tardia:)`. |
| `lib/ui/core/tema/app_colors.dart` | Pares "Texto de la marca tardía", "Ícono de la marca tardía" y "Reloj del pin de una alerta tardía". |
| `lib/ui/inicio/view_models/inicio_view_model.dart` | `avisos`, llegadas en `cargar()`, `tardia()`, `tardias`. |
| `lib/ui/inicio/widgets/inicio_screen.dart` | `tardia` en cada tarjeta, `tardias` en el mapa chico. |
| `lib/ui/mapa/view_models/mapa_view_model.dart` | Lo mismo que el inicio. |
| `lib/ui/mapa/widgets/mapa_screen.dart` | `tardias` en `MapaBarrio`, marca en el resumen e ítem "Llegó con demora" en la leyenda. |
| `lib/ui/alerta_detalle/view_models/detalle_alerta_view_model.dart` | `avisos`, `cargarLlegada()`, `tardia`, `reportadaPor`. |
| `lib/ui/alerta_detalle/widgets/detalle_alerta_screen.dart` | `abrir` pasa `avisos` y llama `cargarLlegada()`; marca debajo del estado; "Reportada por" con `viewModel.reportadaPor` dentro de `MergeSemantics`. |
| `lib/ui/principal/vigilante_de_alertas.dart` | `avisos`: guarda llegadas → publica `AlertasActualizadas` → avisa según la clasificación; devuelve las que avisó. |
| `lib/ui/principal/widgets/principal_screen.dart` | Pasa `d.avisos` a `InicioViewModel`, `MapaViewModel` y `VigilanteDeAlertas`. |

### Backend

| Archivo | Cambio |
|---|---|
| `backend/lib/src/api.dart` | `/salud` con `ahora`; `_conNombre` en `GET/POST/PATCH /alertas` y en `notificarAlerta`. |
| `backend/README.md` | `ahora` en `/salud`; `reportada_por_nombre` en las alertas y en el push. |
| `backend/test/api_test.dart` | Grupos "Salud" y "Nombre de quien reportó". |

### Pruebas (`test/`)

`test/unit/avisos_tardios_test.dart` (nuevo), `test/unit/dominio_test.dart`, `test/unit/repositorios_test.dart`, `test/unit/conexion_test.dart`, `test/unit/persistencia_test.dart`, `test/unit/notificaciones_test.dart`, `test/unit/view_models_test.dart`, `test/widget_test.dart`, `test/accesibilidad_test.dart`, `test/ayudas/falsos.dart` (`AvisosRecibidosFalsos`, `NotificacionesFalsas.tardias`, `ConexionFalsa.desfase`, `alertaDePrueba(reportadaPorNombre:, creadaEn:)`), `test/ayudas/app_de_prueba.dart` (`llegadas:`).

## Trazabilidad

| Requisito | Prueba |
|---|---|
| R1 | `test/unit/avisos_tardios_test.dart` › Clasificación de la demora (R1) › 4:59 y 5:00 de demora llegan a tiempo / 5:01 de demora es tardío / 2 horas exactas es tardío / 2 horas y 1 segundo es demasiado tardío / una demora negativa llega a tiempo |
| R2 | `backend/test/api_test.dart` › Salud › GET /salud devuelve estado ok y la hora del servidor |
| R3 | `test/unit/conexion_test.dart` › ConexionServiceHttp › /salud con ahora mide el desfase en el punto medio del pedido; › /salud sin ahora no cambia el desfase y sigue dando conexión; › ConexionRepositoryRemoto › una comprobación buena guarda el desfase en el teléfono |
| R4 | `test/unit/repositorios_test.dart` › Llegadas de los avisos › la llegada es la hora del teléfono más el desfase guardado; › sin desfase guardado la llegada es la hora del teléfono |
| R5 | `test/unit/repositorios_test.dart` › Llegadas de los avisos › la segunda llegada de la misma alerta conserva la primera; `test/unit/notificaciones_test.dart` › Avisos push con la app cerrada › un push a tiempo se avisa igual que antes (guarda la llegada); › Vigilante de alertas › una alerta nueva a tiempo se avisa igual que antes (guarda la llegada) |
| R6 | `test/unit/repositorios_test.dart` › la segunda llegada de la misma alerta conserva la primera; `test/unit/notificaciones_test.dart` › Avisos push… › si ya había una llegada guardada, clasifica con la primera; › Vigilante… › si el push ya guardó una llegada a tiempo, el vigilante avisa a tiempo |
| R7 | `test/unit/notificaciones_test.dart` › Avisos push… › con los avisos apagados no se guarda la llegada; › Vigilante… › con los avisos apagados no guarda llegadas |
| R8 | `backend/test/api_test.dart` › Nombre de quien reportó › las alertas traen el primer nombre de quien las reportó (las tres rutas); › si el vecino ya no existe, el nombre viene vacío; `test/unit/repositorios_test.dart` › el servidor simulado devuelve el primer nombre de quien reportó |
| R9 | `backend/test/api_test.dart` › Nombre de quien reportó › el push de una alerta nueva trae reportada_por_nombre |
| R10 | `backend/test/api_test.dart` › Nombre de quien reportó › ni la alerta ni el push traen otros datos de quien reportó (conjunto exacto de claves); › reportada_por_nombre no se guarda en el almacén |
| R11 | `test/unit/dominio_test.dart` › JSON › reportada_por_nombre viaja en el JSON; › una alerta sin reportada_por_nombre lo toma vacío; `test/unit/notificaciones_test.dart` › los datos del push traen reportada_por_nombre; `test/unit/persistencia_test.dart` › AlertasDao › la copia local guarda y lee reportada_por_nombre |
| R12 | `test/unit/persistencia_test.dart` › Esquema de la base › migración v3 → v4 agrega reportada_por_nombre sin perder alertas |
| R13 | `test/unit/notificaciones_test.dart` › Avisos push… › un push a tiempo se avisa igual que antes; › Vigilante… › una alerta nueva a tiempo se avisa igual que antes (va por `avisarAlerta`, cuyo título y cuerpo no cambiaron en `NotificacionesServiceLocales`) |
| R14 | `test/unit/avisos_tardios_test.dart` › título "SOS de Marta 15:10"; › el cuerpo es el texto acordado; `test/unit/notificaciones_test.dart` › un push con más de 5 minutos de demora muestra el aviso tardío con título y cuerpo |
| R15 | `test/unit/notificaciones_test.dart` › un push con más de 2 horas de demora no muestra notificación pero guarda la llegada; › Vigilante… › una alerta nueva con 3 horas de demora no se avisa |
| R16 | `test/unit/avisos_tardios_test.dart` › nombre corto de sos, robo, actividad sospechosa, vehículo y ruidos; › arrebato no tiene nombre corto y el título usa el tipo de la alerta ("Arrebato de Marta 15:10"); › título "Robo de Marta 15:10" |
| R17 | `test/unit/avisos_tardios_test.dart` › la hora va con dos dígitos en 24 horas ("09:05", "23:50"); › una alerta de las 23:50 recibida a las 00:30 dice solo "23:50" |
| R18 | `test/unit/avisos_tardios_test.dart` › sin nombre dice "de un vecino" |
| R19 | `test/unit/notificaciones_test.dart` › Vigilante de alertas › una alerta nueva a tiempo se avisa igual que antes; › con 10 minutos de demora se avisa como tardía; › con 3 horas de demora no se avisa |
| R20 | `test/unit/dominio_test.dart` › Marca de alerta tardía › marca de una alerta de hoy; `test/unit/view_models_test.dart` › inicio marca como tardía una alerta con llegada tardía; `test/widget_test.dart` › Alertas tardías › el inicio muestra "Llegó con demora. Alerta de las …" en la tarjeta de una alerta tardía |
| R21 | `test/unit/dominio_test.dart` › Marca de alerta tardía › marca de una alerta de otro día |
| R22 | `test/widget_test.dart` › Alertas tardías › el pin de una alerta tardía tiene el reloj y el resumen muestra la marca |
| R23 | `test/widget_test.dart` › el pin de una alerta tardía tiene el reloj y el resumen muestra la marca; `test/accesibilidad_test.dart` › Resumen de una alerta tardía en el mapa (guías y 200 %) |
| R24 | `test/unit/view_models_test.dart` › detalle carga la marca de su alerta; `test/widget_test.dart` › el detalle de una alerta tardía muestra la marca |
| R25 | `test/unit/view_models_test.dart` › inicio no marca una alerta con llegada a tiempo ni una sin llegada; › mapa expone las marcas por id; `test/widget_test.dart` › una alerta a tiempo no muestra la marca (lista, pin, resumen y detalle) |
| R26 | `test/unit/view_models_test.dart` › una alerta demasiado tardía aparece en el inicio y en el mapa con marca; `test/unit/notificaciones_test.dart` › un push con más de 2 horas… guarda la llegada |
| R27 | `test/widget_test.dart` › la marca tiene ícono de reloj y texto |
| R28 | `test/accesibilidad_test.dart` › Alertas tardías › la etiqueta de la tarjeta y del pin incluyen la marca |
| R29 | `test/accesibilidad_test.dart` › Texto del sistema al 200 % › Inicio con una alerta tardía / Resumen de una alerta tardía en el mapa / Detalle de una alerta tardía, con quién la reportó |
| R30 | `test/accesibilidad_test.dart` › Alertas tardías › los pares de contraste de la marca están registrados; › Colores › Todos los pares de AppColors cumplen el contraste mínimo; › Guías de accesibilidad (textContrastGuideline) en las tres pantallas tardías |
| R31 | `test/widget_test.dart` › la leyenda muestra "Llegó con demora" |
| R32 | `test/unit/view_models_test.dart` › detalle de una alerta ajena con nombre: reportadaPor es el nombre; `test/widget_test.dart` › el detalle de una alerta ajena muestra el nombre de quien la reportó |
| R33 | `test/unit/view_models_test.dart` › detalle de una alerta ajena sin nombre: reportadaPor es "Un vecino"; `test/widget_test.dart` › el detalle de una alerta ajena sin nombre muestra "Un vecino" |
| R34 | `test/unit/view_models_test.dart` › detalle de una alerta propia: reportadaPor es "Vos" aunque traiga nombre; `test/widget_test.dart` › el detalle de una alerta propia muestra "Vos" |
| R35 | `test/accesibilidad_test.dart` › Alertas tardías › el lector lee "Reportada por" y el nombre en una sola etiqueta; › "Reportada por" con nombre al 200 % sin desbordes |

Además: `test/widget_test.dart` › la tarjeta y el resumen del mapa no muestran quién reportó (lo pide T27; acompaña a R32–R35).

## Notas para el reviewer

1. **Pruebas existentes que cambiaron, y por qué.**
   - `test/unit/notificaciones_test.dart`: las pruebas push existentes reciben `avisos: AvisosRecibidosFalsos(ahora: creada)` (llegada a tiempo), como pide T14. El vigilante recibe `avisos`.
   - `test/unit/persistencia_test.dart`: las migraciones v1→ y v2→ armaban la base vieja con `sqlCrearAlertas`, que ahora ya trae `reportada_por_nombre`; el `ALTER TABLE` de la v4 chocaría con la columna. Ahora usan `sqlCrearAlertasHastaV3` (copia del esquema viejo) y `filaHastaV3`. "una base nueva…" espera la versión 4.
   - `test/accesibilidad_test.dart`: el ítem nuevo de la leyenda (R31) ocupa dos líneas al 200 % con la fuente de prueba. En la pantalla de 360 × 800 el mapa baja de unos 198 a 158 dp, el botón SOS tapa casi todos los pines y se pisan entre ellos. La pantalla existente "Resumen de alerta en el mapa" ya no podía tocar el pin de Arrebato con un toque de puntero (caía en el SOS). Ahora los dos resúmenes del mapa se abren con `activarConLector`, la acción "tocar" de la semántica, que es lo que hace un lector de pantalla. `abrirApp`/`ingresar`/`irAPestania` reciben `llegadas` (opcional).
   - `test/unit/view_models_test.dart`: `MapaViewModel` y `DetalleAlertaViewModel` reciben `avisos` en los `crear` existentes.
2. **Riesgo de UX que ya existía y ahora pesa un poco más:** con texto al 200 % en un teléfono bajo, el SOS tapa buena parte del mapa. Los pines se alcanzan moviendo el mapa o con el lector de pantalla. No se cambió el layout porque el design no lo pide; puede valer una feature aparte.
3. **Agregados chicos fuera de la lista de firmas:** el par de contraste "Reloj del pin de una alerta tardía" (`alerta` sobre `superficie`, 3:1) para el distintivo del pin (el design lo dibuja con esos colores). `DetalleAlertaViewModel` sobrescribe `dispose` para no avisar a la vista si `cargarLlegada()` termina con la pantalla ya cerrada. Pruebas extra: "si ya había una llegada guardada, clasifica con la primera" (push), "si el vecino ya no existe, el nombre viene vacío" (backend), "una clave ilegible se lee como sin llegadas" (repositorio), "esTardia…" (dominio).
4. **Capas:** `push_service.dart` (servicio) importa `AvisosRecibidosRepository`, tal como lo pide el design (`procesarAvisoPush(avisos:)` y el handler de segundo plano).
5. **Feature 17:** no se tocó nada de Arrebato (`nombreCorto` devuelve `null` para arrebato y el título usa `tipo`, según R16).
6. Sin `print` ni `debugPrint` nuevos. La prueba temporal de medición que usé para el punto 1 (`test/zz_debug_test.dart`) se borró.

## `./init.sh` completo (resumen)

```
[OK]    Flutter 3.47.5 • channel stable
[OK]    Dart SDK version: 3.13.4 (stable)
[OK]    Existe … (11 archivos base del arnés)
[OK]    feature_list.json válido (17 features)
[OK]    Specs presentes para las features sdd que ya no están en pending
[OK]    flutter pub get
[OK]    dart pub get en backend/
No issues found!
[OK]    flutter analyze sin avisos
No issues found!
[OK]    dart analyze sin avisos en backend/
00:26 +295: All tests passed!
[OK]    Pruebas de la app
00:00 +48: All tests passed!
[OK]    Pruebas del backend
[OK]    Entorno listo. Podés empezar a trabajar.
```

## Prueba manual

No hice prueba manual en emulador. La app completa se recorrió con las pruebas de widgets contra el servidor simulado (inicio, mapa, resumen y detalle con una alerta tardía).
