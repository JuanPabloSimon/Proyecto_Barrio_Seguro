import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/alertas_repository.dart';
import '../../../data/repositories/avisos_recibidos_repository.dart';
import '../../../data/services/bus_de_eventos.dart';
import '../../../data/services/reloj.dart';
import '../../../domain/avisos_tardios.dart';
import '../../../domain/evento_de_app.dart';
import '../../../domain/models/alerta.dart';
import '../../core/estado_carga.dart';
import '../../core/formato.dart';

class MapaViewModel extends ChangeNotifier {
  MapaViewModel({
    required AlertasRepository alertas,
    required BusDeEventos bus,
    required this._reloj,
    required this._avisos,
  }) : _repositorio = alertas {
    _suscripcion = bus.de<AlertasActualizadas>().listen((_) => cargar());
  }

  final AlertasRepository _repositorio;
  final Reloj _reloj;
  final AvisosRecibidosRepository _avisos;
  StreamSubscription<AlertasActualizadas>? _suscripcion;

  EstadoCarga _estado = EstadoCarga.inicial;
  EstadoCarga get estado => _estado;

  /// True si no hubo conexión y se muestran las alertas guardadas.
  bool get sinConexion => _repositorio.sinConexion;

  List<Alerta> _alertas = [];

  EstadoAlerta? _filtro;

  /// null significa "Todas".
  EstadoAlerta? get filtro => _filtro;

  /// Las alertas que pasan el filtro elegido.
  List<Alerta> get visibles => List.unmodifiable(
    _filtro == null ? _alertas : _alertas.where((a) => a.estado == _filtro),
  );

  String hace(Alerta alerta) =>
      tiempoTranscurrido(alerta.creadaEn, _reloj.ahora());

  /// Cuándo llegó a este teléfono el aviso de cada alerta.
  Map<String, DateTime> _llegadas = const {};

  /// Texto de la marca o null si no es tardía (R20, R25).
  String? tardia(Alerta alerta) {
    final llegada = _llegadas[alerta.id];
    if (llegada == null) return null;
    final puntualidad = clasificarAviso(
      creadaEn: alerta.creadaEn,
      llegada: llegada,
    );
    if (!esTardia(puntualidad)) return null;
    return marcaTardia(creadaEn: alerta.creadaEn, ahora: _reloj.ahora());
  }

  /// id → texto de la marca, para el mapa.
  Map<String, String> get tardias => {
    for (final alerta in _alertas) alerta.id: ?tardia(alerta),
  };

  /// Si no se pueden leer, no hay marcas: el mapa no deja de verse.
  Future<Map<String, DateTime>> _leerLlegadas() async {
    try {
      return await _avisos.llegadas();
    } catch (_) {
      return const {};
    }
  }

  void elegirFiltro(EstadoAlerta? filtro) {
    if (filtro == _filtro) return;
    _filtro = filtro;
    notifyListeners();
  }

  Future<void> cargar() async {
    if (_estado != EstadoCarga.exito) {
      _estado = EstadoCarga.cargando;
      notifyListeners();
    }
    try {
      _alertas = await _repositorio.obtenerAlertas();
      _llegadas = await _leerLlegadas();
      _estado = EstadoCarga.exito;
    } catch (_) {
      if (_estado != EstadoCarga.exito) _estado = EstadoCarga.error;
    } finally {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _suscripcion?.cancel();
    super.dispose();
  }
}
