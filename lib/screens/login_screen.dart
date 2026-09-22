import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'main_shell.dart';
import 'registro_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          children: [
            Center(
              child: Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield_outlined, color: Colors.white, size: 44),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Barrio Seguro',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'La red de tus vecinos, siempre a mano.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textoSecundario, fontSize: 16),
            ),
            const SizedBox(height: 40),
            const TextField(
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Teléfono o email',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            const TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Contraseña',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const MainShell()),
              ),
              child: const Text('Ingresar'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RegistroScreen()),
              ),
              child: const Text('Todavía no tengo cuenta'),
            ),
          ],
        ),
      ),
    );
  }
}
