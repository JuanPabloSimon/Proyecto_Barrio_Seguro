import 'package:flutter/material.dart';

import '../tema/app_colors.dart';

/// Marca visible de una alerta SOS: ícono y texto "SOS", nunca solo color.
/// Tiene la forma de la marca tardía (radio 8 y borde), distinta de la
/// pastilla sólida del estado. No es tocable y queda fuera de la semántica:
/// el "SOS" lo dice la etiqueta de la tarjeta o del pin, o el título del
/// resumen y del detalle, una sola vez.
class MarcaSos extends StatelessWidget {
  const MarcaSos({super.key});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.emergenciaSuave,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.emergencia, width: 1.5),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.campaign, size: 16, color: AppColors.emergencia),
            SizedBox(width: 4),
            Flexible(
              child: Text(
                'SOS',
                style: TextStyle(
                  color: AppColors.texto,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
