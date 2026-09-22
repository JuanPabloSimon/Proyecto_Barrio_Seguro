import 'package:flutter/material.dart';

import 'main_shell.dart';

class RegistroScreen extends StatelessWidget {
  const RegistroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          const Text('Completá tus datos para sumarte a la red del barrio.'),
          const SizedBox(height: 24),
          const TextField(
            decoration: InputDecoration(
              labelText: 'Nombre y apellido',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 16),
          const TextField(
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Teléfono',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 16),
          const TextField(
            decoration: InputDecoration(
              labelText: 'Calle y número',
              prefixIcon: Icon(Icons.home_outlined),
            ),
          ),
          const SizedBox(height: 16),
          const TextField(
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Cuadra',
              prefixIcon: Icon(Icons.signpost_outlined),
            ),
          ),
          const SizedBox(height: 16),
          const TextField(
            decoration: InputDecoration(
              labelText: 'Código de la comisión vecinal',
              helperText: 'Lo entrega la comisión para validar que vivís en el barrio.',
              helperMaxLines: 2,
              prefixIcon: Icon(Icons.verified_user_outlined),
            ),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () => Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const MainShell()),
              (route) => false,
            ),
            child: const Text('Crear cuenta'),
          ),
        ],
      ),
    );
  }
}
