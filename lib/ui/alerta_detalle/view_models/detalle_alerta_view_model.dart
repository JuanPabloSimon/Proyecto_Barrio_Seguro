import 'package:flutter/foundation.dart';

import '../../../data/repositories/alertas_repository.dart';
import '../../../data/repositories/avisos_recibidos_repository.dart';
import '../../../data/repositories/sesion_repository.dart';
import '../../../data/services/bus_de_eventos.dart';
import '../../../data/services/reloj.dart';
import '../../../domain/avisos_tardios.dart';
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
    required this._avisos,
  }) : _repositorio = alertas;

  final AlertasRepository _repositorio;
  final SesionRepository _sesion;
  final BusDeEventos _bus;
  final Reloj _reloj;
  final AvisosRecibidosRepository _avisos;

  Alerta _alerta;
  Alerta get alerta => _alerta;

  EstadoCarga _estado = EstadoCarga.inicial;
  EstadoCarga get estado => _estado;

  String? _error;
  String? get error => _error;

  String get hace => tiempoTranscurrido(_alerta.creadaEn, _reloj.ahora());

  bool get esMia => _alerta.reportadaPor == _sesion.usuario?.id;

  /// "Vos" si es propia; si no, `alerta.reportadaPorNombre`, o "Un vecino"
  /// si está vacío (R32, R33, R34).
  String get reportadaPor {
    if (esMia) return 'Vos';
    final nombre = _alerta.reportadaPorNombre.trim();
    return nombre.isEmpty ? 'Un vecino' : nombre;
  }

  /// Cuándo llegó a este teléfono el aviso de esta alerta; null si no hay.
  DateTime? _llegada;

  /// Texto de la marca o null si no es tardía (R24, R25).
  String? get tardia {
    final llegada = _llegada;
    if (llegada == null) return null;
    final puntualidad = clasificarAviso(
      creadaEn: _alerta.creadaEn,
      llegada: llegada,
    );
    if (!esTardia(puntualidad)) return null;
    return marcaTardia(creadaEn: _alerta.creadaEn, ahora: _reloj.ahora());
  }

  /// Lee la llegada guardada de esta alerta. Si no se puede leer, no hay
  /// marca.
  Future<void> cargarLlegada() async {
    try {
      _llegada = (await _avisos.llegadas())[_alerta.id];
    } catch (_) {
      _llegada = null;
    }
    // La pantalla se pudo cerrar mientras se leía.
    if (!_cerrado) notifyListeners();
  }

  bool _cerrado = false;

  @override
  void dispose() {
    _cerrado = true;
    super.dispose();
  }

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
