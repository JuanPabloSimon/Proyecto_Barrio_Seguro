import 'package:flutter/foundation.dart';

import '../../../data/repositories/alertas_repository.dart';
import '../../../data/repositories/sesion_repository.dart';
import '../../../data/services/bus_de_eventos.dart';
import '../../../domain/barrio.dart';
import '../../../domain/evento_de_app.dart';
import '../../../domain/models/alerta.dart';

/// Los pasos de la pantalla SOS.
enum PasoSos { confirmar, enviando, enviada, error }

class SosViewModel extends ChangeNotifier {
  SosViewModel({
    required AlertasRepository alertas,
    required this._sesion,
    required this._bus,
  }) : _repositorio = alertas;

  final AlertasRepository _repositorio;
  final SesionRepository _sesion;
  final BusDeEventos _bus;

  PasoSos _paso = PasoSos.confirmar;
  PasoSos get paso => _paso;

  Alerta? _enviada;

  /// Envía la alerta a los vecinos. Por ahora con la ubicación del centro
  /// del barrio; con el GPS será la posición real del teléfono.
  Future<void> enviar() async {
    _paso = PasoSos.enviando;
    notifyListeners();
    try {
      _enviada = await _repositorio.crearAlerta(
        categoria: CategoriaAlerta.sos,
        tipo: 'Pedido de ayuda (SOS)',
        descripcion: 'Un vecino pidió ayuda con el botón SOS.',
        direccion: Barrio.nombre,
        ubicacion: Barrio.centro,
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
