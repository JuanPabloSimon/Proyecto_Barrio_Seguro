import 'package:flutter/material.dart';

import '../../core/estado_carga.dart';
import '../../core/formato.dart';
import '../../core/tema/app_colors.dart';
import '../../core/widgets/aviso.dart';
import '../view_models/editar_perfil_view_model.dart';

class EditarPerfilScreen extends StatefulWidget {
  const EditarPerfilScreen({super.key, required this.viewModel});

  final EditarPerfilViewModel viewModel;

  @override
  State<EditarPerfilScreen> createState() => _EditarPerfilScreenState();
}

class _EditarPerfilScreenState extends State<EditarPerfilScreen> {
  EditarPerfilViewModel get _vm => widget.viewModel;

  late final _nombre = TextEditingController(text: _vm.usuario?.nombre);
  late final _telefono = TextEditingController(text: _vm.usuario?.telefono);
  late final _calle = TextEditingController(text: _vm.usuario?.calle);
  late final _cuadra = TextEditingController(text: _vm.numeroDeCuadra);

  @override
  void dispose() {
    _nombre.dispose();
    _telefono.dispose();
    _calle.dispose();
    _cuadra.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final ok = await _vm.guardar(
      nombre: _nombre.text,
      telefono: _telefono.text,
      calle: _calle.text,
      cuadra: _cuadra.text,
    );
    if (!ok || !mounted) return;
    final anterior = Navigator.of(context);
    anterior.pop();
    mostrarAviso(anterior.context, 'Datos actualizados');
  }

  @override
  Widget build(BuildContext context) {
    final usuario = _vm.usuario;

    return Scaffold(
      appBar: AppBar(title: const Text('Editar mis datos')),
      body: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            TextField(
              controller: _nombre,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Nombre y apellido',
                errorText: _vm.errorNombre,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: usuario == null
                  ? ''
                  : fechaNumerica(usuario.fechaNacimiento),
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Fecha de nacimiento',
                helperText: 'Define tu rol en los turnos. Para corregirla, contactá a la comisión.',
                helperMaxLines: 4,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _telefono,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Teléfono'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _calle,
              decoration: const InputDecoration(labelText: 'Calle y número'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _cuadra,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Cuadra'),
            ),
            if (_vm.error != null) ...[
              const SizedBox(height: 16),
              Semantics(
                liveRegion: true,
                child: Text(
                  _vm.error!,
                  style: const TextStyle(color: AppColors.emergencia),
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: ListenableBuilder(
            listenable: _vm,
            builder: (context, _) {
              final cargando = _vm.estado == EstadoCarga.cargando;
              return FilledButton(
                onPressed: cargando ? null : _guardar,
                child: cargando
                    ? const SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(
                          semanticsLabel: 'Guardando',
                        ),
                      )
                    : const Text('Guardar cambios'),
              );
            },
          ),
        ),
      ),
    );
  }
}
