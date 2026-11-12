import 'package:flutter/foundation.dart';

import '../../../data/repositories/sesion_repository.dart';
import '../../../data/services/reloj.dart';
import '../../../domain/fechas.dart';
import '../../../domain/reglas_turnos.dart';
import '../../core/estado_carga.dart';

class RegistroViewModel extends ChangeNotifier {
  RegistroViewModel({required this._sesion, required this._reloj});

  final SesionRepository _sesion;
  final Reloj _reloj;

  String _nombre = '';
  String _textoFecha = '';
  DateTime? _fechaNacimiento;
  bool _mostrarErrores = false;

  EstadoCarga _estado = EstadoCarga.inicial;
  EstadoCarga get estado => _estado;

  String? _errorDelServidor;
  String? get errorDelServidor => _errorDelServidor;

  /// Edad según la fecha ingresada, o null si todavía no es válida.
  int? get edad {
    final fecha = _fechaNacimiento;
    return fecha == null ? null : calcularEdad(fecha, hoy: _reloj.ahora());
  }

  /// El rol en los turnos depende de la edad: se le muestra al vecino
  /// apenas escribe una fecha válida.
  bool get seraGuardiaVentana {
    final edad = this.edad;
    return edad != null && ReglasTurnos.esGuardiaVentana(edad);
  }

  String? get errorNombre =>
      _mostrarErrores && _nombre.trim().isEmpty ? 'Ingresá tu nombre' : null;

  String? get errorFecha {
    final completa = _textoFecha.length == 10;
    if (completa && _fechaNacimiento == null) {
      return 'La fecha no es válida. Escribila como día/mes/año, por ejemplo 14/05/1950';
    }
    if (_mostrarErrores && _fechaNacimiento == null) {
      return 'Ingresá tu fecha de nacimiento';
    }
    return null;
  }

  void cambiarNombre(String nombre) {
    _nombre = nombre;
    notifyListeners();
  }

  void cambiarFecha(String texto) {
    _textoFecha = texto;
    _fechaNacimiento = parsearFecha(texto, hoy: _reloj.ahora());
    notifyListeners();
  }

  /// Devuelve true si se creó la cuenta.
  Future<bool> registrar({
    required String telefono,
    required String calle,
    required String cuadra,
    required String codigoComision,
  }) async {
    final fecha = _fechaNacimiento;
    if (_nombre.trim().isEmpty || fecha == null) {
      _mostrarErrores = true;
      notifyListeners();
      return false;
    }

    _estado = EstadoCarga.cargando;
    _errorDelServidor = null;
    notifyListeners();
    try {
      final numeroCuadra = cuadra.trim();
      await _sesion.registrar(
        nombre: _nombre.trim(),
        fechaNacimiento: fecha,
        telefono: telefono.trim(),
        calle: calle.trim(),
        cuadra: numeroCuadra.isEmpty ? '' : 'Cuadra $numeroCuadra',
        codigoComision: codigoComision.trim(),
      );
      _estado = EstadoCarga.exito;
      return true;
    } catch (_) {
      _estado = EstadoCarga.error;
      _errorDelServidor =
          'No pudimos crear la cuenta. Revisá tu conexión y probá de nuevo.';
      return false;
    } finally {
      notifyListeners();
    }
  }
}
