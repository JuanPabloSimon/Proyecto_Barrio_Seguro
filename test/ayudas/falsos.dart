import 'package:BarrioSeguro/data/repositories/alertas_repository.dart';
import 'package:BarrioSeguro/data/repositories/sesion_repository.dart';
import 'package:BarrioSeguro/data/repositories/turnos_repository.dart';
import 'package:BarrioSeguro/data/services/alertas_service.dart';
import 'package:BarrioSeguro/data/services/telefono_service.dart';
import 'package:BarrioSeguro/data/services/ubicacion_service.dart';
import 'package:BarrioSeguro/domain/models/alerta.dart';
import 'package:BarrioSeguro/domain/models/turno.dart';
import 'package:BarrioSeguro/domain/models/vecino.dart';
import 'package:BarrioSeguro/plataforma/capacidades.dart';
import 'package:BarrioSeguro/plataforma/politicas.dart';
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
}) {
  return Alerta(
    id: id,
    categoria: CategoriaAlerta.robo,
    tipo: 'Intento de robo',
    descripcion: 'Prueba',
    direccion: 'Calle de prueba',
    creadaEn: DateTime(2026, 10, 1, 11, 55),
    estado: estado,
    ubicacion: const LatLng(-32.8765, -68.8706),
    reportadaPor: reportadaPor,
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

/// Cumple el contrato de Capacidades, pero cada respuesta la decide la
/// prueba. Un campo final alcanza para implementar un getter.
class CapacidadesFalsas implements Capacidades {
  const CapacidadesFalsas({
    this.puedeHacerLlamadas = true,
    this.recibeNotificacionesPush = true,
    this.tieneBaseDeDatosLocal = false,
    this.tieneGps = true,
  });

  @override
  final bool puedeHacerLlamadas;

  @override
  final bool recibeNotificacionesPush;

  @override
  final bool tieneBaseDeDatosLocal;

  @override
  final bool tieneGps;
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
