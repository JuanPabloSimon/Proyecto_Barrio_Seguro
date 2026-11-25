import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:workmanager/workmanager.dart';

import '../../../configuracion.dart';
import '../alertas_service.dart';
import '../http/alertas_service_http.dart';
import '../http/cliente_api.dart';
import '../local/alertas_dao.dart';
import '../local/almacen_seguro.dart';
import '../local/base_de_datos.dart';
import '../local/pendientes_dao.dart';
import '../reloj.dart';
import '../simulados/alertas_service_simulado.dart';
import '../simulados/servidor_simulado.dart';
import 'envio_de_pendientes.dart';

/// Nombre de la tarea (qué hacer). El nombre único del registro está en
/// TareasConWorkmanager.
const tareaEnviarPendientes = 'enviar-pendientes';

/// Ejecuta la tarea de segundo plano [tarea] sobre la base local [db].
///
/// Si no se pasa [servicio], usa la API real cuando [urlApi] está definida
/// o un servidor simulado local cuando corre sin backend externo.
Future<bool> ejecutarTareaDeFondo(
  String tarea, {
  required Database db,
  AlertasService? servicio,
  String? urlBaseApi,
}) async {
  if (tarea != tareaEnviarPendientes) return true;

  final direccionApi = urlBaseApi ?? urlApi;
  final destino =
      servicio ??
      (direccionApi.isNotEmpty
          ? AlertasServiceHttp(
              ClienteApi(
                base: Uri.parse(direccionApi),
                almacen: AlmacenSeguro(const FlutterSecureStorage()),
              ),
            )
          : AlertasServiceSimulado(
              ServidorSimulado(
                reloj: const RelojDelSistema(),
                demora: Duration.zero,
              ),
            ));

  return enviarAlertasPendientes(
    pendientes: PendientesDao(db),
    servicio: destino,
    copiaLocal: AlertasDao(db),
  );
}

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
    // Los canales nativos (sqflite, flutter_secure_storage) necesitan el
    // binding de Flutter y el registro de plugins en este isolate.
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    final db = await abrirBaseDelDispositivo();
    try {
      return await ejecutarTareaDeFondo(tarea, db: db);
    } finally {
      await db.close();
    }
  });
}
