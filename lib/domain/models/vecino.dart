import '../fechas.dart';
import '../reglas_turnos.dart';

/// El rol del vecino en la red: vecino común o miembro de la comisión.
enum RolVecino {
  vecino,
  comision;

  /// El rol que viene en el JSON. Si falta o no se conoce, `vecino`: ante la
  /// duda, el vecino tiene menos permisos, no más.
  static RolVecino desdeJson(Object? valor) =>
      valor == 'comision' ? RolVecino.comision : RolVecino.vecino;

  /// El valor en el JSON de la API: `vecino` o `comision`.
  String get json => name;
}

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
    this.rol = RolVecino.vecino,
    this.guardiaNormal = false,
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
      rol: RolVecino.desdeJson(json['rol']),
      // Ante cualquier valor que no sea `true`, desactivada: es el valor por
      // defecto y no cambia nada.
      guardiaNormal: json['guardia_normal'] == true,
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

  final RolVecino rol;

  /// Un mayor de 70 que eligió hacer guardia normal (patrulla) en lugar de
  /// guardia de ventana. Lo guarda el servidor; para un menor no cambia
  /// nada.
  final bool guardiaNormal;

  /// Si es miembro de la comisión vecinal (ve las opciones de la comisión).
  bool get esComision => rol == RolVecino.comision;

  int edadEn(DateTime hoy) => calcularEdad(fechaNacimiento, hoy: hoy);

  /// Si al anotarse va a la guardia de ventana: los mayores de 70 que no
  /// eligieron la guardia normal.
  bool esGuardiaVentanaEn(DateTime hoy) => ReglasTurnos.haceGuardiaVentana(
    edad: edadEn(hoy),
    guardiaNormal: guardiaNormal,
  );

  /// Si ve la opción de guardia normal en el perfil.
  bool puedeElegirGuardiaNormalEn(DateTime hoy) =>
      ReglasTurnos.puedeElegirGuardiaNormal(edadEn(hoy));

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
    'rol': rol.json,
    'guardia_normal': guardiaNormal,
  };

  /// No recibe `rol` ni `guardiaNormal` a propósito: el rol no se cambia
  /// desde la app y la guardia normal se cambia solo con
  /// `SesionRepository.cambiarGuardiaNormal`.
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
      rol: rol,
      guardiaNormal: guardiaNormal,
    );
  }
}

/// "2026-10-09": el formato de fechas sin hora que usa la API.
String _soloFecha(DateTime fecha) => fecha.toIso8601String().substring(0, 10);
