import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/avisos_tardios.dart';
import '../../domain/models/alerta.dart';
import '../repositories/avisos_recibidos_repository.dart';
import 'local/preferencias.dart';
import 'notificaciones_service.dart';
import 'reloj.dart';

/// Tópico de Firebase Cloud Messaging al que se suscriben los teléfonos del
/// barrio para recibir alertas nuevas con la app cerrada.
const topicoAlertasPush = 'alertas';

/// Valor de la clave `aviso` de un push que avisa que una alerta resuelta
/// se volvió a abrir (estado_alerta). Un push sin `aviso` es de una alerta
/// nueva.
const avisoPushReabierta = 'reabierta';

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
  // Corre en otro isolate, sin Dependencias: arma sus propias piezas sobre
  // las mismas preferencias (SharedPreferencesAsync no tiene caché).
  final preferencias = Preferencias(SharedPreferencesAsync());
  await procesarAvisoPush(
    mensaje.data,
    preferencias: preferencias,
    notificaciones: notificaciones,
    avisos: AvisosRecibidosRepositoryLocal(
      preferencias: preferencias,
      reloj: const RelojDelSistema(),
    ),
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
    if (datos['reportada_por_nombre'] case final String nombre)
      'reportada_por_nombre': nombre,
  });
}

/// `reabierta_en` del mensaje (entero o texto, en ms desde la época, hora
/// del servidor) o null si falta o no es válido.
DateTime? reabiertaEnDesdeDatosPush(Map<String, dynamic> datos) {
  final ms = _entero(datos['reabierta_en']);
  return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
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
/// sesión abierta y que no esté resuelta. Si corresponde, guarda la llegada
/// en [avisos] y muestra el aviso con [notificaciones]: el de siempre si
/// llegó a tiempo, el tardío si llegó con demora, o ninguno si llegó más de
/// 2 horas después (R5, R13, R14, R15). Devuelve true si mostró un aviso.
Future<bool> procesarAvisoPush(
  Map<String, dynamic> datos, {
  required Preferencias preferencias,
  required NotificacionesService notificaciones,
  required AvisosRecibidosRepository avisos,
}) async {
  if (datos['aviso'] == avisoPushReabierta) {
    return _procesarReapertura(
      datos,
      preferencias: preferencias,
      notificaciones: notificaciones,
      avisos: avisos,
    );
  }
  final alerta = alertaDesdeDatosPush(datos);
  if (alerta == null) return false;
  if (alerta.estado == EstadoAlerta.resuelta) return false;

  if (!await preferencias.notificaciones()) return false;

  final vecino = await preferencias.vecino();
  if (vecino != null && alerta.reportadaPor == vecino.id) return false;

  final llegada = await avisos.registrarLlegada(alerta.id);
  switch (clasificarAviso(creadaEn: alerta.creadaEn, llegada: llegada)) {
    case PuntualidadAviso.aTiempo:
      await notificaciones.avisarAlerta(alerta);
      return true;
    case PuntualidadAviso.tardio:
      await notificaciones.avisarAlertaTardia(alerta);
      return true;
    case PuntualidadAviso.demasiadoTardio:
      return false;
  }
}

/// Aviso de una alerta resuelta que se volvió a abrir (estado_alerta R46 a
/// R52). Mismas condiciones que una alerta nueva, pero la demora se mide
/// desde `reabierta_en` y no se guarda la llegada: la guardada es la del
/// aviso original y decide la marca de "tardía" de la alerta.
Future<bool> _procesarReapertura(
  Map<String, dynamic> datos, {
  required Preferencias preferencias,
  required NotificacionesService notificaciones,
  required AvisosRecibidosRepository avisos,
}) async {
  final alerta = alertaDesdeDatosPush(datos);
  final reabiertaEn = reabiertaEnDesdeDatosPush(datos);
  if (alerta == null || reabiertaEn == null) return false;
  if (alerta.estado == EstadoAlerta.resuelta) return false;

  if (!await preferencias.notificaciones()) return false;

  final vecino = await preferencias.vecino();
  if (vecino != null && alerta.reportadaPor == vecino.id) return false;

  final llegada = await avisos.horaDelServidor();
  switch (clasificarAviso(creadaEn: reabiertaEn, llegada: llegada)) {
    case PuntualidadAviso.aTiempo:
      await notificaciones.avisarReapertura(alerta);
      return true;
    case PuntualidadAviso.tardio:
      await notificaciones.avisarReaperturaTardia(alerta, reabiertaEn);
      return true;
    case PuntualidadAviso.demasiadoTardio:
      return false;
  }
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
