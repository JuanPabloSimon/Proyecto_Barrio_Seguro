/// Pregunta si la app llega a su servidor. No mira el wifi: hay wifi sin
/// internet (portales de acceso) e internet sin servidor.
abstract class ConexionService {
  /// true solo si el servidor respondió que está bien. Nunca lanza: ante
  /// cualquier falla devuelve false.
  Future<bool> hayConexion();

  /// Hora del servidor menos hora del teléfono según la última respuesta
  /// de /salud; null si nunca se pudo medir.
  Duration? get desfase;
}
