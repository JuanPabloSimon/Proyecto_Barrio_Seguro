/// Un error que se le devuelve a la app con un código HTTP y un mensaje
/// pensado para mostrarle al vecino tal cual.
class ErrorDeApi implements Exception {
  const ErrorDeApi(this.codigo, this.mensaje);

  /// 400 datos inválidos, 401 sin sesión, 403 no permitido, 404 no existe,
  /// 409 choca con una regla (por ejemplo, el máximo de turnos).
  final int codigo;
  final String mensaje;

  const ErrorDeApi.datosInvalidos(String mensaje) : this(400, mensaje);
  const ErrorDeApi.sinSesion()
    : this(401, 'Tu sesión venció. Ingresá de nuevo.');
  const ErrorDeApi.noPermitido(String mensaje) : this(403, mensaje);
  const ErrorDeApi.noExiste(String mensaje) : this(404, mensaje);
  const ErrorDeApi.conflicto(String mensaje) : this(409, mensaje);

  @override
  String toString() => 'ErrorDeApi($codigo): $mensaje';
}
