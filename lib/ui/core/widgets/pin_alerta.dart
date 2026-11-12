import 'package:flutter/material.dart';

import '../../../domain/models/alerta.dart';
import '../presentacion_alerta.dart';
import '../tema/app_colors.dart';

/// Marcador de una alerta en el mapa: círculo del color del estado con el
/// ícono del estado adentro, para que no dependa solo del color.
class PinAlerta extends StatelessWidget {
  const PinAlerta({super.key, required this.estado, this.diametro = 32});

  final EstadoAlerta estado;
  final double diametro;

  @override
  Widget build(BuildContext context) {
    return Container(
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
  }
}
