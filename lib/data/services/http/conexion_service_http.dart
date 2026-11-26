import 'dart:async';

import '../conexion_service.dart';
import 'cliente_api.dart';

/// Comprueba la conexión con `GET /salud`, que responde `{"estado": "ok"}`.
///
/// Cualquier otra cosa da sin conexión: un error de red, una respuesta que
/// tarda más que [espera], un código de error o un cuerpo distinto (por
/// ejemplo, la página HTML de un wifi con portal de acceso).
class ConexionServiceHttp implements ConexionService {
  ConexionServiceHttp(this._api, {this.espera = const Duration(seconds: 5)});

  final ClienteApi _api;

  /// Cuánto se espera la respuesta de `/salud` antes de darla por perdida.
  final Duration espera;

  @override
  Future<bool> hayConexion() async {
    try {
      final datos = await _api.get('/salud').timeout(espera);
      return datos is Map && datos['estado'] == 'ok';
    } catch (_) {
      return false;
    }
  }
}
