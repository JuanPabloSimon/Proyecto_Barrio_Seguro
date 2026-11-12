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

  /// Si el dispositivo tiene GPS para mandar la ubicación exacta en una
  /// alerta. Simplificación por plataforma, como [puedeHacerLlamadas].
  bool get tieneGps {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// Si la app puede mostrar notificaciones (avisos de alertas nuevas).
  ///
  /// flutter_local_notifications funciona en Android e iOS; en el resto
  /// la app no avisa fuera de la pantalla.
  bool get muestraNotificaciones {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// Si se pueden programar tareas que corren con la app cerrada
  /// (workmanager), por ejemplo para mandar una alerta cuando vuelve la
  /// señal. Solo Android: en iOS hace falta configurarlo en Xcode, con una
  /// Mac.
  bool get correTareasEnSegundoPlano {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android;
  }
}
