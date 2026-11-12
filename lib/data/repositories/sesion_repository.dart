import '../../domain/models/vecino.dart';
import '../services/local/almacen_seguro.dart';
import '../services/local/preferencias.dart';
import '../services/vecinos_service.dart';

/// Fuente de verdad de la cuenta del vecino que usa la app.
abstract class SesionRepository {
  /// El vecino con la sesión abierta, o null si nadie ingresó.
  Vecino? get usuario;

  /// Recupera la sesión guardada en el teléfono, si la hay. Se llama una
  /// vez al abrir la app, antes de mostrar la primera pantalla.
  Future<void> restaurar();

  Future<Vecino> ingresar({required String usuario, required String clave});

  Future<Vecino> registrar({
    required String nombre,
    required DateTime fechaNacimiento,
    required String telefono,
    required String calle,
    required String cuadra,
    required String codigoComision,
    required String clave,
  });

  Future<Vecino> actualizarDatos(Vecino datos);

  Future<void> cerrarSesion();
}

/// Guarda el token en el almacenamiento seguro (es un secreto) y los datos
/// del vecino en preferencias, para abrir la app ya ingresado aunque no
/// haya conexión.
class SesionRepositoryRemoto implements SesionRepository {
  SesionRepositoryRemoto({
    required this._service,
    required this._preferencias,
    required this._almacen,
  });

  final VecinosService _service;
  final Preferencias _preferencias;
  final AlmacenSeguro _almacen;
  Vecino? _usuario;

  @override
  Vecino? get usuario => _usuario;

  @override
  Future<void> restaurar() async {
    try {
      final token = await _almacen.token();
      _usuario = token == null ? null : await _preferencias.vecino();
    } catch (_) {
      // Si no se puede leer, se arranca sin sesión: el vecino ingresa de
      // nuevo.
      _usuario = null;
    }
  }

  /// Guarda la sesión que devolvió el servidor (`{"token", "vecino"}`).
  Future<Vecino> _abrirSesion(Map<String, dynamic> respuesta) async {
    final vecino = Vecino.fromJson(respuesta['vecino'] as Map<String, dynamic>);
    await _almacen.guardarToken(respuesta['token'] as String);
    await _preferencias.guardarVecino(vecino);
    _usuario = vecino;
    return vecino;
  }

  @override
  Future<Vecino> ingresar({
    required String usuario,
    required String clave,
  }) async {
    return _abrirSesion(
      await _service.ingresar(usuario: usuario, clave: clave),
    );
  }

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
    final respuesta = await _service.registrar({
      'nombre': nombre,
      'fecha_nacimiento': fechaNacimiento.toIso8601String().substring(0, 10),
      'telefono': telefono,
      'calle': calle,
      'cuadra': cuadra,
      'codigo_comision': codigoComision,
      'clave': clave,
    });
    return _abrirSesion(respuesta);
  }

  @override
  Future<Vecino> actualizarDatos(Vecino datos) async {
    final json = Map<String, dynamic>.of(datos.toJson())..remove('id');
    final vecino = Vecino.fromJson(await _service.actualizar(datos.id, json));
    await _preferencias.guardarVecino(vecino);
    _usuario = vecino;
    return vecino;
  }

  @override
  Future<void> cerrarSesion() async {
    // Si no hay conexión, igual se cierra en el teléfono.
    try {
      await _service.cerrarSesion();
    } catch (_) {}
    _usuario = null;
    await _almacen.borrarToken();
    await _preferencias.olvidarVecino();
  }
}
