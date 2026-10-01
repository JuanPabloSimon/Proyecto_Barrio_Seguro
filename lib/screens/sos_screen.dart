import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/dialogo_911.dart';

/// Se abre después de mantener presionado el botón SOS durante 3 segundos:
/// la alerta ya fue enviada.
class SosScreen extends StatelessWidget {
  const SosScreen({super.key});

  void _cerrar(BuildContext context, String mensaje) {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.emergencia,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(Icons.check_circle_outline, color: Colors.white, size: 96),
              const SizedBox(height: 16),
              const Text(
                'Alerta enviada',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Avisamos a los vecinos de tu zona con tu ubicación. Si estás en peligro, llamá al 911.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => mostrarDialogo911(context),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.emergencia,
                ),
                icon: const Icon(Icons.phone),
                label: const Text('Llamar al 911'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _cerrar(context, 'Marcaste la alerta como resuelta'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white, width: 2),
                ),
                child: const Text('Ya estoy a salvo'),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => _cerrar(context, 'Cancelaste la alerta: falsa alarma'),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('Fue una falsa alarma'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
