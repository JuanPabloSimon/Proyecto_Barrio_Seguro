import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Diálogo de confirmación para llamar al 911.
/// Por ahora la llamada es simulada: solo muestra un aviso.
Future<void> mostrarDialogo911(BuildContext context) async {
  final llamar = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.phone_in_talk, color: AppColors.emergencia, size: 32),
      title: const Text('¿Llamar al 911?'),
      content: const Text('Se va a abrir el teléfono para llamar a emergencias.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.emergencia,
            minimumSize: const Size(0, 44),
          ),
          child: const Text('Llamar'),
        ),
      ],
    ),
  );

  if (llamar == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Llamada simulada: todavía no se marca el 911')),
    );
  }
}
