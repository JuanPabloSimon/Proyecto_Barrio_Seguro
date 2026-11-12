import 'package:flutter/material.dart';

import 'dependencias.dart';
import 'ui/core/tema/app_theme.dart';
import 'ui/core/widgets/con_view_model.dart';
import 'ui/login/view_models/login_view_model.dart';
import 'ui/login/widgets/login_screen.dart';

/// Arma las piezas una sola vez, de abajo hacia arriba, y arranca la app.
/// Es el único lugar que sabe cómo está conectado todo.
void main() {
  final dependencias = Dependencias.simuladas();
  runApp(BarrioSeguroApp(dependencias: dependencias));
}

class BarrioSeguroApp extends StatelessWidget {
  const BarrioSeguroApp({super.key, required this.dependencias});

  final Dependencias dependencias;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Barrio Seguro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: ConViewModel(
        crear: () => LoginViewModel(sesion: dependencias.sesion),
        builder: (_, vm) =>
            LoginScreen(viewModel: vm, dependencias: dependencias),
      ),
    );
  }
}
