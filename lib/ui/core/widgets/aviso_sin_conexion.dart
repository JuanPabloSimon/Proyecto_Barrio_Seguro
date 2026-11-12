import 'package:flutter/material.dart';

import '../tema/app_colors.dart';

/// Franja que avisa que no hay conexión y que lo que se ve es la copia
/// guardada en el teléfono. Usa colores de AppColors que ya cumplen el
/// contraste (texto sobre primarioSuave).
class AvisoSinConexion extends StatelessWidget {
  const AvisoSinConexion({super.key, this.margen = EdgeInsets.zero});

  final EdgeInsetsGeometry margen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margen,
      child: Semantics(
        // El lector de pantalla lo anuncia apenas aparece.
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.primarioSuave,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.cloud_off, color: AppColors.texto),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Sin conexión. Estás viendo lo último que se guardó en '
                  'tu teléfono.',
                  style: TextStyle(color: AppColors.texto),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
