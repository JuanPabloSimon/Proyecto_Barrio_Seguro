import '../alertas_service.dart';
import 'cliente_api.dart';

class AlertasServiceHttp implements AlertasService {
  AlertasServiceHttp(this._api);

  final ClienteApi _api;

  @override
  Future<List<Map<String, dynamic>>> obtenerAlertas() async {
    final lista = await _api.get('/alertas') as List<dynamic>;
    return lista.cast<Map<String, dynamic>>();
  }

  @override
  Future<Map<String, dynamic>> crearAlerta(Map<String, dynamic> datos) async =>
      await _api.post('/alertas', datos) as Map<String, dynamic>;

  @override
  Future<Map<String, dynamic>> cambiarEstado(String id, String estado) async =>
      await _api.patch('/alertas/$id', {'estado': estado})
          as Map<String, dynamic>;
}
