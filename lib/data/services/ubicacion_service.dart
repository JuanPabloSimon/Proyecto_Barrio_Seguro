import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Qué respondió el sistema cuando se pidió usar la ubicación.
enum PermisoUbicacion {
  concedido,

  /// Dijo que no. Se le puede volver a preguntar.
  denegado,

  /// Dijo que no y pidió no volver a preguntar: solo se cambia desde los
  /// ajustes del teléfono.
  denegadoParaSiempre,

  /// El GPS del teléfono está apagado.
  servicioApagado,
}

/// La posición del teléfono, con el GPS.
abstract class UbicacionService {
  /// Pide el permiso de ubicación "mientras se usa la app" (nunca en
  /// segundo plano). Si ya estaba concedido, no vuelve a preguntar.
  Future<PermisoUbicacion> pedirPermiso();

  /// Dónde está el teléfono ahora, o null si no hay permiso o el GPS no
  /// responde a tiempo.
  Future<LatLng?> ubicacionActual();

  /// Abre los ajustes de la app, para cambiar un permiso denegado.
  Future<void> abrirAjustes();
}

class UbicacionServiceGeolocator implements UbicacionService {
  const UbicacionServiceGeolocator({this.espera = const Duration(seconds: 6)});

  /// Un SOS no puede esperar al GPS: pasado este tiempo, se manda con la
  /// ubicación aproximada.
  final Duration espera;

  @override
  Future<PermisoUbicacion> pedirPermiso() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return PermisoUbicacion.servicioApagado;
    }
    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    return switch (permiso) {
      LocationPermission.whileInUse ||
      LocationPermission.always => PermisoUbicacion.concedido,
      LocationPermission.deniedForever => PermisoUbicacion.denegadoParaSiempre,
      _ => PermisoUbicacion.denegado,
    };
  }

  @override
  Future<LatLng?> ubicacionActual() async {
    try {
      final permiso = await Geolocator.checkPermission();
      if (permiso != LocationPermission.whileInUse &&
          permiso != LocationPermission.always) {
        return null;
      }
      final posicion = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: espera,
        ),
      );
      return LatLng(posicion.latitude, posicion.longitude);
    } catch (_) {
      // Sin señal, GPS apagado o se pasó el tiempo.
      return null;
    }
  }

  @override
  Future<void> abrirAjustes() => Geolocator.openAppSettings();
}
