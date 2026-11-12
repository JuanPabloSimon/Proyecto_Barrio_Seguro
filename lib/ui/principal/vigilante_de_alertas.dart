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
/// de otros vecinos y avisa con una notificación. También manda las
/// alertas que quedaron pendientes por falta de señal.
///
/// Revisa al empezar, cada [cada] y cada vez que la app vuelve a primer
/// plano (AppLifecycleListener, apunte de eventos del sistema): lo de fondo
/// no garantiza cuándo corre, así que se refresca también al volver.
///
/// Con la app cerrada no puede avisar: para eso hacen falta notificaciones
/// push (Firebase Cloud Messaging), que necesitan un proyecto de Firebase.
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

  /// Los ids que ya vio el vecino. null hasta la primera revisión: lo que
  /// ya estaba al abrir la app no se avisa.
  Set<String>? _conocidas;

  void empezar() {
    revisar();
    _reloj = Timer.periodic(cada, (_) => revisar());
    _ciclo = AppLifecycleListener(onResume: revisar);
  }

  void detener() {
    _reloj?.cancel();
    _ciclo?.dispose();
  }

  /// Devuelve las alertas nuevas que avisó (sirve para las pruebas).
  Future<List<Alerta>> revisar() async {
    try {
      await _alertas.enviarPendientes();
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
