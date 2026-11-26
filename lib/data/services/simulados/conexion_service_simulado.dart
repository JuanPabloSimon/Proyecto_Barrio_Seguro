import '../conexion_service.dart';

/// El servidor simulado vive en memoria y no usa la red: no hay nada real
/// que comprobar. Responde lo que diga [conectado], que las pruebas (o una
/// demo) pueden poner en false para ver la pantalla sin conexión.
class ConexionServiceSimulado implements ConexionService {
  ConexionServiceSimulado({this.conectado = true});

  bool conectado;

  /// El servidor simulado usa el mismo reloj que la app: desfase cero. Las
  /// pruebas lo pueden cambiar.
  @override
  Duration? desfase = Duration.zero;

  @override
  Future<bool> hayConexion() async => conectado;
}
