import 'dart:convert';

import 'vecino.dart';

/// Franjas horarias en las que se patrulla.
enum Franja {
  temprano('20:00 - 22:00'),
  noche('22:00 - 00:00'),
  madrugada('00:00 - 02:00');

  const Franja(this.horario);

  final String horario;

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

  bool incluye(Vecino vecino) =>
      patrulleros.any((p) => p.id == vecino.id) ||
      guardiaVentana?.id == vecino.id;

  List<Vecino> companierosDe(Vecino vecino) =>
      patrulleros.where((p) => p.id != vecino.id).toList();

  /// Objeto -> fila de la tabla `turnos`.
  Map<String, Object?> toMap() {
    final guardia = guardiaVentana;
    return {
      // "2026-10-09": el texto ordena igual que la fecha.
      'fecha': fecha.toIso8601String().substring(0, 10),
      'franja': franja.name,
      'patrulleros': jsonEncode([for (final p in patrulleros) p.toJson()]),
      'guardia_ventana': guardia == null ? null : jsonEncode(guardia.toJson()),
    };
  }
}
