import 'package:flutter/material.dart';

import '../../../dependencias.dart';
import '../../alerta_detalle/widgets/detalle_alerta_screen.dart';
import '../../core/estado_carga.dart';
import '../../core/tema/app_colors.dart';
import '../../core/widgets/dialogo_911.dart';
import '../../core/widgets/estado_de_carga.dart';
import '../../core/widgets/mapa_barrio.dart';
import '../../core/widgets/objetivo_tactil.dart';
import '../../core/widgets/tarjeta_alerta.dart';
import '../../core/widgets/tarjeta_tocable.dart';
import '../../principal/pestanias.dart';
import '../view_models/inicio_view_model.dart';

class InicioScreen extends StatelessWidget {
  const InicioScreen({
    super.key,
    required this.viewModel,
    required this.dependencias,
    required this.onIrA,
  });

  final InicioViewModel viewModel;
  final Dependencias dependencias;

  /// Permite cambiar de pestaña desde el inicio (por ejemplo, abrir el mapa).
  final ValueChanged<Pestania> onIrA;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ListenableBuilder(
          listenable: viewModel,
          builder: (context, _) => Text(viewModel.saludo),
        ),
        actions: [
          IconButton(
            tooltip: 'Ver alertas',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => onIrA(Pestania.mapa),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) => switch (viewModel.estado) {
          EstadoCarga.inicial ||
          EstadoCarga.cargando => const IndicadorDeCarga(),
          EstadoCarga.error => MensajeDeError(onReintentar: viewModel.cargar),
          EstadoCarga.exito => _contenido(context),
        },
      ),
    );
  }

  Widget _contenido(BuildContext context) {
    final cercanas = viewModel.cercanas;
    final activas = viewModel.cantidadActivas;
    final proximoTurno = viewModel.proximoTurno;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 140),
      children: [
        if (activas > 0) ...[
          _BannerAlertas(cantidad: activas, onTap: () => onIrA(Pestania.mapa)),
          const SizedBox(height: 16),
        ],
        if (proximoTurno != null) ...[
          _ProximoTurno(
            resumen: proximoTurno,
            onTap: () => onIrA(Pestania.turnos),
          ),
          const SizedBox(height: 16),
        ],
        // El mapa tiene altura fija pero no lleva texto adentro; el texto
        // va debajo y crece con el tamaño de fuente.
        TarjetaTocable(
          etiqueta:
              'Mapa con ${cercanas.length} alertas cerca tuyo. Abrir el mapa',
          onTap: () => onIrA(Pestania.mapa),
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 150,
                child: MapaBarrio(
                  alertas: cercanas,
                  encuadre: EncuadreMapa.alertas,
                  mostrarRadio: false,
                  tamanioPin: 28,
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 12, 12),
                child: Row(
                  children: [
                    Icon(Icons.map_outlined, color: AppColors.primary),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Abrir el mapa de alertas',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Con el ancho de su texto: el SOS tiene que ser el botón más grande.
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => mostrarDialogo911(context),
            icon: const Icon(Icons.phone),
            label: const Text('Llamar al 911'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.emergencia,
              side: const BorderSide(color: AppColors.emergencia, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Wrap: con texto grande el botón baja a la línea siguiente.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: ObjetivoTactil.separacion,
          children: [
            Semantics(
              header: true,
              child: const Text(
                'Alertas cerca tuyo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: () => onIrA(Pestania.mapa),
              child: const Text('Ver en el mapa'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        for (final alerta in cercanas)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TarjetaAlerta(
              alerta: alerta,
              hace: viewModel.hace(alerta),
              onTap: () =>
                  DetalleAlertaScreen.abrir(context, alerta, dependencias),
            ),
          ),
      ],
    );
  }
}

class _BannerAlertas extends StatelessWidget {
  const _BannerAlertas({required this.cantidad, required this.onTap});

  final int cantidad;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final texto = cantidad == 1
        ? '1 alerta activa en tu zona'
        : '$cantidad alertas activas en tu zona';

    return TarjetaTocable(
      etiqueta: '$texto. Ver en el mapa',
      onTap: onTap,
      color: AppColors.alerta,
      forma: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.sobreColor,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  texto,
                  style: const TextStyle(
                    color: AppColors.sobreColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Tocá para verlas en el mapa',
                  style: TextStyle(color: AppColors.sobreColor),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.sobreColor),
        ],
      ),
    );
  }
}

/// Tarjeta "Tu próximo turno". Se actualiza sola cuando el vecino se anota
/// o sale de un turno en la pestaña Turnos (el ViewModel escucha el bus).
class _ProximoTurno extends StatelessWidget {
  const _ProximoTurno({required this.resumen, required this.onTap});

  final ResumenTurno resumen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final esGuardia = resumen.esGuardiaVentana;
    return TarjetaTocable(
      etiqueta: '${resumen.titulo}. ${resumen.lineas.join('. ')}. Ver turnos',
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: esGuardia ? AppColors.ventana : AppColors.primary,
            foregroundColor: AppColors.sobreColor,
            child: Icon(
              esGuardia ? Icons.window_outlined : Icons.directions_walk,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resumen.titulo,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  resumen.lineas.join('\n'),
                  style: const TextStyle(color: AppColors.textoSecundario),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
