import 'package:flutter/foundation.dart';

import '../../../data/repositories/alertas_repository.dart';
import '../../../data/repositories/avisos_recibidos_repository.dart';
import '../../../data/repositories/sesion_repository.dart';
import '../../../data/services/bus_de_eventos.dart';
import '../../../data/services/error_del_servidor.dart';
import '../../../data/services/reloj.dart';
import '../../../domain/avisos_tardios.dart';
import '../../../domain/evento_de_app.dart';
import '../../../domain/models/alerta.dart';
import '../../../domain/reglas_alertas.dart';
import '../../core/estado_carga.dart';
import '../../core/formato.dart';
import '../../core/textos_estado.dart';

/// R17. Si el cambio de estado falla por la red.
const mensajeErrorCambioEstado =
    'No pudimos cambiar el estado. Probá de nuevo.';

/// R11. "Cambiaste el estado a En atención."
String avisoCambioDeEstado(EstadoAlerta estado) =>
    'Cambiaste el estado a ${estado.etiqueta}.';

/// Qué diálogo pide pasar de un estado a otro (decisión P2).
enum ConfirmacionCambioEstado { resolver, reabrir }

/// resolver: de Activa o En atención a Resuelta. reabrir: de Resuelta a
/// Activa o En atención. null: entre Activa y En atención o al mismo
/// estado (R7, R33, R34).
ConfirmacionCambioEstado? confirmacionParaCambio(
  EstadoAlerta actual,
  EstadoAlerta nuevo,
) {
  if (actual == nuevo) return null;
  if (nuevo == EstadoAlerta.resuelta) return ConfirmacionCambioEstado.resolver;
  if (actual == EstadoAlerta.resuelta) return ConfirmacionCambioEstado.reabrir;
  return null;
}

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

  /// R1, R2, R3: quien la reportó o un miembro de la comisión (RF-05
  /// ampliado), en cualquier estado (R6).
  bool get puedeCambiarEstado => ReglasAlertas.puedeCambiarEstado(
    reportadaPor: _alerta.reportadaPor,
    vecino: _sesion.usuario,
  );

  /// R20: solo quien la reportó, y solo si sigue abierta.
  bool get puedeMarcarFalsaAlarma =>
      esMia && _alerta.estado != EstadoAlerta.resuelta;

  /// True mientras se espera la respuesta de [cambiarEstado] o de
  /// [marcarFalsaAlarma] (R9): las dos acciones se deshabilitan juntas.
  bool get cambiandoEstado => _estado == EstadoCarga.cargando;

  /// Si [nuevo] es el estado actual, no tiene permiso o ya hay un cambio en
  /// curso, no hace nada y devuelve false (R8). Si el servidor confirma,
  /// reemplaza [alerta], publica AlertasActualizadas y devuelve true (R10).
  /// Si falla, deja [alerta] como estaba y llena [error] (R16, R17, R18).
  Future<bool> cambiarEstado(EstadoAlerta nuevo) async {
    if (nuevo == _alerta.estado || !puedeCambiarEstado || cambiandoEstado) {
      return false;
    }
    _estado = EstadoCarga.cargando;
    _error = null;
    notifyListeners();
    try {
      _alerta = await _repositorio.cambiarEstado(_alerta.id, nuevo);
      _estado = EstadoCarga.exito;
      _bus.publicar(const AlertasActualizadas());
      return true;
    } on ErrorDelServidor catch (e) {
      _estado = EstadoCarga.error;
      _error = e.mensaje;
      return false;
    } catch (_) {
      _estado = EstadoCarga.error;
      _error = mensajeErrorCambioEstado;
      return false;
    } finally {
      if (!_cerrado) notifyListeners();
    }
  }

  /// En el prototipo, una falsa alarma también queda como resuelta.
  Future<bool> marcarFalsaAlarma() async {
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
      if (!_cerrado) notifyListeners();
    }
  }
}
