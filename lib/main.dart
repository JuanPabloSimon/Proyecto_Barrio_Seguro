import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';

import 'configuracion.dart';
import 'data/services/local/alertas_dao.dart';
import 'data/services/local/base_de_datos.dart';
import 'data/services/local/pendientes_dao.dart';
import 'data/services/local/turnos_dao.dart';
import 'data/services/notificaciones_service.dart';
import 'data/services/tareas/tarea_de_fondo.dart';
import 'data/services/tareas/tareas_service.dart';
import 'dependencias.dart';
import 'plataforma/capacidades.dart';
import 'ui/core/tema/app_theme.dart';
import 'ui/core/widgets/con_view_model.dart';
import 'ui/login/view_models/login_view_model.dart';
import 'ui/login/widgets/login_screen.dart';
import 'ui/principal/widgets/principal_screen.dart';

/// Arma las piezas una sola vez, de abajo hacia arriba, y arranca la app.
/// Es el único lugar que sabe cómo está conectado todo.
Future<void> main() async {
  // Los plugins (preferencias, base, almacenamiento seguro) hablan con la
  // plataforma: ese canal existe recién cuando hay binding.
  WidgetsFlutterBinding.ensureInitialized();

  const capacidades = Capacidades();
  final base = capacidades.tieneBaseDeDatosLocal ? await _abrirBase() : null;

  final alertasDao = base == null ? null : AlertasDao(base);
  final turnosDao = base == null ? null : TurnosDao(base);
  final pendientesDao = base == null ? null : PendientesDao(base);

  final notificaciones = capacidades.muestraNotificaciones
      ? NotificacionesServiceLocales()
      : const NotificacionesServiceNinguno();
  await _intentar(notificaciones.inicializar);

  // workmanager necesita saber, antes de todo, dónde arranca la tarea de
  // fondo (callbackDispatcher).
  final tareas = capacidades.correTareasEnSegundoPlano
      ? const TareasConWorkmanager()
      : const TareasNinguna();
  if (capacidades.correTareasEnSegundoPlano) {
    await _intentar(() => Workmanager().initialize(callbackDispatcher));
  }

  // Sin API_URL, la app usa el servidor simulado (no hace falta internet).
  // Con el backend andando en la PC, desde el emulador de Android:
  //   flutter run --dart-define=API_URL=http://10.0.2.2:8080
  final dependencias = urlApi.isEmpty
      ? Dependencias.simuladas(
          capacidades: capacidades,
          notificaciones: notificaciones,
          tareas: tareas,
          alertasDao: alertasDao,
          turnosDao: turnosDao,
          pendientesDao: pendientesDao,
        )
      : Dependencias.conApi(
          urlBase: Uri.parse(urlApi),
          capacidades: capacidades,
          notificaciones: notificaciones,
          tareas: tareas,
          alertasDao: alertasDao,
          turnosDao: turnosDao,
          pendientesDao: pendientesDao,
        );
  // Si el vecino ya había ingresado, la app abre directo en el inicio.
  await dependencias.sesion.restaurar();

  runApp(BarrioSeguroApp(dependencias: dependencias));
}

/// Lo que falle al preparar un plugin no impide abrir la app.
Future<void> _intentar(Future<void> Function() preparar) async {
  try {
    await preparar();
  } catch (_) {}
}

/// Si la base no abre, la app sigue sin la copia para usar sin conexión.
Future<Database?> _abrirBase() async {
  try {
    return await abrirBaseDelDispositivo();
  } catch (_) {
    return null;
  }
}

class BarrioSeguroApp extends StatelessWidget {
  const BarrioSeguroApp({super.key, required this.dependencias});

  final Dependencias dependencias;

  @override
  Widget build(BuildContext context) {
    final conSesion = dependencias.sesion.usuario != null;
    return MaterialApp(
      title: 'Barrio Seguro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: conSesion
          ? PrincipalScreen(dependencias: dependencias)
          : ConViewModel(
              crear: () => LoginViewModel(sesion: dependencias.sesion),
              builder: (_, vm) =>
                  LoginScreen(viewModel: vm, dependencias: dependencias),
            ),
    );
  }
}
