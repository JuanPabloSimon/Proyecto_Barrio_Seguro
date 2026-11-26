import 'dart:async';

import '../conexion_service.dart';
import '../reloj.dart';
import 'cliente_api.dart';

/// Comprueba la conexión con `GET /salud`, que responde
/// `{"estado": "ok", "ahora": <milisegundos del servidor>}`.
///
/// Cualquier otra cosa da sin conexión: un error de red, una respuesta que
/// tarda más que [espera], un código de error o un cuerpo distinto (por
/// ejemplo, la página HTML de un wifi con portal de acceso). Para dar
/// conexión alcanza con `estado == "ok"`: un servidor sin `ahora` no rompe
/// nada, solo no mide el desfase.
class ConexionServiceHttp implements ConexionService {
  ConexionServiceHttp(
    this._api, {
    this.espera = const Duration(seconds: 5),
    this._reloj = const RelojDelSistema(),
  });

  final ClienteApi _api;
  final Reloj _reloj;

  /// Cuánto se espera la respuesta de `/salud` antes de darla por perdida.
  final Duration espera;

  Duration? _desfase;
  @override
  Duration? get desfase => _desfase;

  @override
  Future<bool> hayConexion() async {
    try {
      final antes = _reloj.ahora().millisecondsSinceEpoch;
      final datos = await _api.get('/salud').timeout(espera);
      final despues = _reloj.ahora().millisecondsSinceEpoch;
      if (datos is! Map || datos['estado'] != 'ok') return false;

      // R3: el desfase se mide contra el punto medio del pedido; el error es
      // como mucho la mitad del viaje.
      final ahora = datos['ahora'];
      if (ahora is num) {
        final medio = antes + (despues - antes) ~/ 2;
        _desfase = Duration(milliseconds: ahora.toInt() - medio);
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
