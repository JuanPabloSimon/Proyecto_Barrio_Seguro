# Review — feature 16 (avisos_tardios)

**Veredicto:** APPROVED

Revisé el trabajo sin commitear de la rama `feature/avisos_tardios` (`git status`, `git diff` y los archivos nuevos `lib/domain/avisos_tardios.dart`, `lib/data/repositories/avisos_recibidos_repository.dart`, `lib/ui/core/widgets/marca_tardia.dart`, `test/unit/avisos_tardios_test.dart`) contra el spec aprobado en 4c86698.

## Trazabilidad

- R1: [x] `test/unit/avisos_tardios_test.dart` › Clasificación de la demora (R1) › 4:59 y 5:00 de demora llegan a tiempo / 5:01 de demora es tardío / 2 horas exactas es tardío / 2 horas y 1 segundo es demasiado tardío / una demora negativa llega a tiempo
- R2: [x] `backend/test/api_test.dart` › Salud › GET /salud devuelve estado ok y la hora del servidor (sin token; cuerpo exacto con estado y ahora)
- R3: [x] `test/unit/conexion_test.dart` › /salud con ahora mide el desfase en el punto medio del pedido (reloj 12:00:00 y 12:00:02, servidor 12:10:01, desfase de 10 min) · /salud sin ahora no cambia el desfase y sigue dando conexión · ConexionRepositoryRemoto › una comprobación buena guarda el desfase en el teléfono (sin conexión o sin desfase no lo pisa)
- R4: [x] `test/unit/repositorios_test.dart` › Llegadas de los avisos › la llegada es la hora del teléfono más el desfase guardado (desfase de -3 min, contra `Preferencias` reales en memoria) · sin desfase guardado la llegada es la hora del teléfono
- R5: [x] `test/unit/notificaciones_test.dart` › un push a tiempo se avisa igual que antes (guarda la llegada) · Vigilante › una alerta nueva a tiempo se avisa igual que antes (guarda la llegada); `repositorios_test.dart` › la segunda llegada de la misma alerta conserva la primera
- R6: [x] `test/unit/repositorios_test.dart` › la segunda llegada de la misma alerta conserva la primera (otra instancia, una hora después) · `notificaciones_test.dart` › si ya había una llegada guardada, clasifica con la primera · si el push ya guardó una llegada a tiempo, el vigilante avisa a tiempo
- R7: [x] `test/unit/notificaciones_test.dart` › con los avisos apagados no se guarda la llegada (push) · con los avisos apagados no guarda llegadas (vigilante)
- R8: [x] `backend/test/api_test.dart` › las alertas traen el primer nombre de quien las reportó (GET, POST y PATCH) · si el vecino ya no existe, el nombre viene vacío; `repositorios_test.dart` › el servidor simulado devuelve el primer nombre de quien reportó
- R9: [x] `backend/test/api_test.dart` › el push de una alerta nueva trae reportada_por_nombre
- R10: [x] `backend/test/api_test.dart` › ni la alerta ni el push traen otros datos de quien reportó (conjunto exacto de claves en POST, push, GET y PATCH) · reportada_por_nombre no se guarda en el almacén (y un cambio de nombre se ve en la próxima lectura)
- R11: [x] `test/unit/dominio_test.dart` › reportada_por_nombre viaja en el JSON · una alerta sin reportada_por_nombre lo toma vacío (si falta y si es null); `notificaciones_test.dart` › los datos del push traen reportada_por_nombre; `persistencia_test.dart` › la copia local guarda y lee reportada_por_nombre
- R12: [x] `test/unit/persistencia_test.dart` › migración v3 → v4 agrega reportada_por_nombre sin perder alertas (base v3 con el esquema viejo y 2 alertas; `PRAGMA table_info`, versión 4 y guarda el nombre después de migrar)
- R13: [x] `test/unit/notificaciones_test.dart` › un push a tiempo se avisa igual que antes (5:00 exactos van por `avisarAlerta`, no por `avisarAlertaTardia`) · Vigilante › una alerta nueva a tiempo se avisa igual que antes. El título y el cuerpo de `avisarAlerta` en `lib/data/services/notificaciones_service.dart:103-110` son los de antes (solo pasó a usar `_mostrar`, con el mismo id y payload).
- R14: [x] `test/unit/avisos_tardios_test.dart` › título "SOS de Marta 15:10" · el cuerpo es el texto acordado; `notificaciones_test.dart` › un push con más de 5 minutos de demora muestra el aviso tardío con título y cuerpo (5:01 va por `avisarAlertaTardia`, título "SOS de Marta 12:00"). `NotificacionesServiceLocales.avisarAlertaTardia` (`notificaciones_service.dart:113-117`) usa `tituloAvisoTardio` y `cuerpoAvisoTardio`; el plugin no se puede inyectar, así que esa unión se verifica leyendo el código, como preveía T15.
- R15: [x] `test/unit/notificaciones_test.dart` › un push con más de 2 horas de demora no muestra notificación pero guarda la llegada · Vigilante › una alerta nueva con 3 horas de demora no se avisa
- R16: [x] `test/unit/avisos_tardios_test.dart` › nombre corto de sos, robo, actividad sospechosa, vehículo y ruidos · arrebato no tiene nombre corto y el título usa el tipo de la alerta ("Arrebato de Marta 15:10") · título "Robo de Marta 15:10" (con tipo "Intento de robo": usa el nombre corto y no el tipo)
- R17: [x] `test/unit/avisos_tardios_test.dart` › la hora va con dos dígitos en 24 horas ("09:05", "23:50", "00:00") · una alerta de las 23:50 recibida a las 00:30 dice solo "23:50"
- R18: [x] `test/unit/avisos_tardios_test.dart` › sin nombre dice "de un vecino"
- R19: [x] `test/unit/notificaciones_test.dart` › Vigilante › una alerta nueva a tiempo se avisa igual que antes / con 10 minutos de demora se avisa como tardía ("Robo de Jorge 11:55") / con 3 horas de demora no se avisa (y publica `AlertasActualizadas`)
- R20: [x] `test/unit/dominio_test.dart` › marca de una alerta de hoy; `view_models_test.dart` › inicio marca como tardía una alerta con llegada tardía; `widget_test.dart` › el inicio muestra "Llegó con demora. Alerta de las …" en la tarjeta de una alerta tardía
- R21: [x] `test/unit/dominio_test.dart` › marca de una alerta de otro día: "Llegó con demora. Alerta del 24/11 a las 23:50" (también otro año con el mismo día y mes)
- R22: [x] `test/widget_test.dart` › el pin de una alerta tardía tiene el reloj y el resumen muestra la marca (reloj en el pin de a3 y no en el de a2)
- R23: [x] `test/widget_test.dart` › el pin de una alerta tardía tiene el reloj y el resumen muestra la marca (marca dentro del `BottomSheet`)
- R24: [x] `test/unit/view_models_test.dart` › detalle carga la marca de su alerta; `widget_test.dart` › el detalle de una alerta tardía muestra la marca
- R25: [x] `test/unit/view_models_test.dart` › inicio no marca una alerta con llegada a tiempo ni una sin llegada · mapa expone las marcas por id; `widget_test.dart` › una alerta a tiempo no muestra la marca (lista, pin, resumen y detalle)
- R26: [x] `test/unit/view_models_test.dart` › una alerta demasiado tardía aparece en el inicio y en el mapa con marca; `notificaciones_test.dart` › un push con más de 2 horas de demora no muestra notificación pero guarda la llegada
- R27: [x] `test/widget_test.dart` › la marca tiene ícono de reloj y texto
- R28: [x] `test/accesibilidad_test.dart` › Alertas tardías › la etiqueta de la tarjeta y del pin incluyen la marca (etiquetas exactas; la de una alerta a tiempo no la lleva)
- R29: [x] `test/accesibilidad_test.dart` › Texto del sistema al 200 % › Inicio con una alerta tardía / Resumen de una alerta tardía en el mapa / Detalle de una alerta tardía, con quién la reportó
- R30: [x] `test/accesibilidad_test.dart` › los pares de contraste de la marca están registrados (colores y mínimos exactos) · Colores › Todos los pares de AppColors cumplen el contraste mínimo · `textContrastGuideline` en las tres pantallas tardías
- R31: [x] `test/widget_test.dart` › la leyenda muestra "Llegó con demora" (con `PinAlerta(tardia: true)` en el mismo ítem)
- R32: [x] `test/unit/view_models_test.dart` › detalle de una alerta ajena con nombre: reportadaPor es el nombre; `widget_test.dart` › el detalle de una alerta ajena muestra el nombre de quien la reportó ("Pedro", y ya no "Un vecino de la zona")
- R33: [x] `test/unit/view_models_test.dart` › detalle de una alerta ajena sin nombre: reportadaPor es "Un vecino"; `widget_test.dart` › el detalle de una alerta ajena sin nombre muestra "Un vecino"
- R34: [x] `test/unit/view_models_test.dart` › detalle de una alerta propia: reportadaPor es "Vos" aunque traiga nombre; `widget_test.dart` › el detalle de una alerta propia muestra "Vos"
- R35: [x] `test/accesibilidad_test.dart` › el lector lee "Reportada por" y el nombre en una sola etiqueta (mismo nodo de semántica) · "Reportada por" con nombre al 200 % sin desbordes

