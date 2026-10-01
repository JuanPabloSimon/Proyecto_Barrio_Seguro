import 'package:flutter/material.dart';

import '../data/sesion.dart';
import '../utils/fechas.dart';

class EditarPerfilScreen extends StatelessWidget {
  const EditarPerfilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final usuario = Sesion.usuario;

    return Scaffold(
      appBar: AppBar(title: const Text('Editar datos personales')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          TextFormField(
            initialValue: usuario.nombre,
            decoration: const InputDecoration(labelText: 'Nombre y apellido'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: fechaNumerica(usuario.fechaNacimiento),
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'Fecha de nacimiento',
              helperText: 'Define tu rol en los turnos. Para corregirla, contactá a la comisión.',
              helperMaxLines: 2,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: usuario.telefono,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Teléfono'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: usuario.calle,
            decoration: const InputDecoration(labelText: 'Calle y número'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: usuario.cuadra.replaceFirst('Cuadra ', ''),
            decoration: const InputDecoration(labelText: 'Cuadra'),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton(
            onPressed: () {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.of(context).pop();
              messenger.showSnackBar(
                const SnackBar(content: Text('Datos actualizados')),
              );
            },
            child: const Text('Guardar cambios'),
          ),
        ),
      ),
    );
  }
}
