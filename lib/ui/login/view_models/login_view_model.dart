import 'package:flutter/foundation.dart';

import '../../../data/repositories/sesion_repository.dart';
import '../../core/estado_carga.dart';

class LoginViewModel extends ChangeNotifier {
  LoginViewModel({required this._sesion});

  final SesionRepository _sesion;

  EstadoCarga _estado = EstadoCarga.inicial;
  EstadoCarga get estado => _estado;

  String? _error;
  String? get error => _error;

  /// Devuelve true si pudo ingresar; la pantalla decide a dónde ir.
  Future<bool> ingresar({
    required String usuario,
    required String clave,
  }) async {
    _estado = EstadoCarga.cargando;
    _error = null;
    notifyListeners();
    try {
      await _sesion.ingresar(usuario: usuario.trim(), clave: clave);
      _estado = EstadoCarga.exito;
      return true;
    } catch (_) {
      _estado = EstadoCarga.error;
      _error = 'No pudimos ingresar. Revisá tu conexión y probá de nuevo.';
      return false;
    } finally {
      notifyListeners();
    }
  }
}
