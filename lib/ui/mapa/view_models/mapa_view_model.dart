import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/alertas_repository.dart';
import '../../../data/services/bus_de_eventos.dart';
import '../../../data/services/reloj.dart';
import '../../../domain/evento_de_app.dart';
import '../../../domain/models/alerta.dart';
import '../../core/estado_carga.dart';
import '../../core/formato.dart';

class MapaViewModel extends ChangeNotifier {
  MapaViewModel({
    required AlertasRepository alertas,
    required BusDeEventos bus,
    required this._reloj,
  }) : _repositorio = alertas {
    _suscripcion = bus.de<AlertasActualizadas>().listen((_) => cargar());
  }

  final AlertasRepository _repositorio;
  final Reloj _reloj;
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
