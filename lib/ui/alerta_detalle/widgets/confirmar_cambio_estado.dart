import 'package:flutter/material.dart';

import '../../../domain/models/alerta.dart';
import '../../core/presentacion_alerta.dart';
import '../../core/tema/app_colors.dart';
import '../view_models/detalle_alerta_view_model.dart';

/// Pide confirmación antes de pasar una alerta a Resuelta o de volver a
/// abrir una resuelta (decisión P2, R33 y R34).
///
/// Devuelve true solo con "Sí, está resuelta" o "Sí, volver a abrirla"; el
/// botón "No, …", el botón Atrás o tocar fuera del diálogo devuelven false
/// (R36). [nuevo] da el nombre del estado del texto de "reabrir".
Future<bool> confirmarCambioDeEstado(
  BuildContext context, {
  required ConfirmacionCambioEstado confirmacion,
  required EstadoAlerta nuevo,
}) async {
  final resolver = confirmacion == ConfirmacionCambioEstado.resolver;
  final titulo = resolver
      ? '¿Marcar la alerta como resuelta?'
      : '¿Volver a abrir la alerta?';
  final confirmo = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      // R40: al abrirse, el lector anuncia el título (en Android, sin esto,
      // diría el nombre genérico "Alerta").
      semanticLabel: titulo,
      // Con texto grande el diálogo se desplaza en vez de desbordar (R39).
      scrollable: true,
      icon: resolver
          ? const Icon(
              Icons.check_circle_outline,
              color: AppColors.resuelta,
              size: 32,
            )
          : const Icon(
              Icons.notifications_active_outlined,
              color: AppColors.texto,
              size: 32,
            ),
      title: Text(titulo),
      content: Text(
        resolver
            ? 'Va a dejar de aparecer en "Alertas cerca tuyo". Si hace falta, '
                  'la podés volver a abrir desde acá.'
            : 'Va a quedar como ${nuevo.etiqueta} y se les va a avisar a los '
                  'vecinos del barrio.',
      ),
      // Si los botones no entran en una fila (texto grande), se apilan
      // separados 8 dp.
      actionsOverflowButtonSpacing: 8,
      actions: [
        // No dice "Cancelar": se confundiría con cancelar la alerta.
        OutlinedButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
          child: Text(
            resolver ? 'No, dejarla como está' : 'No, dejarla resuelta',
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: resolver ? AppColors.resuelta : AppColors.primary,
            minimumSize: const Size(0, 48),
          ),
          child: Text(resolver ? 'Sí, está resuelta' : 'Sí, volver a abrirla'),
        ),
      ],
    ),
  );
  return confirmo ?? false;
}
