import 'package:flutter/material.dart';

import '../../core/tema/app_colors.dart';

/// Por qué el vecino quiere cerrar su SOS.
enum CierreSos { aSalvo, falsaAlarma }

/// Pide confirmación antes de cerrar la alerta del SOS.
///
/// Devuelve true solo si el vecino toca el botón de confirmar; "Seguir con
/// la alerta", el botón Atrás o tocar fuera del diálogo devuelven false.
Future<bool> confirmarCierreSos(BuildContext context, CierreSos cierre) async {
  final aSalvo = cierre == CierreSos.aSalvo;
  final confirmo = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      // Con texto grande el diálogo se desplaza en vez de desbordar.
      scrollable: true,
      icon: aSalvo
          ? const Icon(
              Icons.check_circle_outline,
              color: AppColors.resuelta,
              size: 32,
            )
          : const Icon(Icons.cancel_outlined, color: AppColors.texto, size: 32),
      title: Text(aSalvo ? '¿Ya estás a salvo?' : '¿Fue una falsa alarma?'),
      content: Text(
        aSalvo
            ? 'Tu alerta va a quedar como resuelta. Si todavía necesitás '
                  'ayuda, tocá "Seguir con la alerta".'
            : 'Tu alerta se va a cancelar y va a quedar como resuelta. Si de '
                  'verdad necesitás ayuda, tocá "Seguir con la alerta".',
      ),
      // Si los botones no entran en una fila (texto grande), se apilan
      // separados 8 dp.
      actionsOverflowButtonSpacing: 8,
      actions: [
        // No dice "Cancelar": en la falsa alarma se confundiría con
        // cancelar la alerta.
        OutlinedButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
          child: const Text('Seguir con la alerta'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: aSalvo ? AppColors.resuelta : AppColors.primary,
            minimumSize: const Size(0, 48),
          ),
          child: Text(
            aSalvo ? 'Sí, estoy a salvo' : 'Sí, fue una falsa alarma',
          ),
        ),
      ],
    ),
  );
  return confirmo ?? false;
}
