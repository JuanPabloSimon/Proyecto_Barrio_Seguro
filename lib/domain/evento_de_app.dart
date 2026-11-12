/// Eventos que le interesan a varias pantallas a la vez. Viajan por el
/// `BusDeEventos`: quien publica no sabe quién escucha.
sealed class EventoDeApp {
  const EventoDeApp();
}

/// Alguien se anotó o salió de un turno.
class TurnosActualizados extends EventoDeApp {
  const TurnosActualizados();
}

/// Se creó una alerta o cambió su estado.
class AlertasActualizadas extends EventoDeApp {
  const AlertasActualizadas();
}

/// Cambiaron los datos del vecino que tiene la sesión abierta.
class PerfilActualizado extends EventoDeApp {
  const PerfilActualizado();
}
