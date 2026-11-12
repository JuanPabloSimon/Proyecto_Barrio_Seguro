import 'package:flutter/material.dart';

import '../../../dependencias.dart';
import '../../../domain/models/alerta.dart';
import '../../core/estado_carga.dart';
import '../../core/tema/app_colors.dart';
import '../../core/widgets/aviso.dart';
import '../../core/widgets/chip_estado.dart';
import '../../core/widgets/con_view_model.dart';
import '../../core/widgets/dialogo_911.dart';
import '../../core/widgets/mapa_barrio.dart';
import '../view_models/detalle_alerta_view_model.dart';

class DetalleAlertaScreen extends StatelessWidget {
  const DetalleAlertaScreen({super.key, required this.viewModel});

  final DetalleAlertaViewModel viewModel;

  /// Abre el detalle de [alerta]. La alerta viaja como parámetro de la
  /// navegación y el ViewModel se crea una sola vez para esta pantalla.
  static void abrir(
    BuildContext context,
    Alerta alerta,
    Dependencias dependencias,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConViewModel(
          crear: () => DetalleAlertaViewModel(
            alerta: alerta,
            alertas: dependencias.alertas,
            sesion: dependencias.sesion,
            bus: dependencias.bus,
            reloj: dependencias.reloj,
          ),
          builder: (_, vm) => DetalleAlertaScreen(viewModel: vm),
        ),
      ),
    );
  }

  Future<void> _cerrarCon(
    BuildContext context,
    Future<bool> Function() accion,
    String mensaje,
  ) async {
    // Se obtienen antes del await: después, esta pantalla puede no existir.
    final navegador = Navigator.of(context);
    final mensajero = ScaffoldMessenger.of(context);
    final ok = await accion();
    if (!ok) return;
    // El aviso se muestra en la pantalla anterior, que es la que queda.
    navegador.pop();
    mostrarAvisoEn(mensajero, mensaje);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) => _pantalla(context),
    );
  }

  Widget _pantalla(BuildContext context) {
    final alerta = viewModel.alerta;
    final esMia = viewModel.esMia;
    final puedeCerrarla = viewModel.puedeCerrarla;
    final cargando = viewModel.estado == EstadoCarga.cargando;
    final error = viewModel.error;

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
              label:
                  'Mapa con la ubicación aproximada de la alerta: ${alerta.direccion}',
              child: ExcludeSemantics(
                child: SizedBox(
                  height: 200,
                  child: MapaBarrio(
                    alertas: [alerta],
                    encuadre: EncuadreMapa.alertas,
                    mostrarRadio: false,
                    mostrarUsuario: false,
                  ),
                ),
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
              Text(
                viewModel.hace,
                style: const TextStyle(color: AppColors.textoSecundario),
              ),
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
            if (error != null) ...[
              Semantics(
                liveRegion: true,
                child: Text(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.emergencia),
                ),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton(
              onPressed: cargando
                  ? null
                  : () => _cerrarCon(
                      context,
                      viewModel.marcarResuelta,
                      'Marcaste la alerta como resuelta',
                    ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.resuelta,
              ),
              child: const Text('Marcar como resuelta'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: cargando
                  ? null
                  : () => _cerrarCon(
                      context,
                      viewModel.marcarFalsaAlarma,
                      'Cancelaste la alerta: falsa alarma',
                    ),
              child: const Text('Fue una falsa alarma'),
            ),
          ],
        ],
      ),
    );
  }
}
