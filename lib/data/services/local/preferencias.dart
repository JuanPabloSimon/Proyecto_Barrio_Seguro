import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/models/vecino.dart';

/// Valores sueltos que tienen que sobrevivir al cierre de la app.
///
/// Todo el acceso a shared_preferences está en esta clase: el resto de la
/// app no conoce las claves ni el paquete. Usa SharedPreferencesAsync (sin
/// caché), como en la materia: cuando agreguemos tareas en segundo plano,
/// cada lectura ve lo último que se escribió.
class Preferencias {
  Preferencias(this._prefs);

  final SharedPreferencesAsync _prefs;

  // Las claves, como constantes: un error de tipeo en un String suelto no
  // avisa nada, simplemente lee null para siempre.
  static const claveCompartirUbicacion = 'compartir_ubicacion';
  static const claveNotificaciones = 'notificaciones';
  static const claveVecino = 'vecino';

  static const todasLasClaves = {
    claveCompartirUbicacion,
    claveNotificaciones,
    claveVecino,
  };

  /// Arranca apagado: la ubicación exacta se comparte recién cuando el
  /// vecino lo acepta.
  Future<bool> compartirUbicacion() async =>
      await _prefs.getBool(claveCompartirUbicacion) ?? false;

  Future<void> guardarCompartirUbicacion(bool valor) =>
      _prefs.setBool(claveCompartirUbicacion, valor);

  /// Arranca apagado: el permiso del sistema se pide recién cuando el
  /// vecino activa los avisos desde el perfil.
  Future<bool> notificaciones() async =>
      await _prefs.getBool(claveNotificaciones) ?? false;

  Future<void> guardarNotificaciones(bool valor) =>
      _prefs.setBool(claveNotificaciones, valor);

  /// Los datos del vecino que ingresó, para abrir la app sin conexión. No
  /// son secretos (el token va en el almacenamiento seguro).
  Future<Vecino?> vecino() async {
    final texto = await _prefs.getString(claveVecino);
    if (texto == null) return null;
    try {
      return Vecino.fromJson(jsonDecode(texto) as Map<String, dynamic>);
    } catch (_) {
      // Datos de una versión vieja de la app que ya no se pueden leer.
      return null;
    }
  }

  Future<void> guardarVecino(Vecino vecino) =>
      _prefs.setString(claveVecino, jsonEncode(vecino.toJson()));

  Future<void> olvidarVecino() => _prefs.remove(claveVecino);

  /// Borra solo las claves de esta clase, no las de otros paquetes.
  Future<void> olvidarTodo() => _prefs.clear(allowList: todasLasClaves);
}