## Tasks

- T1–T35: [x] todas marcadas en `specs/avisos_tardios/tasks.md`, y cada prueba que nombran T2, T4, T6, T9, T11, T13, T15, T16, T18, T20, T22, T27, T28, T30 y T32 existe con ese nombre.

## Arquitectura y convenciones

- [x] Umbrales en `lib/domain/avisos_tardios.dart:8-11`: hasta 5 min inclusive es a tiempo y hasta 2 h inclusive es tardío, en Dart puro. Una demora negativa da a tiempo.
- [x] El desfase se aplica donde corresponde: `ConexionServiceHttp` (`lib/data/services/http/conexion_service_http.dart:36-47`) lo mide contra el punto medio del pedido con el `Reloj` inyectado, y `AvisosRecibidosRepositoryLocal.registrarLlegada` (`lib/data/repositories/avisos_recibidos_repository.dart:35-38`) lo suma a la hora del teléfono. Así la llegada queda en hora del servidor y se compara con `creada_en`, que también es del servidor. El push y el vigilante pasan por el mismo `registrarLlegada`.
- [x] Un SOS a tiempo sigue yendo por `avisarAlerta`, con el mismo título, cuerpo, id y payload (`notificaciones_service.dart:103-110`, `push_service.dart:116-119`, `vigilante_de_alertas.dart:121-124`).
- [x] Backend: `_conNombre` (`backend/lib/src/api.dart:281-294`) arma una copia con solo el primer nombre. Se usa en GET, POST (también para `notificarAlerta`) y PATCH, y el almacén no lo guarda. `/salud` suma `ahora` y la app sigue pidiendo solo `estado == "ok"`, así que es compatible para los dos lados.
- [x] Migración de sqflite de v3 a v4: `versionDelEsquema = 4`, la columna con valor por defecto vacío en `sqlCrearAlertas` y el `ALTER TABLE` en `anterior < 4` (`lib/data/services/local/base_de_datos.dart:76-82`). Las pruebas de v1 y v2 ahora arman el esquema viejo (`sqlCrearAlertasHastaV3`), que es igual al de la v3 commiteada.
- [x] Todo se arma en `lib/dependencias.dart:181-190` y llega por constructor (`avisos` a `ConexionRepositoryRemoto`, a `Dependencias`, a los ViewModels y al vigilante). `conApi` le pasa el `reloj` a `ConexionServiceHttp`. El isolate del push arma sus piezas sin estado global (`push_service.dart:28-38`).
- [x] Los ViewModels no reciben `BuildContext` ni importan widgets. Las pantallas solo leen `viewModel.tardia(s)` y `viewModel.reportadaPor`. No hay `Platform.isX` y no hizo falta tocar `Capacidades` ni `Politicas`.
- [x] Accesibilidad: `MarcaTardia` lleva el reloj (en `ExcludeSemantics`) y el texto en un `Flexible`. El pin se distingue por la forma del distintivo. Las etiquetas de la tarjeta y del pin incluyen la marca. "Reportada por" va en `MergeSemantics`. Los pares están en `AppColors.paresDeContraste` y hay tres pantallas nuevas en las guías y al 200 %.
- [x] No se tocaron reglas de turnos. No hay paquetes nuevos (`pubspec.yaml`, `backend/pubspec.yaml` y sus `.lock` sin cambios).
- [x] La feature 17 `quitar_arrebato` no se tocó: `feature_list.json` no cambió, no existe `specs/quitar_arrebato/` y de Arrebato solo está lo que pide R16 (`nombreCorto` da `null` y el título usa `tipo`).
- [x] `dart format --set-exit-if-changed` no cambia nada en `lib/`, `test/`, `backend/lib/` ni `backend/test/`. Los textos están en español y no hay `print`.

