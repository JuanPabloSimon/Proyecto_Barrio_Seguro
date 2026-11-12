import '../vecinos_service.dart';
import 'servidor_simulado.dart';

class VecinosServiceSimulado implements VecinosService {
  VecinosServiceSimulado(this._servidor);

  final ServidorSimulado _servidor;

  @override
  Future<Map<String, dynamic>> ingresar({
    required String usuario,
    required String clave,
  }) async {
    await _servidor.responder();
    return _servidor.ingresar(usuario, clave);
  }

  @override
  Future<Map<String, dynamic>> registrar(Map<String, dynamic> datos) async {
    await _servidor.responder();
    return _servidor.registrar(datos);
  }

  @override
  Future<Map<String, dynamic>> actualizar(
    String id,
    Map<String, dynamic> datos,
  ) async {
    await _servidor.responder();
    return _servidor.actualizarVecino(id, datos);
  }

  @override
  Future<void> cerrarSesion() async {}
}
