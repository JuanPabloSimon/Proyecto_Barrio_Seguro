import 'package:flutter/material.dart';

import '../../../dependencias.dart';
import '../../core/estado_carga.dart';
import '../../core/tema/app_colors.dart';
import '../../core/widgets/con_view_model.dart';
import '../../principal/widgets/principal_screen.dart';
import '../../registro/view_models/registro_view_model.dart';
import '../../registro/widgets/registro_screen.dart';
import '../view_models/login_view_model.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.viewModel,
    required this.dependencias,
  });

  final LoginViewModel viewModel;

  /// Para armar las pantallas a las que se navega desde acá.
  final Dependencias dependencias;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usuario = TextEditingController();
  final _clave = TextEditingController();

  @override
  void dispose() {
    _usuario.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _ingresar() async {
    final ok = await widget.viewModel.ingresar(
      usuario: _usuario.text,
      clave: _clave.text,
    );
    if (!ok || !mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PrincipalScreen(dependencias: widget.dependencias),
      ),
    );
  }

  void _abrirRegistro() {
    final dependencias = widget.dependencias;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConViewModel(
          crear: () => RegistroViewModel(
            sesion: dependencias.sesion,
            reloj: dependencias.reloj,
          ),
          builder: (_, vm) =>
              RegistroScreen(viewModel: vm, dependencias: dependencias),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          children: [
            // Logo decorativo: el nombre de la app ya está escrito debajo.
            ExcludeSemantics(
              child: Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: AppColors.sobreColor,
                    size: 44,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Semantics(
              header: true,
              child: const Text(
                'Barrio Seguro',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'La red de tus vecinos, siempre a mano.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textoSecundario, fontSize: 16),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _usuario,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Teléfono o email',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _clave,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Contraseña',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 24),
            // Solo esta parte depende del estado del ViewModel.
            ListenableBuilder(
              listenable: widget.viewModel,
              builder: (context, _) {
                final cargando =
                    widget.viewModel.estado == EstadoCarga.cargando;
                final error = widget.viewModel.error;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (error != null) ...[
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          error,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.emergencia),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    FilledButton(
                      onPressed: cargando ? null : _ingresar,
                      child: cargando
                          ? const SizedBox.square(
                              dimension: 24,
                              child: CircularProgressIndicator(
                                semanticsLabel: 'Ingresando',
                              ),
                            )
                          : const Text('Ingresar'),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _abrirRegistro,
              child: const Text('Todavía no tengo cuenta'),
            ),
          ],
        ),
      ),
    );
  }
}
