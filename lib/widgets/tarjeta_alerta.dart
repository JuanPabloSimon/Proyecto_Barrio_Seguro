import 'package:flutter/material.dart';

import '../models/alerta.dart';
import 'chip_estado.dart';

class TarjetaAlerta extends StatelessWidget {
  const TarjetaAlerta({super.key, required this.alerta, this.onTap});

  final Alerta alerta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: alerta.estado.color.withValues(alpha: 0.12),
          child: Icon(alerta.icono, color: alerta.estado.color),
        ),
        title: Text(
          alerta.tipo,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('${alerta.direccion}\n${alerta.hace}'),
        isThreeLine: true,
        trailing: ChipEstado(estado: alerta.estado),
      ),
    );
  }
}
