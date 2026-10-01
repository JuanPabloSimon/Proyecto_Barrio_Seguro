import '../utils/fechas.dart';

class Vecino {
  Vecino({
    required this.id,
    required this.nombre,
    required this.fechaNacimiento,
    this.telefono = '',
    this.calle = '',
    this.cuadra = '',
    this.antiguedad = '',
  });

  /// Desde esta edad el vecino no patrulla: hace guardia de ventana.
  static const edadGuardiaVentana = 70;

  final String id;
  final String nombre;
  final DateTime fechaNacimiento;
  final String telefono;
  final String calle;
  final String cuadra;
  final String antiguedad;

  int get edad => calcularEdad(fechaNacimiento);

  bool get esGuardiaVentana => edad >= edadGuardiaVentana;

  String get rol => esGuardiaVentana ? 'Guardia de ventana' : 'Patrullaje';

  String get primerNombre => nombre.trim().split(RegExp(r'\s+')).first;

  String get iniciales {
    final partes = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    return partes.take(2).map((p) => p[0].toUpperCase()).join();
  }
}
