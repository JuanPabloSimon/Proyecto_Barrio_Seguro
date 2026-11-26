import 'dart:async';

import 'package:barrio_seguro/data/repositories/alertas_repository.dart';
import 'package:barrio_seguro/data/repositories/avisos_recibidos_repository.dart';
import 'package:barrio_seguro/data/repositories/conexion_repository.dart';
import 'package:barrio_seguro/data/repositories/sesion_repository.dart';
import 'package:barrio_seguro/data/repositories/turnos_repository.dart';
import 'package:barrio_seguro/data/services/alertas_service.dart';
import 'package:barrio_seguro/data/services/conexion_service.dart';
import 'package:barrio_seguro/data/services/local/alertas_dao.dart';
import 'package:barrio_seguro/data/services/local/turnos_dao.dart';
import 'package:barrio_seguro/data/services/descarga_csv_service.dart';
import 'package:barrio_seguro/data/services/notificaciones_service.dart';
import 'package:barrio_seguro/data/services/push_service.dart';
import 'package:barrio_seguro/data/services/telefono_service.dart';
import 'package:barrio_seguro/data/services/ubicacion_service.dart';
import 'package:barrio_seguro/domain/models/alerta.dart';
import 'package:barrio_seguro/domain/models/turno.dart';
import 'package:barrio_seguro/domain/models/vecino.dart';
import 'package:barrio_seguro/plataforma/capacidades.dart';
import 'package:barrio_seguro/plataforma/politicas.dart';
import 'package:latlong2/latlong.dart';

/// Repositorios y servicios falsos para probar ViewModels sin servidor.

final vecinaDePrueba = Vecino(
  id: 'clara',
  nombre: 'Clara Medina',
  fechaNacimiento: DateTime(1981, 5, 14),
);

final vecinoMayor = Vecino(
  id: 'rosa',
  nombre: 'Rosa Ibáñez',
  fechaNacimiento: DateTime(1948, 7, 8),
);

Alerta alertaDePrueba({
  String id = 'a1',
  EstadoAlerta estado = EstadoAlerta.activa,
  String reportadaPor = 'clara',
  String reportadaPorNombre = '',
  DateTime? creadaEn,
}) {
  return Alerta(
    id: id,
    categoria: CategoriaAlerta.robo,
    tipo: 'Intento de robo',
    descripcion: 'Prueba',
    direccion: 'Calle de prueba',
    creadaEn: creadaEn ?? DateTime(2026, 10, 1, 11, 55),
    estado: estado,
    ubicacion: const LatLng(-32.8765, -68.8706),
    reportadaPor: reportadaPor,
    reportadaPorNombre: reportadaPorNombre,
  );
}

class SesionFalsa implements SesionRepository {
  SesionFalsa([this.usuario]);

  @override
  Vecino? usuario;

  @override
  Future<void> restaurar() async {}

  @override
  Future<Vecino> ingresar({
    required String usuario,
    required String clave,
  }) async => this.usuario = vecinaDePrueba;

  @override
  Future<Vecino> registrar({
    required String nombre,
    required DateTime fechaNacimiento,
    required String telefono,
    required String calle,
    required String cuadra,
    required String codigoComision,
    required String clave,
  }) async {
    return usuario = Vecino(
      id: 'nuevo',
      nombre: nombre,
      fechaNacimiento: fechaNacimiento,
    );
  }

  @override
  Future<Vecino> actualizarDatos(Vecino datos) async => usuario = datos;

  @override
  Future<void> cerrarSesion() async => usuario = null;
}

/// Guarda alertas en una lista. Con [falla] en true, todo tira error.
class AlertasFalsas implements AlertasRepository {
  AlertasFalsas([List<Alerta>? iniciales, this.falla = false])
    : alertas = [...?iniciales];

  final List<Alerta> alertas;
  bool falla;
  int pedidos = 0;

  /// Dónde se mandó cada alerta creada, en orden.
  final List<LatLng> ubicacionesEnviadas = [];

  @override
  bool sinConexion = false;

  void _quizasFallar() {
    if (falla) throw Exception('sin conexión');
  }

  @override
  Future<List<Alerta>> obtenerAlertas({bool refrescar = false}) async {
    pedidos++;
    _quizasFallar();
    return List.unmodifiable(alertas);
  }

