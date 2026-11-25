import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/alerta.dart';
import 'local/preferencias.dart';
import 'notificaciones_service.dart';

/// Tópico de Firebase Cloud Messaging al que se suscriben los teléfonos del
/// barrio para recibir alertas nuevas con la app cerrada.
const topicoAlertasPush = 'alertas';

/// Callback de nivel superior que Android ejecuta en un isolate propio
/// cuando llega un mensaje de datos de FCM con la app cerrada o en segundo
/// plano.
@pragma('vm:entry-point')
Future<void> manejarMensajePushEnSegundoPlano(RemoteMessage mensaje) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  final notificaciones = NotificacionesServiceLocales();
  await notificaciones.inicializar();
  await procesarAvisoPush(
    mensaje.data,
    preferencias: Preferencias(SharedPreferencesAsync()),
    notificaciones: notificaciones,
  );
}

/// Convierte el mapa `data` de un mensaje push en una [Alerta], o devuelve
/// null si faltan datos obligatorios o no tienen formato válido.
Alerta? alertaDesdeDatosPush(Map<String, dynamic> datos) {
  final id = datos['id'];
  final categoria = datos['categoria'];
  final tipo = datos['tipo'];
  final estado = datos['estado'];
  final reportadaPor = datos['reportada_por'];
  if (id is! String ||
      id.isEmpty ||
      categoria is! String ||
      tipo is! String ||
      estado is! String ||
      reportadaPor is! String) {
    return null;
  }

  final creadaEn = _entero(datos['creada_en']);
  final latitud = _decimal(datos['latitud']);
  final longitud = _decimal(datos['longitud']);
  if (creadaEn == null || latitud == null || longitud == null) {
    return null;
  }

  return Alerta.fromJson({
    'id': id,
    'categoria': categoria,
    'tipo': tipo,
    'descripcion': (datos['descripcion'] as String?) ?? '',
    'direccion': (datos['direccion'] as String?) ?? '',
    'creada_en': creadaEn,
    'estado': estado,
    'latitud': latitud,
    'longitud': longitud,
    'reportada_por': reportadaPor,
  });
}

int? _entero(Object? valor) {
  if (valor is int) return valor;
  if (valor is String) return int.tryParse(valor);
  return null;
}

double? _decimal(Object? valor) {
  if (valor is num) return valor.toDouble();
  if (valor is String) return double.tryParse(valor);
  return null;
}

/// Evalúa un mensaje push recibido en segundo plano: verifica que los avisos
/// estén activos en [preferencias], que la alerta no sea del vecino con
/// sesión abierta y que no esté resuelta. Si corresponde, muestra el aviso
/// con [notificaciones] y devuelve true.
Future<bool> procesarAvisoPush(
  Map<String, dynamic> datos, {
  required Preferencias preferencias,
  required NotificacionesService notificaciones,
}) async {
  final alerta = alertaDesdeDatosPush(datos);
  if (alerta == null) return false;
  if (alerta.estado == EstadoAlerta.resuelta) return false;

  if (!await preferencias.notificaciones()) return false;

  final vecino = await preferencias.vecino();
  if (vecino != null && alerta.reportadaPor == vecino.id) return false;

  await notificaciones.avisarAlerta(alerta);
  return true;
}

/// Avisos push que llegan aunque la app esté cerrada o el celular bloqueado.
abstract class PushService {
  /// Prepara el servicio de mensajería y registra el handler de segundo plano.
  Future<void> inicializar();

  /// Suscribe el dispositivo al tópico de alertas del barrio.
  Future<void> suscribirAlertas();

  /// Cancela la suscripción al tópico de alertas del barrio.
  Future<void> desuscribirAlertas();

  /// Id de cada alerta cuyo aviso push fue tocado por el vecino.
  Stream<String> get alertasTocadas;

  /// Id de la alerta si un aviso push abrió la app desde cero.
  Future<String?> alertaQueAbrioLaApp();
}

/// Implementación real con Firebase Cloud Messaging.
class PushServiceFirebase implements PushService {
  PushServiceFirebase();

  final _tocadas = StreamController<String>.broadcast();

  @override
  Future<void> inicializar() async {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(manejarMensajePushEnSegundoPlano);
    FirebaseMessaging.onMessageOpenedApp.listen((mensaje) {
      final id = _idDeMensaje(mensaje);
      if (id != null) _tocadas.add(id);
    });
  }

  @override
  Future<void> suscribirAlertas() async {
    await Firebase.initializeApp();
    await FirebaseMessaging.instance.subscribeToTopic(topicoAlertasPush);
  }

  @override
  Future<void> desuscribirAlertas() async {
    await Firebase.initializeApp();
    await FirebaseMessaging.instance.unsubscribeFromTopic(topicoAlertasPush);
  }

  @override
  Stream<String> get alertasTocadas => _tocadas.stream;

  @override
  Future<String?> alertaQueAbrioLaApp() async {
    await Firebase.initializeApp();
    final mensaje = await FirebaseMessaging.instance.getInitialMessage();
    return _idDeMensaje(mensaje);
  }

  String? _idDeMensaje(RemoteMessage? mensaje) {
    final id = mensaje?.data['id'];
    return id is String && id.isNotEmpty ? id : null;
  }
}

/// Para plataformas sin Firebase Cloud Messaging o para pruebas por defecto.
class PushServiceNinguno implements PushService {
  const PushServiceNinguno();

  @override
  Future<void> inicializar() async {}

  @override
  Future<void> suscribirAlertas() async {}

  @override
  Future<void> desuscribirAlertas() async {}

  @override
  Stream<String> get alertasTocadas => const Stream.empty();

  @override
  Future<String?> alertaQueAbrioLaApp() async => null;
}
