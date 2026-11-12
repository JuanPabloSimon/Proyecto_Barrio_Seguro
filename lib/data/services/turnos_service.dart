/// Habla con el servidor sobre los turnos de patrullaje.
abstract class TurnosService {
  Future<List<Map<String, dynamic>>> obtenerTurnos({
    required int anio,
    required int mes,
  });

  /// Anota al vecino y devuelve el turno actualizado.
  Future<Map<String, dynamic>> anotarse({
    required String fecha,
    required String franja,
    required String vecinoId,
  });

  /// Saca al vecino del turno y devuelve el turno actualizado.
  Future<Map<String, dynamic>> salir({
    required String fecha,
    required String franja,
    required String vecinoId,
  });
}
