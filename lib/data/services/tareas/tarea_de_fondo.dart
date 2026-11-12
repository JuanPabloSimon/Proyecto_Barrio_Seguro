import 'dart:ui';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:workmanager/workmanager.dart';

import '../../../configuracion.dart';
import '../http/alertas_service_http.dart';
import '../http/cliente_api.dart';
import '../local/almacen_seguro.dart';
import '../local/base_de_datos.dart';
import '../local/pendientes_dao.dart';
import 'envio_de_pendientes.dart';

/// Nombre de la tarea (qué hacer). El nombre único del registro está en
/// TareasConWorkmanager.
const tareaEnviarPendientes = 'enviar-pendientes';

/// Punto de entrada de las tareas de fondo.
///
/// - Es de nivel superior: el sistema la busca por nombre.
/// - Lleva @pragma('vm:entry-point'): nadie la llama desde la app, y sin
///   la anotación el compilador la borraría en release.
/// - Corre en otro isolate: no ve nada de la memoria de la app. Todo lo
///   que necesita lo lee de la base, del almacenamiento seguro y de la
///   constante [urlApi].
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((tarea, _) async {
    // Los plugins hay que registrarlos en este isolate.
    DartPluginRegistrant.ensureInitialized();
    if (tarea != tareaEnviarPendientes) return true;
    // Con el servidor simulado no hay a quién mandarlas: las manda la app
    // la próxima vez que se abre.
    if (urlApi.isEmpty) return true;

    final db = await abrirBaseDelDispositivo();
    try {
      final api = ClienteApi(
        base: Uri.parse(urlApi),
        almacen: AlmacenSeguro(const FlutterSecureStorage()),
      );
      return await enviarAlertasPendientes(
        pendientes: PendientesDao(db),
        servicio: AlertasServiceHttp(api),
      );
    } finally {
      await db.close();
    }
  });
}
