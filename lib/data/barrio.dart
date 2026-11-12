import 'dart:math' as math;

import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:latlong2/latlong.dart' show Distance, LatLng;

/// Datos geográficos del barrio.
class Barrio {
  Barrio._();

  static const nombre = 'Barrio Soberanía';
  static const ciudad = 'Ciudad de Mendoza';

  /// Punto de referencia del barrio: Cabildo de Mendoza, cerca de Ascasubi.
  /// Mientras no se use el GPS, también es la posición del vecino.
  static const centro = LatLng(-32.876568, -68.870672);

  /// Distancia hasta la que un vecino recibe las alertas.
  static const radioAlertasMetros = 1000.0;

  /// Calles de OpenStreetMap. Su servidor público no garantiza disponibilidad:
  /// antes de publicar la app conviene cambiar esta dirección por la de un
  /// proveedor con contrato (no hace falta tocar nada más).
  static const urlCalles = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// OpenStreetMap bloquea las apps que no se identifican o que usan un
  /// identificador genérico como "com.example".
  static const identificadorApp = 'com.barrioseguro.app';

  /// Rectángulo que contiene el círculo del radio de alertas.
  static LatLngBounds get limitesDelRadio {
    const metrosPorGrado = 111320.0;
    const deltaLatitud = radioAlertasMetros / metrosPorGrado;
    final deltaLongitud =
        radioAlertasMetros / (metrosPorGrado * math.cos(centro.latitude * math.pi / 180));
    return LatLngBounds(
      LatLng(centro.latitude - deltaLatitud, centro.longitude - deltaLongitud),
      LatLng(centro.latitude + deltaLatitud, centro.longitude + deltaLongitud),
    );
  }

  /// Distancia en metros desde el centro del barrio.
  static double distanciaAlCentro(LatLng punto) =>
      const Distance().distance(centro, punto);

  static bool estaDentroDelRadio(LatLng punto) =>
      distanciaAlCentro(punto) <= radioAlertasMetros;
}
