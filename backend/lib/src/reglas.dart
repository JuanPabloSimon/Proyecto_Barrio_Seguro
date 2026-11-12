/// Reglas de los turnos. Son las mismas que aplica la app
/// (lib/domain/reglas_turnos.dart), con los mismos mensajes: el servidor
/// las vuelve a aplicar porque no puede confiar solo en la app.
///
/// Están copiadas y no importadas porque la app es un paquete de Flutter y
/// el servidor corre con Dart puro. Si cambia una regla, hay que cambiarla
/// en los dos lados (las pruebas de cada lado lo verifican).
class ReglasTurnos {
  static const maxTurnosPorMes = 2;
  static const cupoPatrulla = 2;
  static const edadGuardiaVentana = 70;

  static const franjas = {'temprano', 'noche', 'madrugada'};

  static int edad(DateTime nacimiento, DateTime hoy) {
    var edad = hoy.year - nacimiento.year;
    final todaviaNoCumplio =
        hoy.month < nacimiento.month ||
        (hoy.month == nacimiento.month && hoy.day < nacimiento.day);
    if (todaviaNoCumplio) edad--;
    return edad;
  }

  static bool esGuardiaVentana(DateTime nacimiento, DateTime hoy) =>
      edad(nacimiento, hoy) >= edadGuardiaVentana;

  /// Por qué el vecino no puede anotarse en el turno, o null si puede.
  static String? motivoNoDisponible({
    required String vecinoId,
    required DateTime nacimiento,
    required List<String> patrulleros,
    required String? guardiaVentana,
    required int turnosEnElMes,
    required DateTime hoy,
  }) {
    if (patrulleros.contains(vecinoId) || guardiaVentana == vecinoId) {
      return null;
    }
    if (turnosEnElMes >= maxTurnosPorMes) {
      return 'Ya tenés $maxTurnosPorMes turnos este mes, que es el máximo permitido.';
    }
    if (esGuardiaVentana(nacimiento, hoy)) {
      if (guardiaVentana != null) {
        return 'Este turno ya tiene guardia de ventana.';
      }
    } else if (patrulleros.length >= cupoPatrulla) {
      return 'La patrulla de este turno ya está completa.';
    }
    return null;
  }
}
