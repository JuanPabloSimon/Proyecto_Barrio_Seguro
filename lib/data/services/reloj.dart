/// La hora también es una dependencia: así las pruebas pueden fijarla.
abstract class Reloj {
  DateTime ahora();
}

class RelojDelSistema implements Reloj {
  const RelojDelSistema();

  @override
  DateTime ahora() => DateTime.now();
}

/// Siempre devuelve la misma hora. Para pruebas.
class RelojFijo implements Reloj {
  const RelojFijo(this.hora);

  final DateTime hora;

  @override
  DateTime ahora() => hora;
}
