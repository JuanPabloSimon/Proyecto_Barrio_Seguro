import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/repositories/alertas_repository.dart';
import '../../../data/repositories/sesion_repository.dart';
import '../../../data/services/bus_de_eventos.dart';
import '../../../data/services/local/preferencias.dart';
import '../../../data/services/ubicacion_service.dart';
import '../../../domain/barrio.dart';
import '../../../domain/evento_de_app.dart';
import '../../../domain/models/alerta.dart';
import '../../../plataforma/capacidades.dart';

/// Los pasos de la pantalla SOS.
enum PasoSos { confirmar, enviando, enviada, error }

class SosViewModel extends ChangeNotifier {
  SosViewModel({
    required AlertasRepository alertas,
    required this._sesion,
    required this._bus,
    required this._preferencias,
    required this._ubicacion,
    required this._capacidades,
  }) : _repositorio = alertas;

  final Preferencias _preferencias;
  final UbicacionService _ubicacion;
  final Capacidades _capacidades;

  bool _conUbicacionExacta = false;

  /// Si la alerta enviada llevó la posición del GPS o solo la zona del
  /// barrio.
  bool get conUbicacionExacta => _conUbicacionExacta;

  final AlertasRepository _repositorio;
  final SesionRepository _sesion;
  final BusDeEventos _bus;

  PasoSos _paso = PasoSos.confirmar;
  PasoSos get paso => _paso;

  Alerta? _enviada;

  /// Envía la alerta a los vecinos. Por ahora con la ubicación del centro
  /// Envía la alerta a los vecinos. Si el vecino aceptó compartir su
  /// ubicación exacta, va la del GPS; si no (o el GPS no responde a
  /// tiempo), la del centro del barrio como zona aproximada.
  Future<void> enviar() async {
    _paso = PasoSos.enviando;
    notifyListeners();
    try {
      final exacta = await _ubicacionExacta();
      _conUbicacionExacta = exacta != null;
      _enviada = await _repositorio.crearAlerta(
        categoria: CategoriaAlerta.sos,
        tipo: 'Pedido de ayuda (SOS)',
        descripcion: 'Un vecino pidió ayuda con el botón SOS.',
        direccion: exacta == null
            ? '${Barrio.nombre} (zona aproximada)'
            : 'Ubicación exacta del vecino',
        ubicacion: exacta ?? Barrio.centro,
        reportadaPor: _sesion.usuario?.id ?? '',
      );
      _paso = PasoSos.enviada;
      _bus.publicar(const AlertasActualizadas());
    } catch (_) {
      _paso = PasoSos.error;
    } finally {
      notifyListeners();
    }
  }

  Future<LatLng?> _ubicacionExacta() async {
    if (!_capacidades.tieneGps) return null;
    try {
      if (!await _preferencias.compartirUbicacion()) return null;
      return await _ubicacion.ubicacionActual();
    } catch (_) {
      return null;
    }
  }

  /// "Ya estoy a salvo" o "Fue una falsa alarma": la alerta queda resuelta.
  /// Devuelve true si se pudo cerrar.
  Future<bool> cerrarAlerta() async {
    final alerta = _enviada;
    if (alerta == null) return true;
    try {
      await _repositorio.cambiarEstado(alerta.id, EstadoAlerta.resuelta);
      _bus.publicar(const AlertasActualizadas());
      return true;
    } catch (_) {
      return false;
    }
  }
}
