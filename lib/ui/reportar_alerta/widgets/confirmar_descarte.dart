import 'package:flutter/material.dart';

/// Pregunta antes de cerrar "Reportar alerta" con datos escritos.
///
/// Devuelve true solo con "Sí, descartar"; "Seguir escribiendo", el botón
/// Atrás o tocar fuera del diálogo devuelven false.
Future<bool> confirmarDescarte(BuildContext context) async {
  final descartar = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      // Con texto grande el diálogo se desplaza en vez de desbordar.
      scrollable: true,
      title: const Text('¿Descartar la alerta?'),
      content: const Text(
        'Todavía no la enviaste. Si salís, se borra lo que escribiste.',
      ),
      // Si los botones no entran en una fila (texto grande), se apilan
      // separados 8 dp.
      actionsOverflowButtonSpacing: 8,
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
          child: const Text('Seguir escribiendo'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
          child: const Text('Sí, descartar'),
        ),
      ],
    ),
  );
  return descartar ?? false;
}
