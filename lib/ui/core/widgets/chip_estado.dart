import 'package:flutter/material.dart';

import '../../../domain/models/alerta.dart';
import '../presentacion_alerta.dart';
import '../tema/app_colors.dart';

/// Estado de una alerta con ícono, texto y color (nunca solo color).
class ChipEstado extends StatelessWidget {
  const ChipEstado({super.key, required this.estado});

  final EstadoAlerta estado;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: estado.color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(estado.icono, size: 16, color: AppColors.sobreColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              estado.etiqueta,
              style: const TextStyle(
                color: AppColors.sobreColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
