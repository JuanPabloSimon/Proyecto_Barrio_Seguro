import '../alertas_service.dart';
import 'servidor_simulado.dart';

class AlertasServiceSimulado implements AlertasService {
  AlertasServiceSimulado(this._servidor);

  final ServidorSimulado _servidor;

  @override
  Future<List<Map<String, dynamic>>> obtenerAlertas() async {
    await _servidor.responder();
    return _servidor.alertas();
  }

  @override
  Future<Map<String, dynamic>> crearAlerta(Map<String, dynamic> datos) async {
    await _servidor.responder();
    return _servidor.crearAlerta(datos);
  }

  @override
  Future<Map<String, dynamic>> cambiarEstado(String id, String estado) async {
    await _servidor.responder();
    return _servidor.cambiarEstadoDeAlerta(id, estado);
  }
}
