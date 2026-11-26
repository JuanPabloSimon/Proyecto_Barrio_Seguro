import 'dart:convert';
import 'dart:io';

import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

/// Envía avisos push de una alerta nueva o reabierta.
abstract class PushService {
  /// Envía el aviso de [alerta] si no está resuelta.
  Future<void> enviarAlerta(Map<String, dynamic> alerta);

  /// Aviso de una alerta resuelta que se volvió a abrir. [alerta] ya trae
  /// el estado nuevo; si está resuelta, no envía nada. [reabiertaEn] es la
  /// hora del servidor del cambio.
  Future<void> enviarReapertura(
    Map<String, dynamic> alerta, {
    required DateTime reabiertaEn,
  });
}

/// No envía nada. Se usa cuando el servidor corre sin credenciales de
/// Firebase o en las pruebas que no evalúan avisos push.
class PushServiceNinguno implements PushService {
  const PushServiceNinguno();

  @override
  Future<void> enviarAlerta(Map<String, dynamic> alerta) async {}

  @override
  Future<void> enviarReapertura(
    Map<String, dynamic> alerta, {
    required DateTime reabiertaEn,
  }) async {}
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

  /// Valor de la clave `aviso` en el aviso de una alerta reabierta. El de
  /// una alerta nueva no lleva `aviso`.
  static const avisoReabierta = 'reabierta';

  @override
  Future<void> enviarAlerta(Map<String, dynamic> alerta) async {
    if (alerta['estado'] == 'resuelta') return;
    await _enviar(_comoTexto(alerta));
  }

  /// Las mismas claves que [enviarAlerta] más `aviso: "reabierta"` y
  /// `reabierta_en` (ms). No viaja quién la reabrió (R45).
  @override
  Future<void> enviarReapertura(
    Map<String, dynamic> alerta, {
    required DateTime reabiertaEn,
  }) async {
    if (alerta['estado'] == 'resuelta') return;
    await _enviar({
      ..._comoTexto(alerta),
      'aviso': avisoReabierta,
      'reabierta_en': '${reabiertaEn.millisecondsSinceEpoch}',
    });
  }

  /// FCM solo acepta textos en `data`.
  Map<String, String> _comoTexto(Map<String, dynamic> alerta) => {
    for (final MapEntry(:key, :value) in alerta.entries)
      if (value != null) key: '$value',
  };

  /// Manda un mensaje de datos al tópico de alertas.
  Future<void> _enviar(Map<String, String> datos) async {
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
          'data': datos,
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
