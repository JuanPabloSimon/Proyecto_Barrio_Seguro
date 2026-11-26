import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../data/repositories/alertas_repository.dart';
import '../../data/repositories/avisos_recibidos_repository.dart';
import '../../data/repositories/sesion_repository.dart';
import '../../data/services/bus_de_eventos.dart';
import '../../data/services/local/preferencias.dart';
import '../../data/services/notificaciones_service.dart';
import '../../data/services/reloj.dart';
import '../../domain/avisos_tardios.dart';
import '../../domain/evento_de_app.dart';
import '../../domain/models/alerta.dart';

/// Mientras la app está abierta, revisa cada tanto si hay alertas nuevas
/// de otros vecinos, o alertas resueltas que se volvieron a abrir, y avisa
/// con una notificación.
///
/// Las reaperturas no traen su hora: la demora se estima con el tiempo
/// desde la revisión anterior que obtuvo la lista (del [Reloj]). Con más
/// de 2 horas, se avisan como tardías, sin hora (estado_alerta R60).
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
    required this._avisos,
    required this._reloj,
    this.cada = const Duration(seconds: 45),
  });

  final AlertasRepository _alertas;
  final SesionRepository _sesion;
  final NotificacionesService _notificaciones;
  final Preferencias _preferencias;
  final BusDeEventos _bus;
  final AvisosRecibidosRepository _avisos;
  final Duration cada;

  final Reloj _reloj;

  Timer? _temporizador;
  AppLifecycleListener? _ciclo;

  /// True mientras el reloj periódico está activo (en primer plano).
  bool get enPrimerPlano => _temporizador?.isActive ?? false;

  /// Los ids que ya vio el vecino. null hasta la primera revisión: lo que
  /// ya estaba al abrir la app no se avisa.
  Set<String>? _conocidas;

  /// Los ids que estaban resueltos en la revisión anterior: si una deja de
  /// estarlo, se reabrió (estado_alerta R53).
  Set<String> _resueltas = {};

  /// La hora de la última revisión que obtuvo la lista: la foto de
  /// [_resueltas]. null hasta la primera (estado_alerta R60 a R63).
  DateTime? _ultimaRevision;

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
    _temporizador?.cancel();
    _temporizador = Timer.periodic(cada, (_) => revisar());
  }

  void _detenerReloj() {
    _temporizador?.cancel();
    _temporizador = null;
  }

  void detener() {
    _detenerReloj();
    _ciclo?.dispose();
    _ciclo = null;
  }

  /// Devuelve las alertas nuevas que avisó, a tiempo o tardías; las que
  /// llegaron demasiado tarde no (sirve para las pruebas). Las reaperturas
  /// avisadas no se devuelven: se ven en el servicio de notificaciones.
  Future<List<Alerta>> revisar() async {
    try {
      final todas = await _alertas.obtenerAlertas(refrescar: true);
      final conocidas = _conocidas;
      final resueltasAntes = _resueltas;
      // R63: si obtenerAlertas falla, el catch vuelve antes de llegar acá y
      // la próxima revisión se mide contra la última que funcionó.
      final ahora = _reloj.ahora();
      final anterior = _ultimaRevision;
      _ultimaRevision = ahora;
      _conocidas = {for (final a in todas) a.id};
      _resueltas = {
        for (final a in todas)
          if (a.estado == EstadoAlerta.resuelta) a.id,
      };
      if (conocidas == null) return const [];

      final yo = _sesion.usuario?.id;
      final nuevas = [
        for (final a in todas)
          if (!conocidas.contains(a.id) &&
              a.reportadaPor != yo &&
              a.estado != EstadoAlerta.resuelta)
            a,
      ];
      final reabiertas = [
        for (final a in todas)
          if (resueltasAntes.contains(a.id) &&
              a.estado != EstadoAlerta.resuelta)
            a,
      ];
      if (nuevas.isEmpty && reabiertas.isEmpty) return const [];

      // R5, R7: la llegada se guarda solo si hay aviso. Si el push ya la
      // guardó, cuenta la del push (R6). Se guarda antes de publicar, así
      // las pantallas, al recargar, ya ven la marca de tardía.
      final conAvisos = await _preferencias.notificaciones();
      final llegadas = <String, DateTime>{};
      if (conAvisos) {
        for (final alerta in nuevas) {
          llegadas[alerta.id] = await _avisos.registrarLlegada(alerta.id);
        }
      }

      // Las pantallas abiertas se actualizan solas (también R54).
      _bus.publicar(const AlertasActualizadas());
      if (!conAvisos) return const [];

      // R53, R55, R60 a R65: la reapertura de una alerta de otro vecino.
      // El vigilante no conoce `reabierta_en`: la demora se estima con el
      // tiempo desde la revisión anterior; con más de 2 horas, el aviso es
      // tardío y sin hora. No se tocan las llegadas: la marca de tardía es
      // la del aviso original.
      final reaperturasTardias =
          anterior != null &&
          reaperturaDelVigilanteTardia(
            revisionAnterior: anterior,
            ahora: ahora,
          );
      for (final alerta in reabiertas) {
        if (alerta.reportadaPor != yo) {
          if (reaperturasTardias) {
            await _notificaciones.avisarReaperturaTardiaSinHora(alerta);
          } else {
            await _notificaciones.avisarReapertura(alerta);
          }
        }
      }

      // R19: la misma regla que el push.
      final avisadas = <Alerta>[];
      for (final alerta in nuevas) {
        final puntualidad = clasificarAviso(
          creadaEn: alerta.creadaEn,
          llegada: llegadas[alerta.id]!,
        );
        switch (puntualidad) {
          case PuntualidadAviso.aTiempo:
            await _notificaciones.avisarAlerta(alerta);
            avisadas.add(alerta);
          case PuntualidadAviso.tardio:
            await _notificaciones.avisarAlertaTardia(alerta);
            avisadas.add(alerta);
          case PuntualidadAviso.demasiadoTardio:
            break;
        }
      }
      return avisadas;
    } catch (_) {
      // Sin señal: se vuelve a intentar en la próxima revisión.
      return const [];
    }
  }
}
