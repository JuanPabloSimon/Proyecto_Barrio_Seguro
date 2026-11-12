import 'package:flutter/foundation.dart';

import '../../../data/repositories/sesion_repository.dart';
import '../../../data/services/bus_de_eventos.dart';
import '../../../domain/evento_de_app.dart';
import '../../../domain/models/vecino.dart';
import '../../core/estado_carga.dart';

class EditarPerfilViewModel extends ChangeNotifier {
  EditarPerfilViewModel({required this._sesion, required this._bus});

  final SesionRepository _sesion;
  final BusDeEventos _bus;

  Vecino? get usuario => _sesion.usuario;

  /// La cuadra sin la palabra "Cuadra", para editar solo el número.
  String get numeroDeCuadra =>
      usuario?.cuadra.replaceFirst('Cuadra ', '') ?? '';

  EstadoCarga _estado = EstadoCarga.inicial;
  EstadoCarga get estado => _estado;

  String? _error;
  String? get error => _error;

  String? _errorNombre;
  String? get errorNombre => _errorNombre;

  /// Devuelve true si se guardaron los cambios.
  Future<bool> guardar({
    required String nombre,
    required String telefono,
    required String calle,
    required String cuadra,
  }) async {
    final actual = usuario;
    if (actual == null) return false;
    if (nombre.trim().isEmpty) {
      _errorNombre = 'Ingresá tu nombre';
      notifyListeners();
      return false;
    }

    _estado = EstadoCarga.cargando;
    _error = null;
    _errorNombre = null;
    notifyListeners();
    try {
      final numero = cuadra.trim();
      await _sesion.actualizarDatos(
        actual.copyWith(
          nombre: nombre.trim(),
          telefono: telefono.trim(),
          calle: calle.trim(),
          cuadra: numero.isEmpty ? '' : 'Cuadra $numero',
        ),
      );
      _estado = EstadoCarga.exito;
      _bus.publicar(const PerfilActualizado());
      return true;
    } catch (_) {
      _estado = EstadoCarga.error;
      _error = 'No pudimos guardar los cambios. Revisá tu conexión y probá de nuevo.';
      return false;
    } finally {
      notifyListeners();
    }
  }
}
