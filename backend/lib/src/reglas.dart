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

/// Reglas para crear una alerta nueva. Son las mismas que aplica la app
/// (lib/domain/reglas_alertas.dart), con los mismos mensajes, y se copian
/// por la misma razón que [ReglasTurnos]. Si cambia una regla, hay que
/// cambiarla en los dos lados.
class ReglasAlertas {
  static const maxTitulo = 60;
  static const maxDescripcion = 500;
  static const maxDireccion = 120;

  /// Las que se pueden crear: `sos` (el botón SOS) y los tipos de
  /// "Reportar alerta". `arrebato` ya no se crea; las alertas viejas de
  /// arrebato se siguen leyendo.
  static const categorias = {
    'sos',
    'actividad_sospechosa',
    'vehiculo',
    'robo',
    'ruidos',
  };

  static const mensajeCategoria = 'Elegí qué tipo de alerta es.';
  static const mensajeTituloVacio = 'Escribí un título para la alerta.';
  static const mensajeTituloLargo =
      'Acortá el título: puede tener hasta $maxTitulo letras.';
  static const mensajeDescripcionLarga =
      'Acortá la descripción: puede tener hasta $maxDescripcion letras.';
  static const mensajeDireccionLarga =
      'Acortá la dirección: puede tener hasta $maxDireccion letras.';

  /// Letras sin los espacios de los extremos (runas, igual que la app).
  static int largo(String texto) => texto.trim().runes.length;

  /// El primer motivo para rechazar una alerta nueva, o null si es válida.
  /// Orden: categoría, título, descripción, dirección.
  static String? motivoRechazo({
    required String categoria,
    required String tipo,
    required String descripcion,
    required String direccion,
  }) {
    if (!categorias.contains(categoria)) return mensajeCategoria;
    if (tipo.trim().isEmpty) return mensajeTituloVacio;
    if (largo(tipo) > maxTitulo) return mensajeTituloLargo;
    if (largo(descripcion) > maxDescripcion) return mensajeDescripcionLarga;
    if (largo(direccion) > maxDireccion) return mensajeDireccionLarga;
    return null;
  }
}
