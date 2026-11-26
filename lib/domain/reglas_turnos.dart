import 'models/turno.dart';
import 'models/vecino.dart';

/// Reglas de negocio de los turnos, acordadas con la comisión vecinal.
/// Son funciones puras: se usan igual en la app y en el servidor.
class ReglasTurnos {
  ReglasTurnos._();

  /// Turnos que puede tomar cada vecino por mes.
  static const maxTurnosPorMes = 2;

  /// Vecinos que patrullan juntos en un turno.
  static const cupoPatrulla = 2;

  /// Desde esta edad el vecino no patrulla: hace guardia de ventana.
  static const edadGuardiaVentana = 70;

  /// Si por la edad le toca guardia de ventana (sin mirar la preferencia).
  static bool esGuardiaVentana(int edad) => edad >= edadGuardiaVentana;

  /// Desde [edadGuardiaVentana] el vecino puede elegir hacer guardia normal
  /// (patrulla) en lugar de guardia de ventana.
  static bool puedeElegirGuardiaNormal(int edad) => edad >= edadGuardiaVentana;

  /// Si al anotarse va a la guardia de ventana: mayor y sin guardia normal.
  static bool haceGuardiaVentana({
    required int edad,
    required bool guardiaNormal,
  }) => esGuardiaVentana(edad) && !guardiaNormal;

  /// El mismo mensaje que la API cuando un menor de 70 pide la guardia
  /// normal.
  static const mensajeGuardiaNormalSoloMayores =
      'Solo los vecinos de $edadGuardiaVentana años o más pueden elegir la '
      'guardia normal.';

  /// El mismo mensaje que la API cuando `guardia_normal` no es booleano.
  static const mensajeGuardiaNormalInvalida =
      'La opción de guardia normal no es válida.';

  /// Motivo por el que [vecino] no puede anotarse en [turno], o null si
  /// puede. [turnosEnElMes] es cuántos turnos ya tiene ese mes.
  static String? motivoNoDisponible({
    required Vecino vecino,
    required Turno turno,
    required int turnosEnElMes,
    required DateTime hoy,
  }) {
    if (turno.incluye(vecino)) return null;

    if (turnosEnElMes >= maxTurnosPorMes) {
      return 'Ya tenés $maxTurnosPorMes turnos este mes, que es el máximo permitido.';
    }
    if (vecino.esGuardiaVentanaEn(hoy)) {
      if (turno.guardiaVentana != null) {
        return 'Este turno ya tiene guardia de ventana.';
      }
    } else if (turno.patrulleros.length >= cupoPatrulla) {
      return 'La patrulla de este turno ya está completa.';
    }
    return null;
  }
}