### Observaciones (no bloquean)

1. `test/accesibilidad_test.dart:175-178`: la pantalla que ya existía, "Resumen de alerta en el mapa", pasó de un toque de puntero a `activarConLector`. El motivo está documentado: el ítem nuevo de la leyenda (R31) achica el mapa al 200 % en 360 × 800 y el SOS tapa el pin de Arrebato. Es un riesgo de uso real para personas mayores con letra grande. Los pines se siguen alcanzando moviendo el mapa o con el lector, pero conviene que el leader lo lleve al equipo como una feature aparte (el layout del mapa con texto grande).
2. `lib/data/services/push_service.dart:115` y `lib/ui/principal/vigilante_de_alertas.dart:106-110`: si `registrarLlegada` falla (una escritura en preferencias), no se muestra ningún aviso, tampoco un SOS a tiempo. En el vigilante, además, la alerta ya quedó en `_conocidas` y no se vuelve a intentar. Ya pasaba lo mismo si fallaba la lectura de `notificaciones()`, y una falla de `SharedPreferencesAsync` es muy rara. Igual se podría avisar como a tiempo cuando no se puede guardar la llegada.
3. `lib/data/services/push_service.dart:9` importa un repositorio desde la capa de servicios, al revés de `ui → repositories → services`. Lo pide el design aprobado (`procesarAvisoPush(avisos:)`). Si se repite, conviene anotarlo en `docs/architecture.md`.
4. `lib/ui/alerta_detalle/view_models/detalle_alerta_view_model.dart:78`: `_cerrado` no nombra el booleano como pregunta (sería `_estaCerrado`). Es menor.

