import 'vecino.dart';

enum Franja {
  temprano('20:00 - 22:00'),
  noche('22:00 - 00:00'),
  madrugada('00:00 - 02:00');

  const Franja(this.horario);

  final String horario;
}

/// Un turno es un día + una franja horaria. Lo cubren hasta dos vecinos
/// patrullando y, opcionalmente, un guardia de ventana (mayor de 70).
class Turno {
  Turno({
    required this.fecha,
    required this.franja,
    List<Vecino> patrulleros = const [],
    this.guardiaVentana,
  }) : patrulleros = [...patrulleros];

  final DateTime fecha;
  final Franja franja;
  final List<Vecino> patrulleros;
  Vecino? guardiaVentana;

  bool get vacio => patrulleros.isEmpty && guardiaVentana == null;

  bool incluye(Vecino vecino) =>
      patrulleros.any((p) => p.id == vecino.id) || guardiaVentana?.id == vecino.id;

  List<Vecino> companierosDe(Vecino vecino) =>
      patrulleros.where((p) => p.id != vecino.id).toList();
}
