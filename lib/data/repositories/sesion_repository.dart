import '../../domain/models/vecino.dart';
import '../services/vecinos_service.dart';

/// Fuente de verdad de la cuenta del vecino que usa la app.
abstract class SesionRepository {
  /// El vecino con la sesión abierta, o null si nadie ingresó.
  Vecino? get usuario;

  Future<Vecino> ingresar({required String usuario, required String clave});

  Future<Vecino> registrar({
    required String nombre,
    required DateTime fechaNacimiento,
    required String telefono,
    required String calle,
    required String cuadra,
    required String codigoComision,
  });

  Future<Vecino> actualizarDatos(Vecino datos);

  Future<void> cerrarSesion();
}

class SesionRepositoryRemoto implements SesionRepository {
  SesionRepositoryRemoto({required this._service});

  final VecinosService _service;
  Vecino? _usuario;

  @override
  Vecino? get usuario => _usuario;

  @override
  Future<Vecino> ingresar({
    required String usuario,
    required String clave,
  }) async {
    final vecino = Vecino.fromJson(
      await _service.ingresar(usuario: usuario, clave: clave),
    );
    _usuario = vecino;
    return vecino;
  }

  @override
  Future<Vecino> registrar({
    required String nombre,
    required DateTime fechaNacimiento,
    required String telefono,
    required String calle,
    required String cuadra,
    required String codigoComision,
  }) async {
    final json = await _service.registrar({
      'nombre': nombre,
      'fecha_nacimiento': fechaNacimiento.toIso8601String().substring(0, 10),
      'telefono': telefono,
      'calle': calle,
      'cuadra': cuadra,
      'codigo_comision': codigoComision,
    });
    final vecino = Vecino.fromJson(json);
    _usuario = vecino;
    return vecino;
  }

  @override
  Future<Vecino> actualizarDatos(Vecino datos) async {
    final json = Map<String, dynamic>.of(datos.toJson())..remove('id');
    final vecino = Vecino.fromJson(await _service.actualizar(datos.id, json));
    _usuario = vecino;
    return vecino;
  }

  @override
  Future<void> cerrarSesion() async {
    _usuario = null;
  }
}
