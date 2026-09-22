class Turno {
  const Turno({
    required this.dia,
    required this.diaCorto,
    required this.diaNumero,
    required this.mes,
    required this.horario,
    required this.vecinos,
    this.esMio = false,
  });

  final String dia;
  final String diaCorto;
  final int diaNumero;
  final String mes;
  final String horario;
  final List<String> vecinos;
  final bool esMio;
}
