import 'package:flutter/material.dart';

import 'data/services/local/alertas_dao.dart';
import 'data/services/local/base_de_datos.dart';
import 'data/services/local/turnos_dao.dart';
import 'dependencias.dart';
import 'plataforma/capacidades.dart';
import 'ui/core/tema/app_theme.dart';
import 'ui/core/widgets/con_view_model.dart';
import 'ui/login/view_models/login_view_model.dart';
import 'ui/login/widgets/login_screen.dart';
import 'ui/principal/widgets/principal_screen.dart';

/// Dirección de la API, elegida al compilar con `--dart-define`.
const _urlApi = String.fromEnvironment('API_URL');

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

  // Sin API_URL, la app usa el servidor simulado (no hace falta internet).
  // Con el backend andando en la PC, desde el emulador de Android:
  //   flutter run --dart-define=API_URL=http://10.0.2.2:8080
  final dependencias = _urlApi.isEmpty
      ? Dependencias.simuladas(
          capacidades: capacidades,
          alertasDao: alertasDao,
          turnosDao: turnosDao,
        )
      : Dependencias.conApi(
          urlBase: Uri.parse(_urlApi),
          capacidades: capacidades,
          alertasDao: alertasDao,
          turnosDao: turnosDao,
        );
  // Si el vecino ya había ingresado, la app abre directo en el inicio.
  await dependencias.sesion.restaurar();

  runApp(BarrioSeguroApp(dependencias: dependencias));
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
