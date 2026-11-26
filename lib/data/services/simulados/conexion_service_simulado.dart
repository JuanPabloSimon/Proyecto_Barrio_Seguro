import '../conexion_service.dart';

/// El servidor simulado vive en memoria y no usa la red: no hay nada real
/// que comprobar. Responde lo que diga [conectado], que las pruebas (o una
/// demo) pueden poner en false para ver la pantalla sin conexión.
class ConexionServiceSimulado implements ConexionService {
  ConexionServiceSimulado({this.conectado = true});

  bool conectado;

  @override
  Future<bool> hayConexion() async => conectado;
}
