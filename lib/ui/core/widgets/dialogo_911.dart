import 'package:flutter/material.dart';

import '../../../data/services/telefono_service.dart';
import '../../../plataforma/capacidades.dart';
import '../tema/app_colors.dart';
import 'aviso.dart';

/// Diálogo para llamar al 911.
///
/// Si el dispositivo puede hacer llamadas, al confirmar se abre el teléfono
/// con el 911 marcado. Si no puede (una computadora, una tablet), se le
/// explica que llame desde otro teléfono.
Future<void> mostrarDialogo911(
  BuildContext context, {
  required Capacidades capacidades,
  required TelefonoService telefono,
}) async {
  if (!capacidades.puedeHacerLlamadas) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        icon: const Icon(
          Icons.phone_disabled,
          color: AppColors.emergencia,
          size: 32,
        ),
        title: const Text('Llamá al 911 desde un teléfono'),
        content: const Text(
          'Este dispositivo no puede hacer llamadas. Si estás en peligro, '
          'llamá al 911 desde tu celular o desde un teléfono fijo.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  final mensajero = ScaffoldMessenger.of(context);
  final llamar = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      // Con texto grande el diálogo se desplaza en vez de desbordar.
      scrollable: true,
      icon: const Icon(
        Icons.phone_in_talk,
        color: AppColors.emergencia,
        size: 32,
      ),
      title: const Text('¿Llamar al 911?'),
      content: const Text(
        'Se va a abrir el teléfono con el 911 ya marcado. '
        'Solo tenés que tocar el botón de llamar.',
      ),
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

  if (llamar != true) return;
  final abierto = await telefono.abrirMarcador('911');
  if (!abierto) {
    mostrarAvisoEn(
      mensajero,
      'No pudimos abrir el teléfono. Marcá 911 a mano.',
    );
  }
}
