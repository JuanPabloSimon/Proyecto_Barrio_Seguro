import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../domain/models/alerta.dart';

/// Avisos del sistema operativo: aparecen aunque el vecino esté en otra app.
abstract class NotificacionesService {
  /// Se llama una vez al arrancar la app.
  Future<void> inicializar();

  /// Pide el permiso (Android 13+ e iOS). Se pide en contexto, cuando el
  /// vecino activa los avisos, nunca al abrir la app. Devuelve si lo dio.
  Future<bool> pedirPermiso();

  /// Muestra el aviso de una alerta nueva.
  Future<void> avisarAlerta(Alerta alerta);

  /// El id de la alerta de cada aviso que el vecino toca con la app abierta
  /// o en segundo plano.
  Stream<String> get alertasTocadas;

  /// El id de la alerta si la app se abrió tocando un aviso.
  Future<String?> alertaQueAbrioLaApp();
}

/// Con flutter_local_notifications.
class NotificacionesServiceLocales implements NotificacionesService {
  NotificacionesServiceLocales();

  final _plugin = FlutterLocalNotificationsPlugin();

  /// El toque llega por un callback fuera de cualquier widget: se convierte
  /// en un Stream y quien lo escucha decide a dónde ir.
  final _tocadas = StreamController<String>.broadcast();

  static const _prefijo = 'alerta:';

  /// Un solo canal, con nombre claro: el vecino lo puede silenciar desde
  /// los ajustes del teléfono sin apagar otras cosas.
  static const _detalles = NotificationDetails(
    android: AndroidNotificationDetails(
      'alertas', // id del canal: fijo, no se cambia
      'Alertas del barrio',
      channelDescription:
          'Avisos cuando un vecino reporta una alerta o pide ayuda',
      importance: Importance.high, // aparece arriba de la pantalla
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  @override
  Future<void> inicializar() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // El permiso se pide con el interruptor del perfil, no acá.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (respuesta) {
        final id = _idDeAlerta(respuesta.payload);
        if (id != null) _tocadas.add(id);
      },
    );
  }

  @override
  Future<bool> pedirPermiso() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return false;
  }

  @override
  Future<void> avisarAlerta(Alerta alerta) {
    final esSos = alerta.categoria == CategoriaAlerta.sos;
    return _plugin.show(
      // Un id por alerta: si se avisa de nuevo, se reemplaza, no se apila.
      id: alerta.id.hashCode & 0x7fffffff,
      title: esSos ? 'SOS: un vecino pidió ayuda' : alerta.tipo,
      body: '${alerta.direccion}. Tocá para ver dónde.',
      notificationDetails: _detalles,
      payload: '$_prefijo${alerta.id}',
    );
  }

  @override
  Stream<String> get alertasTocadas => _tocadas.stream;

  @override
  Future<String?> alertaQueAbrioLaApp() async {
    final detalles = await _plugin.getNotificationAppLaunchDetails();
    if (!(detalles?.didNotificationLaunchApp ?? false)) return null;
    return _idDeAlerta(detalles!.notificationResponse?.payload);
  }

  String? _idDeAlerta(String? payload) =>
      payload != null && payload.startsWith(_prefijo)
      ? payload.substring(_prefijo.length)
      : null;
}

/// Para plataformas sin notificaciones: no hace nada.
class NotificacionesServiceNinguno implements NotificacionesService {
  const NotificacionesServiceNinguno();

  @override
  Future<void> inicializar() async {}

  @override
  Future<bool> pedirPermiso() async => false;

  @override
  Future<void> avisarAlerta(Alerta alerta) async {}

  @override
  Stream<String> get alertasTocadas => const Stream.empty();

  @override
  Future<String?> alertaQueAbrioLaApp() async => null;
}
