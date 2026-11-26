# Design — informe_alertas

> Decisiones técnicas tomadas antes de escribir código. Se apoya en
> `docs/architecture.md` y `docs/conventions.md`; acá solo va lo que esta
> feature agrega o donde roza sus límites.

## Archivos a crear o cambiar

| Capa | Archivo | Cambio |
|---|---|---|
| domain | `lib/domain/informe_alertas.dart` | Crear `FilaInforme`, `FranjaInforme` e `InformeAlertas` con el cálculo puro por mes (por calle, por tipo y por franja horaria) y generación de CSV (`toCsv()` y `nombreArchivoCsv`). |
| data | `lib/data/services/descarga_csv_service.dart` | Crear `DescargaCsvService` (abstracta) y `DescargaCsvServiceLocal` para guardar el archivo `.csv` en el dispositivo sin paquetes externos. |
| armado | `lib/dependencias.dart` | Inyectar `DescargaCsvService descargaCsv` en `Dependencias`, `Dependencias.simuladas` y `Dependencias.conApi`. |
| ui (perfil) | `lib/ui/perfil/view_models/perfil_view_model.dart` | Agregar getter `bool get esComision => usuario?.esComision ?? false;`. |
| ui (perfil) | `lib/ui/perfil/widgets/perfil_screen.dart` | Mostrar el `ListTile` `"Informe mensual de alertas"` solo si `viewModel.esComision` es `true` y navegar a `InformeAlertasScreen`. |
| ui (informe) | `lib/ui/informe_alertas/view_models/informe_alertas_view_model.dart` | Crear `InformeAlertasViewModel` (`ChangeNotifier`): carga alertas desde `AlertasRepository`, cambia de mes (`mesAnterior`, `mesSiguiente`, `elegirMes`), escucha `AlertasActualizadas`, expone `InformeAlertas` y descarga el CSV con `descargarCsv()`. |
| ui (informe) | `lib/ui/informe_alertas/widgets/informe_alertas_screen.dart` | Crear `InformeAlertasScreen` y sus widgets privados (`_SelectorMesInforme`, `_ContenidoInforme`, `_TablaInforme`, `_InformeVacio`), incluyendo el botón `"Descargar informe (CSV)"` en meses con alertas. |
| pruebas | `test/ayudas/falsos.dart`, `test/ayudas/app_de_prueba.dart` | Agregar `DescargaCsvFalsa implements DescargaCsvService` e inyectarla en `appDePrueba`. |
| pruebas | `test/unit/dominio_test.dart` | Pruebas unitarias de `InformeAlertas.delMes`, `toCsv()` y `nombreArchivoCsv`. |
| pruebas | `test/unit/view_models_test.dart` | Pruebas unitarias de `InformeAlertasViewModel` (carga inicial, cambio de mes, mes sin alertas, actualización por bus, error de carga y descarga de CSV exitosa/fallida) y de `PerfilViewModel.esComision`. |
| pruebas | `test/widget_test.dart`, `test/accesibilidad_test.dart` | Pruebas de widgets (visibilidad en perfil según rol `comision` vs `vecino`, tablas del informe, descarga de CSV con botón y estado vacío sin botón de descarga) y pruebas de accesibilidad (48 dp, etiquetas, contraste y texto al 200 %). |

## Firmas nuevas

### En `lib/domain/informe_alertas.dart`

```dart
import 'fechas.dart';
import 'models/alerta.dart';

/// Franjas del día para clasificar a qué hora ocurren las alertas.
enum FranjaInforme {
  madrugada('Madrugada (00:00 - 06:00)'),
  maniana('Mañana (06:00 - 12:00)'),
  tarde('Tarde (12:00 - 20:00)'),
  noche('Noche (20:00 - 00:00)');

  const FranjaInforme(this.etiqueta);

  final String etiqueta;

  static FranjaInforme deHora(int hora) {
    if (hora < 6) return FranjaInforme.madrugada;
    if (hora < 12) return FranjaInforme.maniana;
    if (hora < 20) return FranjaInforme.tarde;
    return FranjaInforme.noche;
  }
}

/// Un renglón de una tabla del informe (nombre de la calle, tipo o franja y
/// cuántas alertas tuvo en el mes).
class FilaInforme {
  const FilaInforme({required this.nombre, required this.cantidad});

  final String nombre;
  final int cantidad;
}

/// Resumen mensual de alertas para presentar al municipio.
class InformeAlertas {
  const InformeAlertas({
    required this.mes,
    required this.total,
    required this.porCalle,
    required this.porTipo,
    required this.porFranja,
  });

  /// Calcula el informe para el año y mes de [mes] a partir de [alertas].
  factory InformeAlertas.delMes({
    required List<Alerta> alertas,
    required DateTime mes,
  });

  final DateTime mes;
  final int total;
  final List<FilaInforme> porCalle;
  final List<FilaInforme> porTipo;
  final List<FilaInforme> porFranja;

  bool get sinAlertas => total == 0;

  /// Nombre sugerido para el archivo, por ejemplo `informe_alertas_2026_10.csv`.
  String get nombreArchivoCsv;

  /// Contenido del informe en formato CSV (con encabezado `Sección,Detalle,Cantidad`
  /// y escape de comas/comillas según RFC 4180).
  String toCsv();
}
```

