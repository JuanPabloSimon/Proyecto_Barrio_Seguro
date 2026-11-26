import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../data/repositories/alertas_repository.dart';
import '../../data/repositories/sesion_repository.dart';
import '../../data/services/bus_de_eventos.dart';
import '../../data/services/local/preferencias.dart';
import '../../data/services/notificaciones_service.dart';
import '../../domain/evento_de_app.dart';
import '../../domain/models/alerta.dart';

/// Mientras la app está abierta, revisa cada tanto si hay alertas nuevas
/// de otros vecinos y avisa con una notificación.
///
/// Reaccionando a los eventos del ciclo de vida del sistema operativo
/// ([AppLifecycleListener]):
/// - Al pasar a segundo plano (`onPause`), detiene el reloj periódico para
///   no hacer pedidos innecesarios.
/// - Al volver a primer plano (`onResume`), revisa inmediatamente y vuelve
///   a encender el reloj periódico.
class VigilanteDeAlertas {
  VigilanteDeAlertas({
    required this._alertas,
    required this._sesion,
    required this._notificaciones,
    required this._preferencias,
    required this._bus,
    this.cada = const Duration(seconds: 45),
  });

  final AlertasRepository _alertas;
  final SesionRepository _sesion;
  final NotificacionesService _notificaciones;
  final Preferencias _preferencias;
  final BusDeEventos _bus;
  final Duration cada;

  Timer? _reloj;
  AppLifecycleListener? _ciclo;

  /// True mientras el reloj periódico está activo (en primer plano).
  bool get enPrimerPlano => _reloj?.isActive ?? false;

  /// Los ids que ya vio el vecino. null hasta la primera revisión: lo que
  /// ya estaba al abrir la app no se avisa.
  Set<String>? _conocidas;

  void empezar() {
    revisar();
    _iniciarReloj();
    _ciclo = AppLifecycleListener(
      onPause: _detenerReloj,
      onResume: () {
        _iniciarReloj();
        revisar();
      },
    );
  }

  void _iniciarReloj() {
    _reloj?.cancel();
    _reloj = Timer.periodic(cada, (_) => revisar());
  }

  void _detenerReloj() {
    _reloj?.cancel();
    _reloj = null;
  }

  void detener() {
    _detenerReloj();
    _ciclo?.dispose();
    _ciclo = null;
  }

  /// Devuelve las alertas nuevas que avisó (sirve para las pruebas).
  Future<List<Alerta>> revisar() async {
    try {
      final todas = await _alertas.obtenerAlertas(refrescar: true);
      final conocidas = _conocidas;
      _conocidas = {for (final a in todas) a.id};
      if (conocidas == null) return const [];

      final yo = _sesion.usuario?.id;
      final nuevas = [
        for (final a in todas)
          if (!conocidas.contains(a.id) &&
              a.reportadaPor != yo &&
              a.estado != EstadoAlerta.resuelta)
            a,
      ];
      if (nuevas.isEmpty) return const [];

      // Las pantallas abiertas se actualizan solas.
      _bus.publicar(const AlertasActualizadas());
      if (!await _preferencias.notificaciones()) return const [];
      for (final alerta in nuevas) {
        await _notificaciones.avisarAlerta(alerta);
      }
      return nuevas;
    } catch (_) {
      // Sin señal: se vuelve a intentar en la próxima revisión.
      return const [];
    }
  }
}