  @override
  Future<Alerta> crearAlerta({
    required CategoriaAlerta categoria,
    required String tipo,
    required String descripcion,
    required String direccion,
    required LatLng ubicacion,
    required String reportadaPor,
  }) async {
    _quizasFallar();
    ubicacionesEnviadas.add(ubicacion);
    final alerta = alertaDePrueba(
      id: 'nueva-${alertas.length}',
      reportadaPor: reportadaPor,
    );
    alertas.insert(0, alerta);
    return alerta;
  }

  @override
  Future<Alerta> cambiarEstado(String id, EstadoAlerta estado) async {
    _quizasFallar();
    final i = alertas.indexWhere((a) => a.id == id);
    final actualizada = alertaDePrueba(
      id: id,
      estado: estado,
      reportadaPor: alertas[i].reportadaPor,
    );
    alertas[i] = actualizada;
    return actualizada;
  }
}

/// Turnos en memoria, sin reglas: las reglas las prueba el ViewModel.
class TurnosFalsos implements TurnosRepository {
  TurnosFalsos([List<Turno>? iniciales]) : turnos = [...?iniciales];

  final List<Turno> turnos;
  bool falla = false;

  @override
  bool sinConexion = false;

  @override
  Future<List<Turno>> obtenerTurnos(
    DateTime mes, {
    bool refrescar = false,
  }) async {
    if (falla) throw Exception('sin conexión');
    return List.unmodifiable(turnos);
  }

  @override
  Future<Turno> anotarse(Vecino vecino, DateTime fecha, Franja franja) async {
    if (falla) throw Exception('sin conexión');
    final turno = Turno(fecha: fecha, franja: franja, patrulleros: [vecino]);
    turnos.add(turno);
    return turno;
  }

  @override
  Future<Turno> salir(Vecino vecino, DateTime fecha, Franja franja) async {
    turnos.removeWhere((t) => t.fecha == fecha && t.franja == franja);
    return Turno(fecha: fecha, franja: franja);
  }
}

/// Servicio que cuenta cuántas veces se le pidió algo, para probar la caché.
/// Con [falla] en true, simula que no hay conexión.
class AlertasServiceContador implements AlertasService {
  int pedidos = 0;
  bool falla = false;

  @override
  Future<List<Map<String, dynamic>>> obtenerAlertas() async {
    pedidos++;
    if (falla) throw Exception('sin conexión');
    return [alertaDePrueba().toJson()];
  }

  @override
  Future<Map<String, dynamic>> crearAlerta(Map<String, dynamic> datos) async =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> cambiarEstado(String id, String estado) async =>
      throw UnimplementedError();
}

/// Servicio de alertas que siempre falla con [error]: un error de red
/// (SocketException) o una respuesta de error de la API (ErrorDelServidor).
class AlertasServiceQueFalla implements AlertasService {
  AlertasServiceQueFalla(this.error);

  final Object error;

  @override
  Future<List<Map<String, dynamic>>> obtenerAlertas() async => throw error;

  @override
  Future<Map<String, dynamic>> crearAlerta(Map<String, dynamic> datos) async =>
      throw error;

  @override
  Future<Map<String, dynamic>> cambiarEstado(String id, String estado) async =>
      throw error;
}

/// Cumple el contrato de Capacidades, pero cada respuesta la decide la
/// prueba. Un campo final alcanza para implementar un getter.
class CapacidadesFalsas implements Capacidades {
  const CapacidadesFalsas({
    this.puedeHacerLlamadas = true,
    this.muestraNotificaciones = true,
    this.tieneBaseDeDatosLocal = false,
    this.tieneGps = true,
    this.recibeAvisosPush = true,
  });

  @override
  final bool puedeHacerLlamadas;

  @override
  final bool muestraNotificaciones;

  @override
  final bool tieneBaseDeDatosLocal;

  @override
  final bool tieneGps;

  @override
  final bool recibeAvisosPush;
}

class PoliticasFalsas implements Politicas {
  const PoliticasFalsas({this.exigeAvisoAntesDeUbicacion = true});

  @override
  final bool exigeAvisoAntesDeUbicacion;
}

