import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../error_del_servidor.dart';
import '../local/almacen_seguro.dart';

/// Habla con la API por HTTP: arma las direcciones, agrega el token de la
/// sesión, convierte el JSON y traduce los errores.
///
/// - Si la API responde con un error (400, 401, 403, 404, 409), lanza
///   [ErrorDelServidor] con el mensaje que manda la API, para mostrarlo tal
///   cual.
/// - Si no hay conexión o la API tarda demasiado, deja pasar la excepción
///   de red: los repositorios la usan para mostrar la copia guardada.
class ClienteApi {
  ClienteApi({
    required this.base,
    required this._almacen,
    http.Client? cliente,
    this.espera = const Duration(seconds: 10),
  }) : _cliente = cliente ?? http.Client();

  /// Por ejemplo `http://10.0.2.2:8080` (la PC vista desde el emulador).
  final Uri base;
  final AlmacenSeguro _almacen;
  final http.Client _cliente;

  /// Cuánto se espera una respuesta antes de darla por perdida.
  final Duration espera;

  Future<dynamic> get(String ruta, {Map<String, String>? parametros}) =>
      _pedir('GET', ruta, parametros: parametros);

  Future<dynamic> post(String ruta, [Object? cuerpo]) =>
      _pedir('POST', ruta, cuerpo: cuerpo);

  Future<dynamic> put(String ruta, [Object? cuerpo]) =>
      _pedir('PUT', ruta, cuerpo: cuerpo);

  Future<dynamic> patch(String ruta, [Object? cuerpo]) =>
      _pedir('PATCH', ruta, cuerpo: cuerpo);

  Future<dynamic> delete(String ruta) => _pedir('DELETE', ruta);

  Future<dynamic> _pedir(
    String metodo,
    String ruta, {
    Map<String, String>? parametros,
    Object? cuerpo,
  }) async {
    // Sin la barra final de la base: "…:8080/" + "/alertas".
    final prefijo = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    final pedido = http.Request(
      metodo,
      base.replace(path: '$prefijo$ruta', queryParameters: parametros),
    )..headers['accept'] = 'application/json';

    final token = await _almacen.token();
    if (token != null) pedido.headers['authorization'] = 'Bearer $token';
    if (cuerpo != null) {
      pedido.headers['content-type'] = 'application/json; charset=utf-8';
      pedido.body = jsonEncode(cuerpo);
    }

    final respuesta = await http.Response.fromStream(
      await _cliente.send(pedido).timeout(espera),
    ).timeout(espera);

    final texto = utf8.decode(respuesta.bodyBytes);
    final datos = texto.isEmpty ? null : jsonDecode(texto);

    if (respuesta.statusCode >= 400) {
      final mensaje = datos is Map<String, dynamic> && datos['error'] is String
          ? datos['error'] as String
          : 'Algo salió mal en el servidor. Probá de nuevo en un rato.';
      throw ErrorDelServidor(mensaje);
    }
    return datos;
  }
}
