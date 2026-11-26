import 'package:flutter/material.dart';

import '../../../domain/models/alerta.dart';
import '../presentacion_alerta.dart';
import '../tema/app_colors.dart';

/// Marcador de una alerta en el mapa: círculo del color del estado con el
/// ícono del estado adentro, para que no dependa solo del color.
///
/// Con [tardia], suma un distintivo de reloj en la esquina superior derecha
/// (R22): se distingue por la forma, no solo por el color.
class PinAlerta extends StatelessWidget {
  const PinAlerta({
    super.key,
    required this.estado,
    this.diametro = 32,
    this.tardia = false,
  });

  final EstadoAlerta estado;
  final double diametro;

  /// Si el aviso de la alerta llegó con demora.
  final bool tardia;

  @override
  Widget build(BuildContext context) {
    final pin = Container(
      width: diametro,
      height: diametro,
      decoration: BoxDecoration(
        color: estado.color,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.superficie, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: Icon(
        estado.icono,
        size: diametro * 0.55,
        color: AppColors.sobreColor,
      ),
    );
    if (!tardia) return pin;

    final distintivo = diametro * 0.45;
    return SizedBox(
      width: diametro,
      height: diametro,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          pin,
          Positioned(
            top: -distintivo * 0.25,
            right: -distintivo * 0.25,
            child: Container(
              key: const ValueKey('distintivo-tardia'),
              width: distintivo,
              height: distintivo,
              decoration: BoxDecoration(
                color: AppColors.superficie,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.alerta, width: 1.5),
              ),
              child: Icon(
                Icons.schedule,
                size: distintivo * 0.75,
                color: AppColors.alerta,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