/// Anota los números que se marcaron en vez de abrir el teléfono.
class TelefonoFalso implements TelefonoService {
  TelefonoFalso({this.abre = true});

  final bool abre;
  final List<String> marcados = [];

  @override
  Future<bool> abrirMarcador(String numero) async {
    marcados.add(numero);
    return abre;
  }
}

/// El GPS de prueba: la prueba decide qué responde el permiso y dónde
/// "está" el teléfono.
class UbicacionFalsa implements UbicacionService {
  UbicacionFalsa({
    this.permiso = PermisoUbicacion.concedido,
    this.posicion = const LatLng(-32.8771, -68.8699),
  });

  PermisoUbicacion permiso;

  /// null: el GPS no responde a tiempo.
  LatLng? posicion;

  int permisosPedidos = 0;
  int posicionesPedidas = 0;
  int ajustesAbiertos = 0;

  @override
  Future<PermisoUbicacion> pedirPermiso() async {
    permisosPedidos++;
    return permiso;
  }

  @override
  Future<LatLng?> ubicacionActual() async {
    posicionesPedidas++;
    return posicion;
  }

  @override
  Future<void> abrirAjustes() async => ajustesAbiertos++;
}

/// Anota los avisos en vez de mostrarlos. [permiso] decide qué responde
/// el sistema cuando se pide.
class NotificacionesFalsas implements NotificacionesService {
  NotificacionesFalsas({this.permiso = true, this.abrioLaApp});

  bool permiso;
  final String? abrioLaApp;
  final List<Alerta> avisadas = [];
  final _tocadas = StreamController<String>.broadcast();

  /// Simula que el vecino tocó el aviso de la alerta [id].
  void tocar(String id) => _tocadas.add(id);

  @override
  Future<void> inicializar() async {}

  @override
  Future<bool> pedirPermiso() async => permiso;

  @override
  Future<void> avisarAlerta(Alerta alerta) async => avisadas.add(alerta);

  /// Las alertas que se avisaron como tardías, en orden.
  final List<Alerta> tardias = [];

  @override
  Future<void> avisarAlertaTardia(Alerta alerta) async => tardias.add(alerta);

  @override
  Stream<String> get alertasTocadas => _tocadas.stream;

  @override
  Future<String?> alertaQueAbrioLaApp() async => abrioLaApp;
}

/// Simula el servicio de avisos push (FCM) sin red ni Firebase.
class PushFalso implements PushService {
  PushFalso({this.abrioLaApp, this.falla = false});

  final String? abrioLaApp;
  bool falla;
  bool inicializado = false;
  bool suscripto = false;
  int suscripciones = 0;
  int desuscripciones = 0;
  final _tocadas = StreamController<String>.broadcast();

  /// Simula que el vecino tocó el aviso push de la alerta [id].
  void tocar(String id) => _tocadas.add(id);

  void _revisar() {
    if (falla) throw Exception('fallo de push');
  }

  @override
  Future<void> inicializar() async {
    _revisar();
    inicializado = true;
  }

  @override
  Future<void> suscribirAlertas() async {
    _revisar();
    suscripto = true;
    suscripciones++;
  }

  @override
  Future<void> desuscribirAlertas() async {
    _revisar();
    suscripto = false;
    desuscripciones++;
  }

  @override
  Stream<String> get alertasTocadas => _tocadas.stream;

  @override
  Future<String?> alertaQueAbrioLaApp() async => abrioLaApp;
}

/// El `GET /salud` de prueba: responde [hay] y cuenta las [comprobaciones].
/// Con [demora], la respuesta tarda ese tiempo (para probar pedidos en
/// vuelo).
class ConexionFalsa implements ConexionService {
  ConexionFalsa({this.hay = true, this.demora = Duration.zero, this.desfase});

  bool hay;
  Duration demora;
  int comprobaciones = 0;

  @override
  Duration? desfase;

  @override
  Future<bool> hayConexion() async {
    comprobaciones++;
    if (demora > Duration.zero) await Future<void>.delayed(demora);
    return hay;
  }
}

/// Repositorio de conexión en memoria: [comprobar] responde [hay], cuenta
/// las [comprobaciones] y emite en [cambios] cuando el resultado cambia.
class ConexionRepositoryFalsa implements ConexionRepository {
  ConexionRepositoryFalsa({this.hay = true});

