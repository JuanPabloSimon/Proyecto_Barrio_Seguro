import '../models/vecino.dart';
import 'datos_demo.dart';

/// Usuario que tiene la sesión abierta. Lo define el login o el registro.
class Sesion {
  Sesion._();

  static Vecino usuario = vecinoClara;

  /// Vuelve al usuario de ejemplo. Lo usan los tests.
  static void reiniciar() => usuario = vecinoClara;
}
