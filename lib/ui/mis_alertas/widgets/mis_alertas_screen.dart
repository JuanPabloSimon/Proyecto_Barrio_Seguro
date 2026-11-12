import 'package:flutter/material.dart';

import '../../../dependencias.dart';
import '../../alerta_detalle/widgets/detalle_alerta_screen.dart';
import '../../core/estado_carga.dart';
import '../../core/widgets/estado_de_carga.dart';
import '../../core/widgets/tarjeta_alerta.dart';
import '../view_models/mis_alertas_view_model.dart';

class MisAlertasScreen extends StatelessWidget {
  const MisAlertasScreen({
    super.key,
    required this.viewModel,
    required this.dependencias,
  });

  final MisAlertasViewModel viewModel;
  final Dependencias dependencias;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis alertas')),
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) => switch (viewModel.estado) {
          EstadoCarga.inicial ||
          EstadoCarga.cargando => const IndicadorDeCarga(),
          EstadoCarga.error => MensajeDeError(onReintentar: viewModel.cargar),
          EstadoCarga.exito => _lista(context),
        },
      ),
    );
  }

  Widget _lista(BuildContext context) {
    final mias = viewModel.mias;
    if (mias.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Todavía no reportaste alertas. Si ves algo raro, tocá el botón SOS.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: mias.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, i) => TarjetaAlerta(
        alerta: mias[i],
        hace: viewModel.hace(mias[i]),
        onTap: () => DetalleAlertaScreen.abrir(context, mias[i], dependencias),
      ),
    );
  }
}
