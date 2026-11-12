import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/sesion_repository.dart';
import '../../../data/services/bus_de_eventos.dart';
import '../../../data/services/reloj.dart';
import '../../../domain/evento_de_app.dart';
import '../../../domain/models/vecino.dart';
import '../../core/formato.dart';

class PerfilViewModel extends ChangeNotifier {
  PerfilViewModel({
    required this._sesion,
    required BusDeEventos bus,
    required this._reloj,
  }) {
    // Si se editan los datos, el perfil se vuelve a dibujar.
    _suscripcion = bus.de<PerfilActualizado>().listen((_) => notifyListeners());
  }

  final SesionRepository _sesion;
  final Reloj _reloj;
  StreamSubscription<PerfilActualizado>? _suscripcion;

  Vecino? get usuario => _sesion.usuario;

  bool get esGuardiaVentana =>
      usuario?.esGuardiaVentanaEn(_reloj.ahora()) ?? false;

  String get rol => esGuardiaVentana ? 'guardia de ventana' : 'patrullaje';

  /// "Cabildo de Mendoza, Cuadra 12"
  String get direccion {
    final u = usuario;
    if (u == null) return '';
    return [u.calle, u.cuadra].where((t) => t.isNotEmpty).join(', ');
  }

  /// "45 años. En la red desde marzo de 2021"
  String get edadYAntiguedad {
    final u = usuario;
    if (u == null) return '';
    final desde = u.vecinoDesde;
    final edad = '${u.edadEn(_reloj.ahora())} años.';
    if (desde == null) return edad;
    return '$edad En la red desde ${nombreMes(desde.month)} de ${desde.year}';
  }

  // Preferencias del vecino. Por ahora viven en memoria; en la rama de
  // persistencia se guardan con shared_preferences.
  bool _compartirUbicacion = true;
  bool get compartirUbicacion => _compartirUbicacion;

  bool _notificaciones = true;
  bool get notificaciones => _notificaciones;

  void cambiarCompartirUbicacion(bool valor) {
    _compartirUbicacion = valor;
    notifyListeners();
  }

  void cambiarNotificaciones(bool valor) {
    _notificaciones = valor;
    notifyListeners();
  }

  Future<void> cerrarSesion() => _sesion.cerrarSesion();

  @override
  void dispose() {
    _suscripcion?.cancel();
    super.dispose();
  }
}
