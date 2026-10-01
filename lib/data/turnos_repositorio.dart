import 'package:flutter/foundation.dart';

import '../models/turno.dart';
import '../models/vecino.dart';
import 'datos_demo.dart';

/// Guarda los turnos en memoria y aplica las reglas de asignación.
/// Avisa a las pantallas cuando algo cambia (ChangeNotifier).
class TurnosRepositorio extends ChangeNotifier {
  TurnosRepositorio(List<Turno> iniciales) {
    for (final turno in iniciales) {
      _turnos[_clave(turno.fecha, turno.franja)] = turno;
    }
  }

  static const maxTurnosPorMes = 2;
  static const cupoPatrulla = 2;

  final Map<String, Turno> _turnos = {};

  String _clave(DateTime fecha, Franja franja) =>
      '${fecha.year}-${fecha.month}-${fecha.day}|${franja.name}';

  /// Devuelve el turno de ese día y franja (vacío si nadie se anotó).
  Turno turno(DateTime fecha, Franja franja) =>
      _turnos[_clave(fecha, franja)] ?? Turno(fecha: fecha, franja: franja);

  /// Turnos del vecino en el mes indicado, ordenados por fecha y horario.
  List<Turno> turnosDe(Vecino vecino, DateTime mes) {
    final lista = _turnos.values
        .where((t) =>
            t.fecha.year == mes.year &&
            t.fecha.month == mes.month &&
            t.incluye(vecino))
        .toList();
    lista.sort((a, b) {
      final porFecha = a.fecha.compareTo(b.fecha);
      return porFecha != 0 ? porFecha : a.franja.index.compareTo(b.franja.index);
    });
    return lista;
  }

  /// Motivo por el que el vecino no puede anotarse, o null si puede.
  String? motivoNoDisponible(Vecino vecino, Turno turno) {
    if (turno.incluye(vecino)) return null;

    final cantidad = turnosDe(vecino, turno.fecha).length;
    if (cantidad >= maxTurnosPorMes) {
      return 'Ya tenés $maxTurnosPorMes turnos este mes, que es el máximo permitido.';
    }
    if (vecino.esGuardiaVentana) {
      if (turno.guardiaVentana != null) {
        return 'Este turno ya tiene guardia de ventana.';
      }
    } else if (turno.patrulleros.length >= cupoPatrulla) {
      return 'La patrulla de este turno ya está completa.';
    }
    return null;
  }

  void anotar(Vecino vecino, DateTime fecha, Franja franja) {
    final turno = this.turno(fecha, franja);
    if (turno.incluye(vecino) || motivoNoDisponible(vecino, turno) != null) return;

    if (vecino.esGuardiaVentana) {
      turno.guardiaVentana = vecino;
    } else {
      turno.patrulleros.add(vecino);
    }
    _turnos[_clave(fecha, franja)] = turno;
    notifyListeners();
  }

  void salir(Vecino vecino, DateTime fecha, Franja franja) {
    final turno = _turnos[_clave(fecha, franja)];
    if (turno == null) return;

    turno.patrulleros.removeWhere((p) => p.id == vecino.id);
    if (turno.guardiaVentana?.id == vecino.id) turno.guardiaVentana = null;
    notifyListeners();
  }
}

final turnosRepositorio = TurnosRepositorio(turnosDemo());
