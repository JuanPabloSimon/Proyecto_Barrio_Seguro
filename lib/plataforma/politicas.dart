import 'package:flutter/foundation.dart';

/// Lo que la app **debe** hacer en cada plataforma: reglas de las tiendas y
/// decisiones de diseño del equipo.
class Politicas {
  const Politicas();

  /// Si antes de compartir la ubicación hay que mostrar un aviso propio que
  /// explique para qué se usa, con quién se comparte y permita decir que no.
  ///
  /// Google Play lo exige ("prominent disclosure") cuando la app usa datos
  /// sensibles de un modo que el usuario podría no esperar, como mandarle la
  /// ubicación a otros vecinos. El aviso va dentro de la app, justo antes
  /// del permiso del sistema. En iOS el propio diálogo del sistema muestra
  /// el motivo que escribimos en Info.plist.
  bool get exigeAvisoAntesDeUbicacion {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android;
  }
}