### En `lib/data/services/descarga_csv_service.dart`

```dart
/// Guarda en el dispositivo un archivo CSV generado por la app.
abstract class DescargaCsvService {
  /// Guarda [contenido] bajo [nombreArchivo] y devuelve la ruta o nombre
  /// donde quedó guardado, o null si no se pudo guardar.
  Future<String?> guardarCsv({
    required String nombreArchivo,
    required String contenido,
  });
}

/// Guarda el archivo CSV en la carpeta de descargas de Android (si existe)
/// o en la carpeta temporal del sistema, con BOM UTF-8 para que las
/// planillas de cálculo abran bien los acentos.
class DescargaCsvServiceLocal implements DescargaCsvService {
  const DescargaCsvServiceLocal({this.carpetaDestino});

  final Directory? carpetaDestino;
  ...
}
```

### En `lib/ui/informe_alertas/view_models/informe_alertas_view_model.dart`

```dart
class InformeAlertasViewModel extends ChangeNotifier {
  InformeAlertasViewModel({
    required AlertasRepository alertas,
    required BusDeEventos bus,
    required Reloj reloj,
    DescargaCsvService descargaCsv = const DescargaCsvServiceLocal(),
    DateTime? mesInicial,
  });

  EstadoCarga get estado;
  bool get sinConexion;
  DateTime get mes;
  InformeAlertas get informe;

  Future<void> cargar();
  void elegirMes(DateTime nuevoMes);
  void mesAnterior();
  void mesSiguiente();

  /// Genera y guarda el archivo CSV del mes actual y devuelve el mensaje
  /// para mostrarle al miembro de la comisión.
  Future<String> descargarCsv();
}
```

## API y datos

- **Rutas nuevas o cambiadas:** Ninguna. El informe y su exportación CSV se calculan en el dominio de la app a partir de las alertas provistas por `AlertasRepository.obtenerAlertas()`.
  - Esto permite consultar y descargar el CSV también **sin conexión** (usando la copia local en `sqflite`), y cambiar de mes sin latencia de red.
- **Formato del archivo CSV (`InformeAlertas.toCsv()`):**
  ```csv
  Sección,Detalle,Cantidad
  Resumen,Total del mes,5
  Por calle,Calle Plantamura,2
  Por tipo,Intento de robo,1
  Por franja horaria,Noche (20:00 - 00:00),3
  ```
  Si un detalle contiene comas o comillas dobles, se encierra entre comillas dobles duplicando las comillas internas (`"` → `""`).
- **Cambios en el JSON de los modelos y en sqflite:** Ninguno.

## Plataforma

- `DescargaCsvServiceLocal` escribe el archivo en el sistema de archivos local (`dart:io`, intentando `/storage/emulated/0/Download` en Android si existe y es escribible, con respaldo en `Directory.systemTemp`). En pruebas se inyecta `DescargaCsvFalsa` (o un directorio temporal).

## Accesibilidad

- **Objetivos táctiles (≥ 48 x 48 dp):** Los botones `'Mes anterior'`, `'Mes siguiente'` y `'Descargar informe (CSV)'` miden al menos 48 x 48 dp.
- **Lectores de pantalla:** Cada sección del informe (`'Por calle'`, `'Por tipo de alerta'`, `'Por franja horaria'`) usa `Semantics(header: true, ...)` y los botones de cambio de mes tienen `tooltip` descriptivo.
- **Texto al 200 %:** Las filas de cada tabla y el botón de descarga usan layouts flexibles (`Expanded` / `Wrap`) sin desbordes horizontales con `escalaTexto: 2.0`.
- **Estado sin depender solo del color:** Las cantidades se muestran con números explícitos y encabezados textuales.
- Se agrega la pantalla `'Informe de alertas'` a la lista `pantallas` de `test/accesibilidad_test.dart`.

## Paquetes nuevos

Ninguno (`dart:io` y `package:path/path.dart` ya están disponibles en el proyecto).

## Alternativa descartada

**Calcular el informe y el CSV únicamente en un endpoint del backend (`GET /comision/informes/alertas.csv`) sin lógica en el dominio de la app.**
Se descarta porque impediría ver y descargar el informe cuando el miembro de la comisión no tiene señal (a pesar de tener la copia de alertas en `AlertasDao`) y porque el criterio de aceptación de `feature_list.json` exige pruebas unitarias del cálculo del informe, del ViewModel y de la pantalla en la app.

## Riesgos y notas

- En un mes sin alertas (`informe.sinAlertas == true`), la pantalla muestra el aviso de mes vacío y oculta tanto las tablas como el botón `"Descargar informe (CSV)"` (R8, R12) para no descargar archivos vacíos.
