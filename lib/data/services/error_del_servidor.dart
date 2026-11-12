/// El servidor respondió, pero rechazó el pedido (por ejemplo, porque no
/// se cumple una regla). [mensaje] se puede mostrar tal cual al usuario.
class ErrorDelServidor implements Exception {
  const ErrorDelServidor(this.mensaje);

  final String mensaje;

  @override
  String toString() => 'ErrorDelServidor: $mensaje';
}
