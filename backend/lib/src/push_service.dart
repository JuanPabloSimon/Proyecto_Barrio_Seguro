import 'dart:convert';
import 'dart:io';

import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

/// Envía avisos push cuando un vecino reporta una alerta nueva.
abstract class PushService {
  /// Envía el aviso de [alerta] si no está resuelta.
  Future<void> enviarAlerta(Map<String, dynamic> alerta);
}

/// No envía nada. Se usa cuando el servidor corre sin credenciales de
/// Firebase o en las pruebas que no evalúan avisos push.
class PushServiceNinguno implements PushService {
  const PushServiceNinguno();

  @override
  Future<void> enviarAlerta(Map<String, dynamic> alerta) async {}
}

/// Envía mensajes de datos al tópico `alertas` mediante la API HTTP v1 de
/// Firebase Cloud Messaging.
class PushServiceFcm implements PushService {
  PushServiceFcm({required this.projectId, required this._obtenerCliente});

  /// Crea el servicio usando un [cliente] HTTP ya preparado (útil en pruebas
  /// con `MockClient`).
  factory PushServiceFcm.conCliente({
    required String projectId,
    required http.Client cliente,
  }) {
    return PushServiceFcm(
      projectId: projectId,
      obtenerCliente: () async => cliente,
    );
  }

  /// Crea el servicio a partir del archivo JSON de una cuenta de servicio
  /// de Firebase.
  factory PushServiceFcm.desdeArchivo(File archivo) {
    final json = jsonDecode(archivo.readAsStringSync()) as Map<String, dynamic>;
    final projectId = json['project_id'];
    if (projectId is! String || projectId.isEmpty) {
      throw const FormatException(
        'El archivo de Firebase no tiene project_id.',
      );
    }
    final credenciales = ServiceAccountCredentials.fromJson(json);
    Future<http.Client>? clienteAutenticado;
    return PushServiceFcm(
      projectId: projectId,
      obtenerCliente: () => clienteAutenticado ??= clientViaServiceAccount(
        credenciales,
        const ['https://www.googleapis.com/auth/firebase.messaging'],
      ),
    );
  }

  final String projectId;
  final Future<http.Client> Function() _obtenerCliente;

  static const topicoAlertas = 'alertas';

  @override
  Future<void> enviarAlerta(Map<String, dynamic> alerta) async {
    if (alerta['estado'] == 'resuelta') return;

    final cliente = await _obtenerCliente();
    final url = Uri.parse(
      'https://fcm.googleapis.com/v1/projects/$projectId/messages:send',
    );
    final respuesta = await cliente.post(
      url,
      headers: {'content-type': 'application/json; charset=utf-8'},
      body: jsonEncode({
        'message': {
          'topic': topicoAlertas,
          'data': {
            for (final MapEntry(:key, :value) in alerta.entries)
              if (value != null) key: '$value',
          },
          'android': {'priority': 'HIGH'},
        },
      }),
    );
    if (respuesta.statusCode < 200 || respuesta.statusCode >= 300) {
      throw HttpException(
        'Error de FCM (${respuesta.statusCode}): ${respuesta.body}',
        uri: url,
      );
    }
  }
}
