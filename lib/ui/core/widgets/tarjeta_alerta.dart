import 'package:flutter/material.dart';

import '../../../domain/models/alerta.dart';
import '../presentacion_alerta.dart';
import '../tema/app_colors.dart';
import 'chip_estado.dart';
import 'marca_tardia.dart';
import 'tarjeta_tocable.dart';

class TarjetaAlerta extends StatelessWidget {
  const TarjetaAlerta({
    super.key,
    required this.alerta,
    required this.hace,
    required this.onTap,
    this.tardia,
  });

  final Alerta alerta;

  /// Cuánto hace que se reportó, ya formateado ("Hace 5 minutos").
  final String hace;
  final VoidCallback onTap;

  /// Texto de la marca si el aviso llegó con demora; null si no (R20).
  final String? tardia;

  /// Lo que lee el lector de pantalla: tipo, cuándo, estado, la marca de
  /// tardía si la hay (R28) y dónde.
  static String descripcion(Alerta alerta, String hace, {String? tardia}) =>
      'Alerta de ${alerta.tipo.toLowerCase()}, ${hace.toLowerCase()}, '
      '${alerta.estado.etiqueta.toLowerCase()}. '
      '${tardia == null ? '' : '$tardia. '}${alerta.direccion}';

  @override
  Widget build(BuildContext context) {
    final tardia = this.tardia;
    return TarjetaTocable(
      etiqueta: '${descripcion(alerta, hace, tardia: tardia)}. Ver detalle',
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
                if (tardia != null) ...[
                  const SizedBox(height: 8),
                  MarcaTardia(texto: tardia),
                ],
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
