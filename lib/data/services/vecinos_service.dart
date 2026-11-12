/// Habla con el servidor sobre la cuenta del vecino.
abstract class VecinosService {
  /// Devuelve los datos del vecino si las credenciales son correctas.
  Future<Map<String, dynamic>> ingresar({
    required String usuario,
    required String clave,
  });

  /// Crea la cuenta y devuelve el vecino creado (con su id).
  Future<Map<String, dynamic>> registrar(Map<String, dynamic> datos);

  Future<Map<String, dynamic>> actualizar(
    String id,
    Map<String, dynamic> datos,
  );
}
