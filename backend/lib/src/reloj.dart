/// De dónde sale la hora. En las pruebas se usa una fija, así las edades y
/// las fechas de las alertas dan siempre lo mismo.
abstract class Reloj {
  DateTime ahora();
}

class RelojDelSistema implements Reloj {
  const RelojDelSistema();

  @override
  DateTime ahora() => DateTime.now();
}

class RelojFijo implements Reloj {
  RelojFijo(this.hora);

  DateTime hora;

  @override
  DateTime ahora() => hora;
}
