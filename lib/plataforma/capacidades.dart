import 'package:flutter/foundation.dart';

/// Lo que el dispositivo o la plataforma **puede** hacer.
///
/// Las pantallas no preguntan "¿es Android?": preguntan "¿puede hacer
/// llamadas?". Así, si una regla cambia, se cambia acá y en ningún otro
/// lado. Se usa `defaultTargetPlatform` y `kIsWeb` (y no `Platform.isIOS`,
/// de dart:io) porque funcionan también en la web.
class Capacidades {
  const Capacidades();

  /// Si el dispositivo puede abrir la app de teléfono para llamar al 911.
  ///
  /// Simplificación: decide según la plataforma. Una tablet sin chip no
  /// puede llamar aunque sea Android; en ese caso el teléfono no se abre y
  /// la app le pide al vecino que marque a mano.
  bool get puedeHacerLlamadas {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// Si hay base de datos local (sqflite) para guardar alertas y turnos.
  ///
  /// El plugin funciona en Android, iOS y macOS. En la web y en Windows o
  /// Linux la app funciona igual, pero sin la copia para usar sin conexión.
  bool get tieneBaseDeDatosLocal {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  /// Si la app puede recibir notificaciones push de alertas.
  ///
  /// Firebase Cloud Messaging no funciona en Windows ni en Linux, y por
  /// ahora solo lo vamos a configurar en Android e iOS.
  bool get recibeNotificacionesPush {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }
}
