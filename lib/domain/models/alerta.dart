import 'package:latlong2/latlong.dart' show LatLng;

/// En qué situación está una alerta.
enum EstadoAlerta {
  activa('activa'),
  enAtencion('en_atencion'),
  resuelta('resuelta');

  const EstadoAlerta(this.valorApi);

  /// Cómo viaja en el JSON de la API.
  final String valorApi;

  static EstadoAlerta desdeApi(String valor) =>
      values.firstWhere((e) => e.valorApi == valor, orElse: () => activa);
}

/// Qué tipo de hecho se reporta.
enum CategoriaAlerta {
  sos('sos'),
  actividadSospechosa('actividad_sospechosa'),
  vehiculo('vehiculo'),
  robo('robo'),

  /// Solo para leer alertas viejas: ya no se puede reportar (no está en
  /// [paraReportar] y el servidor la rechaza al crear).
  arrebato('arrebato'),
  ruidos('ruidos');

  const CategoriaAlerta(this.valorApi);

  final String valorApi;

  /// Los tipos que el vecino puede elegir en "Reportar alerta", en orden.
  static const paraReportar = [actividadSospechosa, vehiculo, robo, ruidos];

  static CategoriaAlerta desdeApi(String valor) =>
      values.firstWhere((c) => c.valorApi == valor, orElse: () => sos);
}

/// Lo que se antepone al título de una alerta SOS para el lector de
/// pantalla. El informe no lo usa: cuenta los SOS en una fila "SOS".
const prefijoSos = 'SOS: ';

class Alerta {
  const Alerta({
    required this.id,
    required this.categoria,
    required this.tipo,
    required this.descripcion,
    required this.direccion,
    required this.creadaEn,
    required this.estado,
    required this.ubicacion,
    required this.reportadaPor,
    this.reportadaPorNombre = '',
  });

  factory Alerta.fromJson(Map<String, dynamic> json) {
    return Alerta(
      id: json['id'] as String,
      categoria: CategoriaAlerta.desdeApi(json['categoria'] as String),
      tipo: json['tipo'] as String,
      descripcion: json['descripcion'] as String,
      direccion: json['direccion'] as String,
      creadaEn: DateTime.fromMillisecondsSinceEpoch(json['creada_en'] as int),
      estado: EstadoAlerta.desdeApi(json['estado'] as String),
      // `as num` acepta tanto -32 como -32.5.
      ubicacion: LatLng(
        (json['latitud'] as num).toDouble(),
        (json['longitud'] as num).toDouble(),
      ),
      reportadaPor: json['reportada_por'] as String,
      reportadaPorNombre: json['reportada_por_nombre'] as String? ?? '',
    );
  }

  /// Fila de la tabla `alertas` -> objeto.
  ///
  /// Las columnas de la tabla tienen los mismos nombres y tipos que el JSON
  /// de la API (la fecha en milisegundos, las coordenadas como REAL), así
  /// que la conversión es la misma.
  factory Alerta.fromMap(Map<String, Object?> fila) => Alerta.fromJson(fila);

  final String id;
  final CategoriaAlerta categoria;

  /// Título corto, por ejemplo "Intento de robo".
  final String tipo;
  final String descripcion;
  final String direccion;
  final DateTime creadaEn;
  final EstadoAlerta estado;

  /// Dónde ocurrió, en coordenadas reales.
  final LatLng ubicacion;

  /// Id del vecino que la reportó.
  final String reportadaPor;

  /// Primer nombre de quien la reportó, para el aviso tardío. '' si el
  /// servidor no lo mandó.
  final String reportadaPorNombre;

  /// "SOS: Intento de robo" si la categoría es sos; el tipo tal cual si no.
  /// Así un SOS y un robo con el mismo título no se escuchan iguales.
  String get tituloConCategoria =>
      categoria == CategoriaAlerta.sos ? '$prefijoSos$tipo' : tipo;

  Map<String, dynamic> toJson() => {
    'id': id,
    'categoria': categoria.valorApi,
    'tipo': tipo,
    'descripcion': descripcion,
    'direccion': direccion,
    'creada_en': creadaEn.millisecondsSinceEpoch,
    'estado': estado.valorApi,
    'latitud': ubicacion.latitude,
    'longitud': ubicacion.longitude,
    'reportada_por': reportadaPor,
    'reportada_por_nombre': reportadaPorNombre,
  };

  /// Objeto -> fila de la tabla `alertas`.
  Map<String, Object?> toMap() => toJson();
}
