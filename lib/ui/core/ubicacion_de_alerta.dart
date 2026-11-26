import 'package:latlong2/latlong.dart';

import '../../data/services/local/preferencias.dart';
import '../../data/services/ubicacion_service.dart';
import '../../domain/barrio.dart';
import '../../plataforma/capacidades.dart';

/// Dirección de una alerta que lleva la posición del GPS y no tiene una
/// dirección escrita.
const direccionExacta = 'Ubicación exacta del vecino';

/// Dirección de una alerta que lleva la posición del centro del barrio.
const direccionZona = '${Barrio.nombre} (zona aproximada)';

/// Decide qué posición lleva una alerta nueva (SOS o "Reportar alerta"):
/// la del GPS solo si el dispositivo tiene GPS y el vecino activó
/// "Compartir ubicación exacta en alertas". Si no, o si algo falla, el que
/// la usa manda el centro del barrio.
class UbicacionDeAlerta {
  const UbicacionDeAlerta({
    required this._capacidades,
    required this._preferencias,
    required this._ubicacion,
  });

  final Capacidades _capacidades;
  final Preferencias _preferencias;
  final UbicacionService _ubicacion;

  /// True si hay GPS y el vecino activó la ubicación exacta. False si
  /// falla la lectura de la preferencia.
  Future<bool> compartePosicionExacta() async {
    if (!_capacidades.tieneGps) return false;
    try {
      return await _preferencias.compartirUbicacion();
    } catch (_) {
      return false;
    }
  }

  /// La posición del GPS, o null si no comparte, no hay GPS o no responde.
  Future<LatLng?> posicionExacta() async {
    if (!await compartePosicionExacta()) return null;
    try {
      return await _ubicacion.ubicacionActual();
    } catch (_) {
      return null;
    }
  }
}
