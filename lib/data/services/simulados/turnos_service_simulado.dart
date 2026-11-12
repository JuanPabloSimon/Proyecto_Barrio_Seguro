import '../turnos_service.dart';
import 'servidor_simulado.dart';

class TurnosServiceSimulado implements TurnosService {
  TurnosServiceSimulado(this._servidor);

  final ServidorSimulado _servidor;

  @override
  Future<List<Map<String, dynamic>>> obtenerTurnos({
    required int anio,
    required int mes,
  }) async {
    await _servidor.responder();
    return _servidor.turnosDelMes(anio, mes);
  }

  @override
  Future<Map<String, dynamic>> anotarse({
    required String fecha,
    required String franja,
    required String vecinoId,
  }) async {
    await _servidor.responder();
    return _servidor.anotarse(fecha, franja, vecinoId);
  }

  @override
  Future<Map<String, dynamic>> salir({
    required String fecha,
    required String franja,
    required String vecinoId,
  }) async {
    await _servidor.responder();
    return _servidor.salir(fecha, franja, vecinoId);
  }
}
