import '../turnos_service.dart';
import 'cliente_api.dart';

class TurnosServiceHttp implements TurnosService {
  TurnosServiceHttp(this._api);

  final ClienteApi _api;

  @override
  Future<List<Map<String, dynamic>>> obtenerTurnos({
    required int anio,
    required int mes,
  }) async {
    final lista = await _api.get(
      '/turnos',
      parametros: {'anio': '$anio', 'mes': '$mes'},
    ) as List<dynamic>;
    return lista.cast<Map<String, dynamic>>();
  }

  @override
  Future<Map<String, dynamic>> anotarse({
    required String fecha,
    required String franja,
    required String vecinoId,
  }) async =>
      await _api.put('/turnos/$fecha/$franja/vecinos/$vecinoId')
          as Map<String, dynamic>;

  @override
  Future<Map<String, dynamic>> salir({
    required String fecha,
    required String franja,
    required String vecinoId,
  }) async =>
      await _api.delete('/turnos/$fecha/$franja/vecinos/$vecinoId')
          as Map<String, dynamic>;
}
