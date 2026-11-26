import 'package:flutter/material.dart';

import 'configuracion.dart';
import 'data/services/local/alertas_dao.dart';
import 'data/services/local/base_de_datos.dart';
import 'data/services/local/turnos_dao.dart';
import 'data/services/notificaciones_service.dart';
import 'data/services/push_service.dart';
import 'dependencias.dart';
import 'plataforma/capacidades.dart';
import 'ui/conexion/view_models/conexion_view_model.dart';
import 'ui/conexion/widgets/atras_sin_conexion.dart';
import 'ui/conexion/widgets/compuerta_de_conexion.dart';
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

  final notificaciones = capacidades.muestraNotificaciones
      ? NotificacionesServiceLocales()
      : const NotificacionesServiceNinguno();
  await _intentar(notificaciones.inicializar);

  final push = capacidades.recibeAvisosPush
      ? PushServiceFirebase()
      : const PushServiceNinguno();
  await _intentar(push.inicializar);

  // Sin API_URL, la app usa el servidor simulado (no hace falta internet).
  // Con el backend andando en la PC, desde el emulador de Android:
  //   flutter run --dart-define=API_URL=http://10.0.2.2:8080
  final dependencias = urlApi.isEmpty
      ? Dependencias.simuladas(
          capacidades: capacidades,
          notificaciones: notificaciones,
          push: push,
          alertasDao: alertasDao,
          turnosDao: turnosDao,
        )
      : Dependencias.conApi(
          urlBase: Uri.parse(urlApi),
          capacidades: capacidades,
          notificaciones: notificaciones,
          push: push,
          alertasDao: alertasDao,
          turnosDao: turnosDao,
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

/// Si la base no abre, la app sigue sin la caché de alertas y turnos.
Future<Database?> _abrirBase() async {
  try {
    return await abrirBaseDelDispositivo();
  } catch (_) {
    return null;
  }
}

/// La app con la compuerta de conexión.
///
/// El `ConexionViewModel` se crea por encima de `MaterialApp` para que el
/// mismo llegue a [AtrasSinConexion] y a la compuerta. [AtrasSinConexion]
/// tiene que ir por encima de `MaterialApp`: el botón Atrás del sistema
/// recorre los observadores del binding en el orden en que se registraron
/// y corta en el primero que lo atiende. Así queda antes que el de
/// `WidgetsApp`, que cerraría las rutas tapadas sin que el vecino las vea.
class BarrioSeguroApp extends StatelessWidget {
  const BarrioSeguroApp({super.key, required this.dependencias});

  final Dependencias dependencias;

  @override
  Widget build(BuildContext context) {
    final conSesion = dependencias.sesion.usuario != null;
    return ConViewModel(
      crear: () => ConexionViewModel(
        conexion: dependencias.conexion,
        bus: dependencias.bus,
      )..empezar(),
      builder: (_, vm) => AtrasSinConexion(
        viewModel: vm,
        child: MaterialApp(
          title: 'Barrio Seguro',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          // La compuerta va por encima del Navigator: sin conexión tapa
          // cualquier pantalla abierta sin destruirla.
          builder: (context, child) => CompuertaDeConexion(
            viewModel: vm,
            capacidades: dependencias.capacidades,
            telefono: dependencias.telefono,
            child: child ?? const SizedBox.shrink(),
          ),
          home: conSesion
              ? PrincipalScreen(dependencias: dependencias)
              : ConViewModel(
                  crear: () => LoginViewModel(sesion: dependencias.sesion),
                  builder: (_, vm) =>
                      LoginScreen(viewModel: vm, dependencias: dependencias),
                ),
        ),
      ),
    );
  }
}
