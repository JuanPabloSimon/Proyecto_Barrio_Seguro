import 'package:flutter/foundation.dart';

import '../../../data/repositories/alertas_repository.dart';
import '../../../data/repositories/sesion_repository.dart';
import '../../../data/services/bus_de_eventos.dart';
import '../../../data/services/reloj.dart';
import '../../../domain/evento_de_app.dart';
import '../../../domain/models/alerta.dart';
import '../../core/estado_carga.dart';
import '../../core/formato.dart';

class DetalleAlertaViewModel extends ChangeNotifier {
  DetalleAlertaViewModel({
    required this._alerta,
    required AlertasRepository alertas,
    required this._sesion,
    required this._bus,
    required this._reloj,
  }) : _repositorio = alertas;

  final AlertasRepository _repositorio;
  final SesionRepository _sesion;
  final BusDeEventos _bus;
  final Reloj _reloj;

  Alerta _alerta;
  Alerta get alerta => _alerta;

  EstadoCarga _estado = EstadoCarga.inicial;
  EstadoCarga get estado => _estado;

  String? _error;
  String? get error => _error;

  String get hace => tiempoTranscurrido(_alerta.creadaEn, _reloj.ahora());

  bool get esMia => _alerta.reportadaPor == _sesion.usuario?.id;

  /// Solo quien la reportó puede cerrarla, y solo si sigue abierta (RF-05).
  bool get puedeCerrarla => esMia && _alerta.estado != EstadoAlerta.resuelta;

  Future<bool> marcarResuelta() => _cerrar();

  /// En el prototipo, una falsa alarma también queda como resuelta.
  Future<bool> marcarFalsaAlarma() => _cerrar();

  Future<bool> _cerrar() async {
    _estado = EstadoCarga.cargando;
    _error = null;
    notifyListeners();
    try {
      _alerta = await _repositorio.cambiarEstado(
        _alerta.id,
        EstadoAlerta.resuelta,
      );
      _estado = EstadoCarga.exito;
      _bus.publicar(const AlertasActualizadas());
      return true;
    } catch (_) {
      _estado = EstadoCarga.error;
      _error = 'No pudimos cerrar la alerta. Probá de nuevo.';
      return false;
    } finally {
      notifyListeners();
    }
  }
}
