import 'package:workmanager/workmanager.dart';

import 'tarea_de_fondo.dart';

/// Encarga trabajo al sistema para que corra aunque la app esté cerrada.
abstract class TareasService {
  /// Pide mandar las alertas pendientes apenas haya conexión.
  Future<void> programarEnvioDePendientes();
}

/// Con workmanager (WorkManager de Android).
class TareasConWorkmanager implements TareasService {
  const TareasConWorkmanager();

  @override
  Future<void> programarEnvioDePendientes() {
    return Workmanager().registerOneOffTask(
      'envio-de-pendientes', // nombre único de este registro
      tareaEnviarPendientes, // qué hacer
      // No hace falta escuchar la conectividad: el sistema la corre
      // cuando hay red.
      constraints: Constraints(networkType: NetworkType.connected),
      // Si ya había una esperando, alcanza con esa: manda todas.
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );
  }
}

/// Donde no hay tareas de fondo: las pendientes se mandan cuando la app
/// vuelve a abrirse o a primer plano.
class TareasNinguna implements TareasService {
  const TareasNinguna();

  @override
  Future<void> programarEnvioDePendientes() async {}
}
