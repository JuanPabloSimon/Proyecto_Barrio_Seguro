import 'package:flutter/material.dart';

import '../models/alerta.dart';
import '../theme/app_colors.dart';
import '../widgets/chip_estado.dart';
import '../widgets/dialogo_911.dart';
import '../widgets/mapa_simulado.dart';

class DetalleAlertaScreen extends StatelessWidget {
  const DetalleAlertaScreen({super.key, required this.alerta});

  final Alerta alerta;

  static void abrir(BuildContext context, Alerta alerta) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DetalleAlertaScreen(alerta: alerta)),
    );
  }

  void _cerrarCon(BuildContext context, String mensaje) {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    final puedeCerrarla =
        alerta.reportadaPorMi && alerta.estado != EstadoAlerta.resuelta;

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de la alerta')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(height: 200, child: MapaSimulado(alertas: [alerta])),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ChipEstado(estado: alerta.estado),
              const SizedBox(width: 8),
              Text(alerta.hace, style: const TextStyle(color: AppColors.textoSecundario)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            alerta.tipo,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(alerta.descripcion, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.place_outlined),
            title: const Text('Ubicación aproximada'),
            subtitle: Text(alerta.direccion),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_outline),
            title: const Text('Reportada por'),
            subtitle: Text(alerta.reportadaPorMi ? 'Vos' : 'Un vecino de la zona'),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => mostrarDialogo911(context),
            icon: const Icon(Icons.phone),
            label: const Text('Llamar al 911'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.emergencia,
              side: const BorderSide(color: AppColors.emergencia, width: 1.5),
            ),
          ),
          if (puedeCerrarla) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _cerrarCon(context, 'Marcaste la alerta como resuelta'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.resuelta),
              child: const Text('Marcar como resuelta'),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => _cerrarCon(context, 'Cancelaste la alerta: falsa alarma'),
              child: const Text('Fue una falsa alarma'),
            ),
          ],
        ],
      ),
    );
  }
}
