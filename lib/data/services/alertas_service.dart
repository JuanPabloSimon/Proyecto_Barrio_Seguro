/// Habla con el servidor sobre las alertas. Devuelve el JSON tal como llega,
/// sin convertirlo: eso lo hace el repositorio.
abstract class AlertasService {
  Future<List<Map<String, dynamic>>> obtenerAlertas();

  /// Crea una alerta y devuelve la alerta creada (con id y fecha).
  Future<Map<String, dynamic>> crearAlerta(Map<String, dynamic> datos);

  Future<Map<String, dynamic>> cambiarEstado(String id, String estado);
}