## Checkpoints

- C1: [x] Están los archivos del arnés y `./init.sh` sale con 0.
- C2: [x] Hay una sola feature en `in_progress` (la 16), las `done` tienen pruebas en verde y `progress/current.md` describe la sesión activa.
- C3: [x] Se respetan las capas (salvo la excepción que autoriza el design, ver la observación 3). Los ViewModels no reciben `BuildContext`, todo se arma en `lib/dependencias.dart`, no hay `Platform.isX`, no hay paquetes nuevos y no se tocaron reglas de turnos.
- C4: [x] `flutter analyze` y `dart analyze` sin avisos. Pasan las 295 pruebas de la app y las 48 del backend. El repositorio y los ViewModels nuevos se prueban con los falsos de `test/ayudas/falsos.dart`, con `RelojFijo` y sin internet.
- C5: [x] Objetivos de 48 dp (guías en las tres pantallas nuevas), etiquetas, texto al 200 % sin desbordes y la marca con ícono y texto, no solo con color.
- C6: [x] No quedan temporales (`test/zz_debug_test.dart` ya no existe) ni `print`. `progress/history.md` tiene la entrada de la última sesión cerrada (feature 15); la de esta sesión la escribe el leader al cerrar. La feature sigue en `in_progress`.
- C7: [x] `specs/avisos_tardios/` tiene los tres archivos en EARS, T1–T35 están en `[x]` y cada R1 a R35 tiene una prueba concreta.

## Salida de init.sh

```
[OK]    feature_list.json válido (17 features)
[OK]    Specs presentes para las features sdd que ya no están en pending
[OK]    flutter pub get
[OK]    dart pub get en backend/
No issues found! (ran in 3.1s)
[OK]    flutter analyze sin avisos
No issues found!
[OK]    dart analyze sin avisos en backend/
00:26 +295: All tests passed!
[OK]    Pruebas de la app
00:00 +48: All tests passed!
[OK]    Pruebas del backend
[OK]    Entorno listo. Podés empezar a trabajar.
```

## Cambios requeridos

Ninguno. Falta commitear el trabajo de la rama (el spec ya está commiteado en 4c86698) y que el leader lleve las observaciones 1 y 2 al equipo.
