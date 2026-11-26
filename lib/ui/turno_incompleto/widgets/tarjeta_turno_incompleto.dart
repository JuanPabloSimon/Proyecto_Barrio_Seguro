import 'package:flutter/material.dart';

import '../../core/tema/app_colors.dart';
import '../../core/widgets/objetivo_tactil.dart';
import '../view_models/turno_incompleto_view_model.dart';

/// Tarjeta del aviso de turno incompleto. En el inicio recibe [onTap] (lleva
/// a Turnos); en Turnos no, y tocarla fuera de "Entendido" no hace nada.
///
/// Es una tarjeta y no un diálogo: no tapa el SOS ni corta lo que está
/// leyendo el lector de pantalla, que la anuncia como región en vivo.
class TarjetaTurnoIncompleto extends StatelessWidget {
  const TarjetaTurnoIncompleto({
    super.key,
    required this.aviso,
    required this.onCerrar,
    this.onTap,
  });

  final AvisoTurnoIncompleto aviso;
  final VoidCallback onCerrar;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final alTocar = onTap;
    final contenido = Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: _Contenido(aviso: aviso, conIndicacion: alTocar != null),
    );

    return Card(
      color: AppColors.superficie,
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.alerta, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (alTocar == null)
            Semantics(
              container: true,
              liveRegion: true,
              label: aviso.etiqueta,
              excludeSemantics: true,
              child: contenido,
            )
          else
            Semantics(
              container: true,
              liveRegion: true,
              button: true,
              label: '${aviso.etiqueta}. Ver turnos',
              onTap: alTocar,
              excludeSemantics: true,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: ObjetivoTactil.tamanioMinimo,
                ),
                child: InkWell(onTap: alTocar, child: contenido),
              ),
            ),
          const SizedBox(height: ObjetivoTactil.separacion),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Align(
              alignment: Alignment.centerRight,
              child: Semantics(
                container: true,
                button: true,
                label: 'Entendido. Ocultar este aviso',
                onTap: onCerrar,
                excludeSemantics: true,
                child: OutlinedButton(
                  onPressed: onCerrar,
                  child: const Text('Entendido'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({required this.aviso, required this.conIndicacion});

  final AvisoTurnoIncompleto aviso;
  final bool conIndicacion;

  @override
  Widget build(BuildContext context) {
    // Sin maxLines ni alturas fijas: con el texto al 200 % crece hacia abajo.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // El ícono distingue el aviso además del color del borde.
        const Icon(Icons.event_busy, color: AppColors.alerta, size: 32),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                aviso.titulo,
                style: const TextStyle(
                  color: AppColors.texto,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(aviso.texto, style: const TextStyle(color: AppColors.texto)),
              if (conIndicacion) ...[
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Tocá para ver tus turnos',
                        style: TextStyle(
                          color: AppColors.texto,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: AppColors.texto),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
