/// Habla con el servidor sobre la cuenta del vecino.
abstract class VecinosService {
  /// Si las credenciales son correctas devuelve
  /// `{"token": "...", "vecino": {...}}`. El token identifica la sesión en
  /// los pedidos siguientes.
  Future<Map<String, dynamic>> ingresar({
    required String usuario,
    required String clave,
  });

  /// Crea la cuenta y devuelve lo mismo que [ingresar]: el token y el
  /// vecino creado (con su id).
  Future<Map<String, dynamic>> registrar(Map<String, dynamic> datos);

  Future<Map<String, dynamic>> actualizar(
    String id,
    Map<String, dynamic> datos,
  );
}
