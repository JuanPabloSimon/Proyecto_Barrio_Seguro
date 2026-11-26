import 'dart:convert';

import 'vecino.dart';

/// Franjas horarias en las que se patrulla.
enum Franja {
  temprano('20:00 - 22:00', horaInicio: 20),
  noche('22:00 - 00:00', horaInicio: 22),
  madrugada('00:00 - 02:00', horaInicio: 0, empiezaAlDiaSiguiente: true);

  const Franja(
    this.horario, {
    required this.horaInicio,
    this.empiezaAlDiaSiguiente = false,
  });

  final String horario;

  /// Hora (0 a 23) en que empieza la franja.
  final int horaInicio;

  /// True si la franja de la fecha D empieza el día D+1 (la Madrugada: la
  /// noche del 9 al 10 es la madrugada del 9).
  final bool empiezaAlDiaSiguiente;

  /// Todas las franjas duran 2 horas.
  static const duracionEnHoras = 2;

  /// Inicio de la franja del turno de [fecha], hora local.
  ///
  /// Usa el constructor de `DateTime` con el día y la hora "desbordados"
  /// (Dart los pasa al día, mes o año siguiente) en vez de sumar
  /// `Duration` de 24 horas, que fallarían en un cambio de horario.
  DateTime inicioEn(DateTime fecha) => DateTime(
    fecha.year,
    fecha.month,
    fecha.day + (empiezaAlDiaSiguiente ? 1 : 0),
    horaInicio,
  );

  /// Fin de la franja del turno de [fecha] (excluido), hora local.
  DateTime finEn(DateTime fecha) => DateTime(
    fecha.year,
    fecha.month,
    fecha.day + (empiezaAlDiaSiguiente ? 1 : 0),
    horaInicio + duracionEnHoras,
  );

  /// Busca la franja por su nombre en la API; null si no existe.
  static Franja? desdeNombre(String nombre) {
    for (final franja in values) {
      if (franja.name == nombre) return franja;
    }
    return null;
  }
}

/// Un turno es un día más una franja horaria. Lo cubren hasta dos vecinos
/// patrullando y, opcionalmente, un guardia de ventana (mayor de 70).
class Turno {
  Turno({
    required this.fecha,
    required this.franja,
    List<Vecino> patrulleros = const [],
    this.guardiaVentana,
  }) : patrulleros = List.unmodifiable(patrulleros);

  factory Turno.fromJson(Map<String, dynamic> json) {
    final guardia = json['guardia_ventana'] as Map<String, dynamic>?;
    return Turno(
      fecha: DateTime.parse(json['fecha'] as String),
      franja: Franja.desdeNombre(json['franja'] as String) ?? Franja.noche,
      patrulleros: [
        for (final p in json['patrulleros'] as List<dynamic>)
          Vecino.fromJson(p as Map<String, dynamic>),
      ],
      guardiaVentana: guardia == null ? null : Vecino.fromJson(guardia),
    );
  }

  /// Fila de la tabla `turnos` -> objeto.
  ///
  /// Los vecinos del turno se guardan como JSON en una columna de texto:
  /// para una copia local alcanza, y evita una tabla aparte de vecinos.
  factory Turno.fromMap(Map<String, Object?> fila) {
    final guardia = fila['guardia_ventana'] as String?;
    return Turno.fromJson({
      'fecha': fila['fecha'],
      'franja': fila['franja'],
      'patrulleros': jsonDecode(fila['patrulleros'] as String),
      'guardia_ventana': guardia == null ? null : jsonDecode(guardia),
    });
  }

  final DateTime fecha;
  final Franja franja;
  final List<Vecino> patrulleros;
  final Vecino? guardiaVentana;

  bool get vacio => patrulleros.isEmpty && guardiaVentana == null;

  /// Patrulleros más el guardia de ventana, si hay: cuentan igual.
  int get personasAnotadas =>
      patrulleros.length + (guardiaVentana != null ? 1 : 0);

  /// Inicio de la franja de este turno, hora local.
  DateTime get inicio => franja.inicioEn(fecha);

  /// Fin de la franja de este turno (excluido), hora local.
  DateTime get fin => franja.finEn(fecha);

  bool incluye(Vecino vecino) =>
      patrulleros.any((p) => p.id == vecino.id) ||
      guardiaVentana?.id == vecino.id;

  List<Vecino> companierosDe(Vecino vecino) =>
      patrulleros.where((p) => p.id != vecino.id).toList();

  /// Objeto -> fila de la tabla `turnos`. Los vecinos van sin `rol`: en un
  /// turno no hace falta saber quién es de la comisión.
  Map<String, Object?> toMap() {
    final guardia = guardiaVentana;
    return {
      // "2026-10-09": el texto ordena igual que la fecha.
      'fecha': fecha.toIso8601String().substring(0, 10),
      'franja': franja.name,
      'patrulleros': jsonEncode([for (final p in patrulleros) _sinRol(p)]),
      'guardia_ventana': guardia == null ? null : jsonEncode(_sinRol(guardia)),
    };
  }

  static Map<String, dynamic> _sinRol(Vecino v) => v.toJson()..remove('rol');
}
