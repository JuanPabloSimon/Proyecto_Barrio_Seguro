import 'package:flutter/material.dart';

import '../data/sesion.dart';
import '../models/alerta.dart';
import '../theme/app_colors.dart';
import '../widgets/aviso.dart';
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
    // El aviso se muestra en la pantalla anterior, que es la que queda.
    final anterior = Navigator.of(context);
    anterior.pop();
    mostrarAviso(anterior.context, mensaje);
  }

  @override
  Widget build(BuildContext context) {
    final esMia = alerta.reportadaPor == Sesion.usuario.id;
    final puedeCerrarla = esMia && alerta.estado != EstadoAlerta.resuelta;

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de alerta')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Semantics(
              container: true,
              image: true,
              label: 'Mapa con la ubicación aproximada de la alerta: ${alerta.direccion}',
              child: ExcludeSemantics(
                child: SizedBox(height: 200, child: MapaSimulado(alertas: [alerta])),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ChipEstado(estado: alerta.estado),
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
            subtitle: Text(esMia ? 'Vos' : 'Un vecino de la zona'),
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
            const SizedBox(height: 12),
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
