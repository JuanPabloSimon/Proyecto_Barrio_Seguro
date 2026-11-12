import 'package:url_launcher/url_launcher.dart';

/// Abre la app de teléfono del dispositivo.
abstract class TelefonoService {
  /// Abre el teléfono con [numero] ya marcado; la persona confirma la
  /// llamada ahí. Devuelve false si no se pudo abrir.
  Future<bool> abrirMarcador(String numero);
}

/// Usa el plugin url_launcher con un link `tel:`.
///
/// Abre el marcador en lugar de llamar directamente: ni Android ni iOS
/// dejan que una app llame sola a un número de emergencias, y así la
/// persona ve el número antes de llamar.
class TelefonoServiceUrlLauncher implements TelefonoService {
  const TelefonoServiceUrlLauncher();

  @override
  Future<bool> abrirMarcador(String numero) async {
    try {
      return await launchUrl(Uri(scheme: 'tel', path: numero));
    } catch (_) {
      return false;
    }
  }
}
