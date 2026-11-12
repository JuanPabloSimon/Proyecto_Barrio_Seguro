import 'package:flutter/material.dart';

import '../../../domain/models/alerta.dart';
import '../presentacion_alerta.dart';
import '../tema/app_colors.dart';
import 'chip_estado.dart';
import 'tarjeta_tocable.dart';

class TarjetaAlerta extends StatelessWidget {
  const TarjetaAlerta({
    super.key,
    required this.alerta,
    required this.hace,
    required this.onTap,
  });

  final Alerta alerta;

  /// Cuánto hace que se reportó, ya formateado ("Hace 5 minutos").
  final String hace;
  final VoidCallback onTap;

  /// Lo que lee el lector de pantalla: tipo, cuándo, estado y dónde.
  static String descripcion(Alerta alerta, String hace) =>
      'Alerta de ${alerta.tipo.toLowerCase()}, ${hace.toLowerCase()}, '
      '${alerta.estado.etiqueta.toLowerCase()}. ${alerta.direccion}';

  @override
  Widget build(BuildContext context) {
    return TarjetaTocable(
      etiqueta: '${descripcion(alerta, hace)}. Ver detalle',
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: alerta.estado.colorSuave,
            child: Icon(alerta.categoria.icono, color: alerta.estado.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alerta.tipo,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  alerta.direccion,
                  style: const TextStyle(color: AppColors.textoSecundario),
                ),
                Text(
                  hace,
                  style: const TextStyle(color: AppColors.textoSecundario),
                ),
                const SizedBox(height: 8),
                ChipEstado(estado: alerta.estado),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
