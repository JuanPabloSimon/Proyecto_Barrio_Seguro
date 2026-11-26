import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/sesion_repository.dart';
import '../../../data/services/bus_de_eventos.dart';
import '../../../data/services/error_del_servidor.dart';
import '../../../data/services/local/preferencias.dart';
import '../../../data/services/notificaciones_service.dart';
import '../../../data/services/push_service.dart';
import '../../../data/services/ubicacion_service.dart';
import '../../../data/services/reloj.dart';
import '../../../domain/evento_de_app.dart';
import '../../../domain/models/vecino.dart';
import '../../../plataforma/capacidades.dart';
import '../../../plataforma/politicas.dart';
import '../../core/formato.dart';

class PerfilViewModel extends ChangeNotifier {
  PerfilViewModel({
    required this._sesion,
    required this._bus,
    required this._reloj,
    required this._capacidades,
    required this._politicas,
    required this._preferencias,
    required this._ubicacion,
    required this._notificacionesService,
    this._pushService = const PushServiceNinguno(),
  }) {
    // Si se editan los datos, el perfil se vuelve a dibujar.
    _suscripcion = _bus.de<PerfilActualizado>().listen(
      (_) => notifyListeners(),
    );
  }

  final SesionRepository _sesion;
  final BusDeEventos _bus;
  final Reloj _reloj;
  final Capacidades _capacidades;
  final Politicas _politicas;
  final Preferencias _preferencias;
  final UbicacionService _ubicacion;
  final NotificacionesService _notificacionesService;
  final PushService _pushService;
  StreamSubscription<PerfilActualizado>? _suscripcion;

  Vecino? get usuario => _sesion.usuario;

  /// Si el vecino con sesión abierta pertenece a la comisión vecinal.
  bool get esComision => usuario?.esComision ?? false;

  bool get esGuardiaVentana =>
      usuario?.esGuardiaVentanaEn(_reloj.ahora()) ?? false;

  String get rol => esGuardiaVentana ? 'guardia de ventana' : 'patrullaje';

  /// Si el vecino ve la opción de guardia normal (70 años o más).
  bool get puedeElegirGuardiaNormal =>
      usuario?.puedeElegirGuardiaNormalEn(_reloj.ahora()) ?? false;

  /// El valor que confirmó el servidor.
  bool get guardiaNormal => usuario?.guardiaNormal ?? false;

  bool _cambiandoGuardiaNormal = false;

  /// True mientras se espera al servidor: el interruptor se desactiva.
  bool get cambiandoGuardiaNormal => _cambiandoGuardiaNormal;

  /// Pide el cambio al servidor. Devuelve null si salió bien o el mensaje
  /// para el vecino si no. Si falla, todo queda como estaba.
  ///
  /// A diferencia de las preferencias del teléfono, la guardia normal la
  /// guarda el servidor (es quien decide el lugar al anotarse): el
  /// interruptor cambia recién cuando confirma.
  Future<String?> cambiarGuardiaNormal(bool activa) async {
    _cambiandoGuardiaNormal = true;
    notifyListeners();
    try {
      await _sesion.cambiarGuardiaNormal(activa: activa);
      // Turnos, inicio y este perfil se redibujan con el lugar nuevo.
      _bus.publicar(const PerfilActualizado());
      return null;
    } on ErrorDelServidor catch (e) {
      return e.mensaje;
    } catch (_) {
      return 'No pudimos guardar el cambio. Revisá tu conexión y probá de '
          'nuevo.';
    } finally {
      _cambiandoGuardiaNormal = false;
      notifyListeners();
    }
  }

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

  /// Sin GPS no hay ubicación exacta: el interruptor se desactiva.
  bool get tieneGps => _capacidades.tieneGps;

  /// Si al activar "Compartir ubicación" hay que mostrar antes el aviso que
  /// explica para qué se usa (ver [Politicas.exigeAvisoAntesDeUbicacion]).
  bool get debeAvisarAntesDeCompartirUbicacion =>
      !_compartirUbicacion && _politicas.exigeAvisoAntesDeUbicacion;

  /// Si el dispositivo puede recibir notificaciones push. Si no, el
  /// interruptor se muestra desactivado con la explicación.
  bool get puedeRecibirNotificaciones => _capacidades.muestraNotificaciones;

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

  /// Activa la ubicación exacta: pide el permiso del sistema y, si lo
  /// dan, la deja prendida. Si no, devuelve el mensaje para el vecino.
  ///
  /// La pantalla llama a esto después del aviso propio (si la política lo
  /// exige): primero se explica, después pregunta el sistema.
  Future<String?> activarUbicacion() async {
    final permiso = await _ubicacion.pedirPermiso();
    switch (permiso) {
      case PermisoUbicacion.concedido:
        await cambiarCompartirUbicacion(true);
        return null;
      case PermisoUbicacion.denegado:
        return 'Sin el permiso de ubicación, en las alertas se comparte '
            'solo la zona aproximada.';
      case PermisoUbicacion.denegadoParaSiempre:
        _permisoBloqueado = true;
        notifyListeners();
        return 'El permiso de ubicación está bloqueado. Activalo desde los '
            'ajustes del teléfono.';
      case PermisoUbicacion.servicioApagado:
        return 'La ubicación del teléfono está apagada. Prendela y probá de '
            'nuevo.';
    }
  }

  bool _permisoBloqueado = false;

  /// Si el permiso quedó bloqueado y hay que ir a los ajustes.
  bool get permisoBloqueado => _permisoBloqueado;

  Future<void> abrirAjustes() => _ubicacion.abrirAjustes();

  /// Primero la pantalla (respuesta inmediata), después el disco.
  Future<void> cambiarCompartirUbicacion(bool valor) async {
    _compartirUbicacion = valor;
    notifyListeners();
    await _guardar(() => _preferencias.guardarCompartirUbicacion(valor));
  }

  /// Activa los avisos: pide el permiso del sistema y, si lo dan, los
  /// deja prendidos. Si no, devuelve el mensaje para el vecino. Sin
  /// permiso la app sigue funcionando igual; solo no avisa.
  Future<String?> activarAvisos() async {
    final otorgado = await _notificacionesService.pedirPermiso();
    if (!otorgado) {
      return 'Sin permiso no podemos avisarte de alertas nuevas. Podés '
          'activarlo desde los ajustes del teléfono.';
    }
    await cambiarNotificaciones(true);
    return null;
  }

  Future<void> cambiarNotificaciones(bool valor) async {
    _notificaciones = valor;
    notifyListeners();
    await _guardar(() => _preferencias.guardarNotificaciones(valor));
    if (valor) {
      await _guardar(_pushService.suscribirAlertas);
    } else {
      await _guardar(_pushService.desuscribirAlertas);
    }
  }

  /// Si el disco falla, el cambio queda igual mientras la app está abierta.
  Future<void> _guardar(Future<void> Function() escribir) async {
    try {
      await escribir();
    } catch (_) {}
  }

  Future<void> cerrarSesion() async {
    await _guardar(_pushService.desuscribirAlertas);
    await _sesion.cerrarSesion();
  }

  @override
  void dispose() {
    _suscripcion?.cancel();
    super.dispose();
  }
}
