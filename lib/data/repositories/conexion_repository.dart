import 'dart:async';

import '../services/conexion_service.dart';
import 'avisos_recibidos_repository.dart';

/// Si la app llega a su servidor. Lo comparten el ViewModel de conexión
/// (que comprueba cada tanto) y los repositorios de alertas y turnos (que
/// piden una comprobación apenas un pedido falla por la red).
abstract class ConexionRepository {
  /// null hasta que termina la primera comprobación.
  bool? get hayConexion;

  /// Emite el resultado de cada comprobación que CAMBIA [hayConexion].
  Stream<bool> get cambios;

  /// Comprueba ahora. Si ya hay una comprobación en vuelo, devuelve esa
  /// (no dispara pedidos duplicados).
  Future<bool> comprobar();
}

/// Le pregunta al [ConexionService] y recuerda la última respuesta. Con
/// [avisos], guarda en el teléfono el desfase del reloj que midió el
/// servicio después de cada comprobación buena (R3).
class ConexionRepositoryRemoto implements ConexionRepository {
  ConexionRepositoryRemoto({required this._service, this._avisos});

  final ConexionService _service;
  final AvisosRecibidosRepository? _avisos;
  final StreamController<bool> _cambios = StreamController<bool>.broadcast();
  Future<bool>? _enCurso;

  bool? _hayConexion;
  @override
  bool? get hayConexion => _hayConexion;

  @override
  Stream<bool> get cambios => _cambios.stream;

  @override
  Future<bool> comprobar() {
    return _enCurso ??= _comprobar().whenComplete(() => _enCurso = null);
  }

  Future<bool> _comprobar() async {
    bool hay;
    try {
      hay = await _service.hayConexion();
    } catch (_) {
      // El servicio no debería lanzar; si lo hace, es que no llegó.
      hay = false;
    }
    if (hay) _guardarDesfase();
    final cambio = hay != _hayConexion;
    _hayConexion = hay;
    if (cambio && !_cambios.isClosed) _cambios.add(hay);
    return hay;
  }

  /// Sin `ahora` en la respuesta (servidor viejo) no hay desfase y queda el
  /// último guardado. Si guardar falla, la comprobación no se entera.
  void _guardarDesfase() {
    final avisos = _avisos;
    final desfase = _service.desfase;
    if (avisos == null || desfase == null) return;
    unawaited(avisos.guardarDesfase(desfase).catchError((Object _) {}));
  }

  /// Cierra el stream de [cambios].
  Future<void> cerrar() => _cambios.close();
}
