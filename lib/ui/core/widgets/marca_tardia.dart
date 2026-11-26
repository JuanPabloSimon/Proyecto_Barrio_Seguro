import 'package:flutter/material.dart';

import '../tema/app_colors.dart';

/// Marca de una alerta cuyo aviso llegó con demora: ícono de reloj y texto
/// (por ejemplo "Llegó con demora. Alerta de las 15:10"), nunca solo un
/// color (R27). El texto hace salto de línea con letra grande (R29). No es
/// tocable.
class MarcaTardia extends StatelessWidget {
  const MarcaTardia({super.key, required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.alertaSuave,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.alerta),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ExcludeSemantics(
            child: Icon(Icons.schedule, size: 18, color: AppColors.alerta),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              texto,
              style: const TextStyle(
                color: AppColors.texto,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
