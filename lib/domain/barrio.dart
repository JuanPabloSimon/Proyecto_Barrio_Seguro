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

  /// Distancia en metros desde el centro del barrio.
  static double distanciaAlCentro(LatLng punto) =>
      const Distance().distance(centro, punto);

  static bool estaDentroDelRadio(LatLng punto) =>
      distanciaAlCentro(punto) <= radioAlertasMetros;
}
