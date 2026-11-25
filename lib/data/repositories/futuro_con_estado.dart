/// En qué punto del ciclo de vida está una operación asíncrona ([Future]) en
/// un repositorio o servicio.
enum EstadoFuturo {
  /// Todavía no se inició ningún pedido.
  inicial,

  /// Hay un [Future] en vuelo esperando respuesta.
  cargando,

  /// El último [Future] se completó y dejó un [valor] válido.
  exito,

  /// El último [Future] falló con un [error].
  error,
}

/// Envuelve un [Future] manteniendo explícitamente su estado ([estado]), la
/// promesa en vuelo ([enCurso]), el último resultado exitoso ([valor]) y el
/// último fallo ([error]).
///
/// - Si se llama a [ejecutar] mientras el estado es [EstadoFuturo.cargando] y
///   no se pide [refrescar], devuelve el **mismo [Future] en vuelo** para no
///   disparar pedidos duplicados al servidor.
/// - Si el estado es [EstadoFuturo.exito] y no se pide [refrescar], devuelve
///   el [valor] en caché.
class FuturoConEstado<T> {
  EstadoFuturo _estado = EstadoFuturo.inicial;

  /// Estado actual del [Future].
  EstadoFuturo get estado => _estado;

  /// True mientras hay un [Future] esperando respuesta.
  bool get cargando => _estado == EstadoFuturo.cargando;

  /// El [Future] que está corriendo ahora mismo, o null si no hay ninguno en
  /// vuelo.
  Future<T>? get enCurso => _enCurso;
  Future<T>? _enCurso;

  /// Último resultado exitoso guardado en caché.
  T? get valor => _valor;
  T? _valor;

  /// Último error capturado cuando [estado] es [EstadoFuturo.error].
  Object? get error => _error;
  Object? _error;

  /// Ejecuta [operacion] o reutiliza el [Future] en vuelo / [valor] en caché
  /// según el [estado] actual.
  Future<T> ejecutar(Future<T> Function() operacion, {bool refrescar = false}) {
    final valorActual = _valor;
    if (!refrescar && _estado == EstadoFuturo.exito && valorActual != null) {
      return Future<T>.value(valorActual);
    }
    final activo = _enCurso;
    if (!refrescar && _estado == EstadoFuturo.cargando && activo != null) {
      return activo;
    }

    _estado = EstadoFuturo.cargando;
    _error = null;
    late final Future<T> pedido;
    pedido = operacion().then(
      (resultado) {
        if (identical(_enCurso, pedido)) {
          _valor = resultado;
          _estado = EstadoFuturo.exito;
          _enCurso = null;
        }
        return resultado;
      },
      onError: (Object e, StackTrace traza) {
        if (identical(_enCurso, pedido)) {
          _error = e;
          _estado = EstadoFuturo.error;
          _enCurso = null;
        }
        Error.throwWithStackTrace(e, traza);
      },
    );
    _enCurso = pedido;
    return pedido;
  }

  /// Actualiza el valor en caché y deja el estado en [EstadoFuturo.exito].
  void fijarValor(T nuevoValor) {
    _valor = nuevoValor;
    _error = null;
    _enCurso = null;
    _estado = EstadoFuturo.exito;
  }

  /// Limpia la caché y vuelve el estado a [EstadoFuturo.inicial].
  void limpiar() {
    _valor = null;
    _error = null;
    _enCurso = null;
    _estado = EstadoFuturo.inicial;
  }
}
