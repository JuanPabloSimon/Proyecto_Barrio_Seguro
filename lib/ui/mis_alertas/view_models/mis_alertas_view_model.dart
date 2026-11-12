import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/alertas_repository.dart';
import '../../../data/repositories/sesion_repository.dart';
import '../../../data/services/bus_de_eventos.dart';
import '../../../data/services/reloj.dart';
import '../../../domain/evento_de_app.dart';
import '../../../domain/models/alerta.dart';
import '../../core/estado_carga.dart';
import '../../core/formato.dart';

class MisAlertasViewModel extends ChangeNotifier {
  MisAlertasViewModel({
    required AlertasRepository alertas,
    required this._sesion,
    required BusDeEventos bus,
    required this._reloj,
  }) : _repositorio = alertas {
    _suscripcion = bus.de<AlertasActualizadas>().listen((_) => cargar());
  }

  final AlertasRepository _repositorio;
  final SesionRepository _sesion;
  final Reloj _reloj;
  StreamSubscription<AlertasActualizadas>? _suscripcion;

  EstadoCarga _estado = EstadoCarga.inicial;
  EstadoCarga get estado => _estado;

  List<Alerta> _mias = [];

  /// Las alertas que reportó el vecino con la sesión abierta.
  List<Alerta> get mias => List.unmodifiable(_mias);

  String hace(Alerta alerta) =>
      tiempoTranscurrido(alerta.creadaEn, _reloj.ahora());

  Future<void> cargar() async {
    if (_estado != EstadoCarga.exito) {
      _estado = EstadoCarga.cargando;
      notifyListeners();
    }
    try {
      final id = _sesion.usuario?.id;
      final alertas = await _repositorio.obtenerAlertas();
      _mias = alertas.where((a) => a.reportadaPor == id).toList();
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