  bool hay;
  int comprobaciones = 0;
  final _cambios = StreamController<bool>.broadcast();

  @override
  bool? hayConexion;

  @override
  Stream<bool> get cambios => _cambios.stream;

  /// Si alguien sigue escuchando [cambios] (para probar `dispose`).
  bool get tieneOyentes => _cambios.hasListener;

  @override
  Future<bool> comprobar() async {
    comprobaciones++;
    final cambio = hay != hayConexion;
    hayConexion = hay;
    if (cambio) _cambios.add(hay);
    return hay;
  }
}

/// Copia local de alertas en memoria, para las pruebas de widgets: SQLite
/// hace I/O real, que no avanza con el tiempo falso de testWidgets.
class AlertasDaoEnMemoria implements AlertasDao {
  AlertasDaoEnMemoria([List<Alerta>? iniciales]) : guardadas = [...?iniciales];

  final List<Alerta> guardadas;

  @override
  Future<List<Alerta>> listar() async => List.unmodifiable(guardadas);

  @override
  Future<void> reemplazarTodas(List<Alerta> alertas) async {
    guardadas
      ..clear()
      ..addAll(alertas);
  }

  @override
  Future<void> guardar(Alerta alerta) async {
    guardadas
      ..removeWhere((a) => a.id == alerta.id)
      ..insert(0, alerta);
  }
}

/// Copia local de turnos en memoria (ver [AlertasDaoEnMemoria]).
class TurnosDaoEnMemoria implements TurnosDao {
  TurnosDaoEnMemoria([List<Turno>? iniciales]) : guardados = [...?iniciales];

  final List<Turno> guardados;

  bool _delMes(Turno t, DateTime mes) =>
      t.fecha.year == mes.year && t.fecha.month == mes.month;

  @override
  Future<List<Turno>> delMes(DateTime mes) async =>
      List.unmodifiable(guardados.where((t) => _delMes(t, mes)));

  @override
  Future<void> reemplazarMes(DateTime mes, List<Turno> turnos) async {
    guardados
      ..removeWhere((t) => _delMes(t, mes))
      ..addAll(turnos);
  }

  @override
  Future<void> guardar(Turno turno) async {
    guardados
      ..removeWhere((t) => t.fecha == turno.fecha && t.franja == turno.franja)
      ..add(turno);
  }
}

/// Guarda en memoria los archivos CSV que la app pidió descargar.
class DescargaCsvFalsa implements DescargaCsvService {
  DescargaCsvFalsa({this.falla = false});

  bool falla;
  String? ultimoNombre;
  String? ultimoContenido;
  int descargas = 0;

  @override
  Future<String?> guardarCsv({
    required String nombreArchivo,
    required String contenido,
  }) async {
    if (falla) return null;
    descargas++;
    ultimoNombre = nombreArchivo;
    ultimoContenido = contenido;
    return '/descargas/$nombreArchivo';
  }
}

/// Llegadas de avisos en memoria. [registrarLlegada] guarda [ahora] (ya en
/// hora del servidor) si la alerta no tenía llegada. Con [falla] en true,
/// leer las llegadas tira error.
class AvisosRecibidosFalsos implements AvisosRecibidosRepository {
  AvisosRecibidosFalsos({
    DateTime? ahora,
    Map<String, DateTime>? iniciales,
    this.falla = false,
  }) : ahora = ahora ?? DateTime(2026, 10, 1, 12),
       guardadas = {...?iniciales};

  /// La hora (del servidor) en que "llega" el próximo aviso.
  DateTime ahora;
  final Map<String, DateTime> guardadas;
  bool falla;

  /// El último desfase que se pidió guardar.
  Duration? desfase;

  @override
  Future<DateTime> registrarLlegada(String alertaId) async =>
      guardadas.putIfAbsent(alertaId, () => ahora);

  @override
  Future<Map<String, DateTime>> llegadas() async {
    if (falla) throw Exception('no se pudo leer');
    return Map.unmodifiable(guardadas);
  }

  @override
  Future<void> guardarDesfase(Duration desfase) async => this.desfase = desfase;
}
