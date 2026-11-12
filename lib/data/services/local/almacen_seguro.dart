import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secretos de la app, guardados cifrados con el llavero del sistema
/// (Keystore en Android, Keychain en iOS). Nunca en preferencias ni en la
/// base común: esos se guardan sin cifrar.
class AlmacenSeguro {
  AlmacenSeguro(this._almacen);

  final FlutterSecureStorage _almacen;

  static const claveToken = 'token_de_sesion';

  /// El token de la sesión abierta, o null si nadie ingresó.
  Future<String?> token() => _almacen.read(key: claveToken);

  Future<void> guardarToken(String token) =>
      _almacen.write(key: claveToken, value: token);

  Future<void> borrarToken() => _almacen.delete(key: claveToken);
}
