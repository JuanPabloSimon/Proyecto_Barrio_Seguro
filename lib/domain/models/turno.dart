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
}
