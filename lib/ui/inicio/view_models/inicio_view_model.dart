import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/alertas_repository.dart';
import '../../../data/repositories/sesion_repository.dart';
import '../../../data/repositories/turnos_repository.dart';
import '../../../data/services/bus_de_eventos.dart';
import '../../../data/services/reloj.dart';
import '../../../domain/models/alerta.dart';
import '../../../domain/models/turno.dart';
import '../../core/estado_carga.dart';
import '../../core/formato.dart';

/// Resumen del próximo turno del vecino, listo para mostrar.
class ResumenTurno {
  const ResumenTurno({
    required this.titulo,
    required this.lineas,
    required this.esGuardiaVentana,
  });

  final String titulo;
  final List<String> lineas;
  final bool esGuardiaVentana;
}

class InicioViewModel extends ChangeNotifier {
  InicioViewModel({
    required this._alertas,
    required this._turnos,
    required this._sesion,
    required BusDeEventos bus,
    required this._reloj,
    required this._mesDeTurnos,
  }) {
    // Si otra pantalla anota un turno o envía una alerta, el inicio se
    // actualiza solo.
    _suscripcion = bus.eventos.listen((_) => cargar());
  }

  final AlertasRepository _alertas;
  final TurnosRepository _turnos;
  final SesionRepository _sesion;
  final Reloj _reloj;
  final DateTime _mesDeTurnos;
  StreamSubscription<Object>? _suscripcion;

  EstadoCarga _estado = EstadoCarga.inicial;
  EstadoCarga get estado => _estado;

  List<Alerta> _cercanas = [];

  /// Alertas que todavía no se resolvieron.
  List<Alerta> get cercanas => List.unmodifiable(_cercanas);

  int _cantidadActivas = 0;
  int get cantidadActivas => _cantidadActivas;

  ResumenTurno? _proximoTurno;
  ResumenTurno? get proximoTurno => _proximoTurno;

  /// True si no hubo conexión y se muestran los datos guardados.
  bool get sinConexion => _alertas.sinConexion || _turnos.sinConexion;

  String get saludo => 'Hola, ${_sesion.usuario?.primerNombre ?? 'vecino'}';

  String hace(Alerta alerta) =>
      tiempoTranscurrido(alerta.creadaEn, _reloj.ahora());

  Future<void> cargar() async {
    // El indicador de carga solo se muestra la primera vez; después los
    // datos se actualizan sin borrar lo que ya se ve.
    if (_estado != EstadoCarga.exito) {
      _estado = EstadoCarga.cargando;
      notifyListeners();
    }
    try {
      // Los dos pedidos salen a la vez y se espera a que terminen ambos.
      final resultados = await Future.wait([
        _alertas.obtenerAlertas(),
        _turnos.obtenerTurnos(_mesDeTurnos),
      ]);
      final alertas = resultados[0] as List<Alerta>;
      final turnos = resultados[1] as List<Turno>;

      _cercanas = alertas
          .where((a) => a.estado != EstadoAlerta.resuelta)
          .toList();
      _cantidadActivas = alertas
          .where((a) => a.estado == EstadoAlerta.activa)
          .length;
      _proximoTurno = _resumir(turnos);
      _estado = EstadoCarga.exito;
    } catch (_) {
      if (_estado != EstadoCarga.exito) _estado = EstadoCarga.error;
    } finally {
      notifyListeners();
    }
  }

  ResumenTurno? _resumir(List<Turno> turnos) {
    final usuario = _sesion.usuario;
    if (usuario == null) return null;
    final esGuardia = usuario.esGuardiaVentanaEn(_reloj.ahora());

    final mios = turnos.where((t) => t.incluye(usuario)).toList()
      ..sort((a, b) {
        final porFecha = a.fecha.compareTo(b.fecha);
        return porFecha != 0
            ? porFecha
            : a.franja.index.compareTo(b.franja.index);
      });

    if (mios.isEmpty) {
      return ResumenTurno(
        titulo: 'Todavía no tenés turnos en ${nombreMes(_mesDeTurnos.month)}',
        lineas: const ['Elegí un día y un horario en el calendario de turnos.'],
        esGuardiaVentana: esGuardia,
      );
    }

    final turno = mios.first;
    final patrulla = turno
        .companierosDe(usuario)
        .map((v) => v.nombre)
        .join(', ');
    final guardia = turno.guardiaVentana;
    return ResumenTurno(
      titulo: esGuardia
          ? 'Tu próxima guardia de ventana'
          : 'Tu próximo turno de patrullaje',
      lineas: [
        '${fechaLarga(turno.fecha)}, ${turno.franja.horario}',
        if (esGuardia)
          patrulla.isEmpty
              ? 'Sin patrulla anotada todavía'
              : 'Patrulla: $patrulla'
        else ...[
          patrulla.isEmpty ? 'Sin compañero todavía' : 'Con $patrulla',
          if (guardia != null) 'Guardia de ventana: ${guardia.nombre}',
        ],
      ],
      esGuardiaVentana: esGuardia,
    );
  }

  @override
  void dispose() {
    _suscripcion?.cancel();
    super.dispose();
  }
}
