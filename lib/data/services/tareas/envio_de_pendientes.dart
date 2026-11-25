import '../../../domain/models/alerta.dart';
import '../alertas_service.dart';
import '../error_del_servidor.dart';
import '../local/alertas_dao.dart';
import '../local/pendientes_dao.dart';

/// Manda a la API, en orden, las alertas que quedaron sin enviar.
///
/// La usan la app (al abrirse o volver a primer plano) y la tarea de
/// fondo. Devuelve false si falló la red, para que workmanager vuelva a
/// intentar más tarde; true si no quedó nada que se pueda arreglar
/// reintentando.
///
/// Si se pasa [copiaLocal], cada alerta que el servidor acepta se guarda
/// también en la tabla `alertas` del dispositivo.
Future<bool> enviarAlertasPendientes({
  required PendientesDao pendientes,
  required AlertasService servicio,
  AlertasDao? copiaLocal,
}) async {
  for (final pendiente in await pendientes.listar()) {
    Map<String, dynamic>? creada;
    try {
      creada = await servicio.crearAlerta(pendiente.datos);
    } on ErrorDelServidor {
      // La API la rechazó: reintentar no la va a arreglar. Se descarta.
    } catch (_) {
      return false; // sin red: queda para el próximo intento
    }
    if (creada != null && copiaLocal != null) {
      try {
        await copiaLocal.guardar(Alerta.fromJson(creada));
      } catch (_) {}
    }
    await pendientes.borrar(pendiente.id);
  }
  return true;
}
