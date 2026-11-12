import '../vecinos_service.dart';
import 'cliente_api.dart';

class VecinosServiceHttp implements VecinosService {
  VecinosServiceHttp(this._api);

  final ClienteApi _api;

  @override
  Future<Map<String, dynamic>> ingresar({
    required String usuario,
    required String clave,
  }) async =>
      await _api.post('/sesiones', {'usuario': usuario, 'clave': clave})
          as Map<String, dynamic>;

  @override
  Future<Map<String, dynamic>> registrar(Map<String, dynamic> datos) async =>
      await _api.post('/vecinos', datos) as Map<String, dynamic>;

  @override
  Future<Map<String, dynamic>> actualizar(
    String id,
    Map<String, dynamic> datos,
  ) async => await _api.put('/vecinos/$id', datos) as Map<String, dynamic>;

  @override
  Future<void> cerrarSesion() => _api.delete('/sesiones');
}
