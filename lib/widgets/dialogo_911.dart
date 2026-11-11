import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'aviso.dart';

/// Diálogo de confirmación para llamar al 911.
/// Por ahora la llamada es simulada: solo muestra un aviso.
Future<void> mostrarDialogo911(BuildContext context) async {
  final llamar = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      // Con texto grande el diálogo se desplaza en vez de desbordar.
      scrollable: true,
      icon: const Icon(Icons.phone_in_talk, color: AppColors.emergencia, size: 32),
      title: const Text('¿Llamar al 911?'),
      content: const Text('Se va a abrir el teléfono para llamar a emergencias.'),
      // Si los botones no entran en una fila (texto grande), se apilan
      // separados 8 dp.
      actionsOverflowButtonSpacing: 8,
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
    mostrarAviso(context, 'Llamada simulada: todavía no se marca el 911');
  }
}
