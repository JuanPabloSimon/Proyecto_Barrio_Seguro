import '../alertas_service.dart';
import '../error_del_servidor.dart';
import '../local/pendientes_dao.dart';

/// Manda a la API, en orden, las alertas que quedaron sin enviar.
///
/// La usan la app (al abrirse o volver a primer plano) y la tarea de
/// fondo. Devuelve false si falló la red, para que workmanager vuelva a
/// intentar más tarde; true si no quedó nada que se pueda arreglar
/// reintentando.
Future<bool> enviarAlertasPendientes({
  required PendientesDao pendientes,
  required AlertasService servicio,
}) async {
  for (final pendiente in await pendientes.listar()) {
    try {
      await servicio.crearAlerta(pendiente.datos);
    } on ErrorDelServidor {
      // La API la rechazó: reintentar no la va a arreglar. Se descarta.
    } catch (_) {
      return false; // sin red: queda para el próximo intento
    }
    await pendientes.borrar(pendiente.id);
  }
  return true;
}
