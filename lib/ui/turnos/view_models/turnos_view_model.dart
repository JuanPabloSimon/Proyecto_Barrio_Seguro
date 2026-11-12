import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/sesion_repository.dart';
import '../../../data/repositories/turnos_repository.dart';
import '../../../data/services/bus_de_eventos.dart';
import '../../../data/services/error_del_servidor.dart';
import '../../../data/services/reloj.dart';
import '../../../domain/evento_de_app.dart';
import '../../../domain/fechas.dart';
import '../../../domain/models/turno.dart';
import '../../../domain/models/vecino.dart';
import '../../../domain/reglas_turnos.dart';
import '../../core/estado_carga.dart';
import '../../core/formato.dart';
import '../../core/marca_dia.dart';

class TurnosViewModel extends ChangeNotifier {
  TurnosViewModel({
    required TurnosRepository turnos,
    required this._sesion,
    required this._bus,
    required this._reloj,
    required DateTime mes,
  }) : _repositorio = turnos,
       mes = DateTime(mes.year, mes.month),
       _dia = DateTime(mes.year, mes.month) {
    _suscripcion = _bus.de<TurnosActualizados>().listen((_) => cargar());
  }

  final TurnosRepository _repositorio;
  final SesionRepository _sesion;
  final BusDeEventos _bus;
  final Reloj _reloj;
  StreamSubscription<TurnosActualizados>? _suscripcion;

  /// Mes que muestra el calendario.
  final DateTime mes;

  EstadoCarga _estado = EstadoCarga.inicial;
  EstadoCarga get estado => _estado;

  List<Turno> _turnos = [];
  bool _diaElegidoPorElUsuario = false;

  /// True mientras se anota o sale de un turno: los botones se desactivan.
  bool _ocupado = false;
  bool get ocupado => _ocupado;

  bool _soloMios = false;
  bool get soloMios => _soloMios;

  DateTime _dia;
  DateTime get dia => _dia;

  Vecino? get usuario => _sesion.usuario;

  bool get esGuardiaVentana =>
      usuario?.esGuardiaVentanaEn(_reloj.ahora()) ?? false;

  /// Turnos del vecino en el mes, por fecha y horario.
  List<Turno> get misTurnos {
    final u = usuario;
    if (u == null) return const [];
    final mios =
        _turnos.where((t) => t.incluye(u) && mismoMes(t.fecha, mes)).toList()
          ..sort((a, b) {
            final porFecha = a.fecha.compareTo(b.fecha);
            return porFecha != 0
                ? porFecha
                : a.franja.index.compareTo(b.franja.index);
          });
    return List.unmodifiable(mios);
  }

  Future<void> cargar() async {
    if (_estado != EstadoCarga.exito) {
      _estado = EstadoCarga.cargando;
      notifyListeners();
    }
    try {
      _turnos = await _repositorio.obtenerTurnos(mes);
      // La primera vez, el calendario abre en el primer turno propio.
      if (!_diaElegidoPorElUsuario) {
        final mios = misTurnos;
        if (mios.isNotEmpty) _dia = mios.first.fecha;
      }
      _estado = EstadoCarga.exito;
    } catch (_) {
      if (_estado != EstadoCarga.exito) _estado = EstadoCarga.error;
    } finally {
      notifyListeners();
    }
  }

  /// El turno de ese día y franja; vacío si nadie se anotó.
  Turno turno(DateTime dia, Franja franja) {
    for (final t in _turnos) {
      if (mismoDia(t.fecha, dia) && t.franja == franja) return t;
    }
    return Turno(fecha: dia, franja: franja);
  }

  MarcaDia marcaDe(DateTime dia) {
    final u = usuario;
    final delDia = Franja.values.map((f) => turno(dia, f));
    if (u != null && delDia.any((t) => t.incluye(u))) return MarcaDia.mia;
    if (delDia.any((t) => !t.vacio)) return MarcaDia.conTurnos;
    return MarcaDia.ninguna;
  }

  /// Por qué el vecino no puede anotarse en [turno], o null si puede.
  String? motivoNoDisponible(Turno turno) {
    final u = usuario;
    if (u == null) return 'Ingresá para anotarte.';
    return ReglasTurnos.motivoNoDisponible(
      vecino: u,
      turno: turno,
      turnosEnElMes: misTurnos.length,
      hoy: _reloj.ahora(),
    );
  }

  /// Líneas de texto de una tarjeta de "Mis turnos".
  List<String> detalleDe(Turno turno) {
    final u = usuario;
    if (u == null) return const [];
    final companieros = turno.companierosDe(u).map((v) => v.nombre).join(', ');
    final guardia = turno.guardiaVentana;
    if (esGuardiaVentana) {
      return [
        'Guardia de ventana desde tu casa',
        companieros.isEmpty
            ? 'Sin patrulla anotada todavía'
            : 'Patrulla: $companieros',
      ];
    }
    return [
      companieros.isEmpty ? 'Sin compañero todavía' : 'Con $companieros',
      if (guardia != null)
        'Guardia de ventana: ${guardia.nombre} (mayor de ${ReglasTurnos.edadGuardiaVentana})',
    ];
  }

  void elegirDia(DateTime dia) {
    _dia = dia;
    _diaElegidoPorElUsuario = true;
    notifyListeners();
  }

  void mostrarSoloMios(bool soloMios) {
    _soloMios = soloMios;
    notifyListeners();
  }

  /// Desde "Mis turnos": vuelve al calendario en ese día.
  void verEnCalendario(DateTime dia) {
    _soloMios = false;
    elegirDia(dia);
  }

  /// Devuelve el mensaje para mostrarle al vecino, haya salido bien o no.
  Future<String> anotarse(Turno turno) => _accion(
    () => _repositorio.anotarse(usuario!, turno.fecha, turno.franja),
    'Te anotaste: ${fechaLarga(turno.fecha)}, ${turno.franja.horario}',
  );

  Future<String> salir(Turno turno) => _accion(
    () => _repositorio.salir(usuario!, turno.fecha, turno.franja),
    'Saliste del turno del ${fechaLarga(turno.fecha).toLowerCase()}',
  );

  Future<String> _accion(
    Future<Turno> Function() pedido,
    String mensajeExito,
  ) async {
    if (usuario == null) return 'Ingresá para anotarte.';
    _ocupado = true;
    notifyListeners();
    try {
      await pedido();
      _turnos = await _repositorio.obtenerTurnos(mes);
      _bus.publicar(const TurnosActualizados());
      return mensajeExito;
    } on ErrorDelServidor catch (e) {
      return e.mensaje;
    } catch (_) {
      return 'No pudimos guardar el cambio. Revisá tu conexión y probá de nuevo.';
    } finally {
      _ocupado = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _suscripcion?.cancel();
    super.dispose();
  }
}
