import '../fechas.dart';
import '../reglas_turnos.dart';

/// Un vecino registrado en la red del barrio.
class Vecino {
  const Vecino({
    required this.id,
    required this.nombre,
    required this.fechaNacimiento,
    this.telefono = '',
    this.calle = '',
    this.cuadra = '',
    this.vecinoDesde,
  });

  factory Vecino.fromJson(Map<String, dynamic> json) {
    final desde = json['vecino_desde'] as String?;
    return Vecino(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      fechaNacimiento: DateTime.parse(json['fecha_nacimiento'] as String),
      telefono: json['telefono'] as String? ?? '',
      calle: json['calle'] as String? ?? '',
      cuadra: json['cuadra'] as String? ?? '',
      vecinoDesde: desde == null ? null : DateTime.parse(desde),
    );
  }

  final String id;
  final String nombre;
  final DateTime fechaNacimiento;
  final String telefono;
  final String calle;
  final String cuadra;

  /// Desde cuándo está en la red. Null si recién se registra.
  final DateTime? vecinoDesde;

  int edadEn(DateTime hoy) => calcularEdad(fechaNacimiento, hoy: hoy);

  /// Los mayores de 70 no patrullan: hacen guardia de ventana.
  bool esGuardiaVentanaEn(DateTime hoy) =>
      ReglasTurnos.esGuardiaVentana(edadEn(hoy));

  String get primerNombre => nombre.trim().split(RegExp(r'\s+')).first;

  String get iniciales {
    final partes = nombre
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty);
    return partes.take(2).map((p) => p[0].toUpperCase()).join();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'fecha_nacimiento': _soloFecha(fechaNacimiento),
    'telefono': telefono,
    'calle': calle,
    'cuadra': cuadra,
    if (vecinoDesde != null) 'vecino_desde': _soloFecha(vecinoDesde!),
  };

  Vecino copyWith({
    String? nombre,
    String? telefono,
    String? calle,
    String? cuadra,
  }) {
    return Vecino(
      id: id,
      nombre: nombre ?? this.nombre,
      fechaNacimiento: fechaNacimiento,
      telefono: telefono ?? this.telefono,
      calle: calle ?? this.calle,
      cuadra: cuadra ?? this.cuadra,
      vecinoDesde: vecinoDesde,
    );
  }
}

/// "2026-10-09": el formato de fechas sin hora que usa la API.
String _soloFecha(DateTime fecha) => fecha.toIso8601String().substring(0, 10);
