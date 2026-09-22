import 'package:flutter/material.dart';

import '../models/alerta.dart';

class ChipEstado extends StatelessWidget {
  const ChipEstado({super.key, required this.estado});

  final EstadoAlerta estado;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: estado.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        estado.etiqueta,
        style: TextStyle(
          color: estado.color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
