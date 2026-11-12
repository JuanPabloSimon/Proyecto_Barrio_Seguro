import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/sesion_repository.dart';
import '../../../data/services/bus_de_eventos.dart';
import '../../../data/services/local/preferencias.dart';
import '../../../data/services/reloj.dart';
import '../../../domain/evento_de_app.dart';
import '../../../domain/models/vecino.dart';
import '../../../plataforma/capacidades.dart';
import '../../../plataforma/politicas.dart';
import '../../core/formato.dart';

class PerfilViewModel extends ChangeNotifier {
  PerfilViewModel({
    required this._sesion,
    required BusDeEventos bus,
    required this._reloj,
    required this._capacidades,
    required this._politicas,
    required this._preferencias,
  }) {
    // Si se editan los datos, el perfil se vuelve a dibujar.
    _suscripcion = bus.de<PerfilActualizado>().listen((_) => notifyListeners());
  }

  final SesionRepository _sesion;
  final Reloj _reloj;
  final Capacidades _capacidades;
  final Politicas _politicas;
  final Preferencias _preferencias;
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

  // Preferencias del vecino, guardadas en el teléfono con [Preferencias].
  // Los valores por defecto (ubicación apagada, notificaciones prendidas)
  // están definidos ahí, en un solo lugar.

  /// Arranca apagado: la ubicación exacta se comparte recién cuando el
  /// vecino lo acepta.
  bool _compartirUbicacion = false;
  bool get compartirUbicacion => _compartirUbicacion;

  /// Si al activar "Compartir ubicación" hay que mostrar antes el aviso que
  /// explica para qué se usa (ver [Politicas.exigeAvisoAntesDeUbicacion]).
  bool get debeAvisarAntesDeCompartirUbicacion =>
      !_compartirUbicacion && _politicas.exigeAvisoAntesDeUbicacion;

  /// Si el dispositivo puede recibir notificaciones push. Si no, el
  /// interruptor se muestra desactivado con la explicación.
  bool get puedeRecibirNotificaciones => _capacidades.recibeNotificacionesPush;

  bool _notificaciones = true;
  bool get notificaciones => puedeRecibirNotificaciones && _notificaciones;

  /// Lee las preferencias guardadas. Se llama al crear el ViewModel.
  Future<void> cargar() async {
    try {
      _compartirUbicacion = await _preferencias.compartirUbicacion();
      _notificaciones = await _preferencias.notificaciones();
    } catch (_) {
      // Si no se pueden leer, quedan los valores por defecto.
    }
    notifyListeners();
  }

  /// Primero la pantalla (respuesta inmediata), después el disco.
  Future<void> cambiarCompartirUbicacion(bool valor) async {
    _compartirUbicacion = valor;
    notifyListeners();
    await _guardar(() => _preferencias.guardarCompartirUbicacion(valor));
  }

  Future<void> cambiarNotificaciones(bool valor) async {
    _notificaciones = valor;
    notifyListeners();
    await _guardar(() => _preferencias.guardarNotificaciones(valor));
  }

  /// Si el disco falla, el cambio queda igual mientras la app está abierta.
  Future<void> _guardar(Future<void> Function() escribir) async {
    try {
      await escribir();
    } catch (_) {}
  }

  Future<void> cerrarSesion() => _sesion.cerrarSesion();

  @override
  void dispose() {
    _suscripcion?.cancel();
    super.dispose();
  }
}
