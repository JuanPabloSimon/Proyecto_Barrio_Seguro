import 'package:flutter/material.dart';

import '../../../domain/informe_alertas.dart';
import '../../core/estado_carga.dart';
import '../../core/formato.dart';
import '../../core/tema/app_colors.dart';
import '../../core/widgets/aviso.dart';
import '../../core/widgets/aviso_sin_conexion.dart';
import '../../core/widgets/estado_de_carga.dart';
import '../../core/widgets/objetivo_tactil.dart';
import '../view_models/informe_alertas_view_model.dart';

class InformeAlertasScreen extends StatelessWidget {
  const InformeAlertasScreen({super.key, required this.viewModel});

  final InformeAlertasViewModel viewModel;

  Future<void> _descargarCsv(BuildContext context) async {
    final mensaje = await viewModel.descargarCsv();
    if (context.mounted) mostrarAviso(context, mensaje);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Informe de alertas')),
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) => switch (viewModel.estado) {
          EstadoCarga.inicial ||
          EstadoCarga.cargando => const IndicadorDeCarga(),
          EstadoCarga.error => MensajeDeError(onReintentar: viewModel.cargar),
          EstadoCarga.exito => _ContenidoInforme(
            viewModel: viewModel,
            onDescargarCsv: () => _descargarCsv(context),
          ),
        },
      ),
    );
  }
}

class _ContenidoInforme extends StatelessWidget {
  const _ContenidoInforme({
    required this.viewModel,
    required this.onDescargarCsv,
  });

  final InformeAlertasViewModel viewModel;
  final VoidCallback onDescargarCsv;

  @override
  Widget build(BuildContext context) {
    final informe = viewModel.informe;
    final textoMes = mesYAnio(viewModel.mes);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        if (viewModel.sinConexion)
          const AvisoSinConexion(margen: EdgeInsets.only(bottom: 12)),
        _SelectorMesInforme(
          textoMes: textoMes,
          onMesAnterior: viewModel.mesAnterior,
          onMesSiguiente: viewModel.mesSiguiente,
        ),
        const SizedBox(height: 16),
        if (informe.sinAlertas)
          _InformeVacio(textoMes: textoMes)
        else ...[
          _ResumenTotalMes(
            total: informe.total,
            textoMes: textoMes,
            onDescargarCsv: onDescargarCsv,
          ),
          const SizedBox(height: 20),
          _TablaInforme(
            titulo: 'Por calle',
            icono: Icons.place_outlined,
            filas: informe.porCalle,
          ),
          const SizedBox(height: 16),
          _TablaInforme(
            titulo: 'Por tipo de alerta',
            icono: Icons.campaign_outlined,
            filas: informe.porTipo,
          ),
          const SizedBox(height: 16),
          _TablaInforme(
            titulo: 'Por franja horaria',
            icono: Icons.schedule_outlined,
            filas: informe.porFranja,
          ),
        ],
      ],
    );
  }
}

class _SelectorMesInforme extends StatelessWidget {
  const _SelectorMesInforme({
    required this.textoMes,
    required this.onMesAnterior,
    required this.onMesSiguiente,
  });

  final String textoMes;
  final VoidCallback onMesAnterior;
  final VoidCallback onMesSiguiente;

  @override
  Widget build(BuildContext context) {
    final estiloBoton = IconButton.styleFrom(
      minimumSize: const Size.square(ObjetivoTactil.tamanioMinimo),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Mes anterior',
              style: estiloBoton,
              onPressed: onMesAnterior,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  textoMes,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Mes siguiente',
              style: estiloBoton,
              onPressed: onMesSiguiente,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }
}

class _InformeVacio extends StatelessWidget {
  const _InformeVacio({required this.textoMes});

  final String textoMes;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ExcludeSemantics(
              child: Icon(
                Icons.inbox_outlined,
                size: 40,
                color: AppColors.textoSecundario,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No hubo alertas registradas en ${textoMes.toLowerCase()}.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResumenTotalMes extends StatelessWidget {
  const _ResumenTotalMes({
    required this.total,
    required this.textoMes,
    required this.onDescargarCsv,
  });

  final int total;
  final String textoMes;
  final VoidCallback onDescargarCsv;

  @override
  Widget build(BuildContext context) {
    final textoTotal = total == 1
        ? '1 alerta registrada en ${textoMes.toLowerCase()}'
        : '$total alertas registradas en ${textoMes.toLowerCase()}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              textoTotal,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Resumen mensual para presentar al municipio.',
              style: TextStyle(color: AppColors.textoSecundario),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onDescargarCsv,
              icon: const Icon(Icons.download_outlined),
              label: const Text('Descargar informe (CSV)'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TablaInforme extends StatelessWidget {
  const _TablaInforme({
    required this.titulo,
    required this.icono,
    required this.filas,
  });

  final String titulo;
  final IconData icono;
  final List<FilaInforme> filas;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: Icon(icono, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < filas.length; i++) ...[
              if (i > 0) const Divider(height: 16),
              _FilaTablaInforme(fila: filas[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilaTablaInforme extends StatelessWidget {
  const _FilaTablaInforme({required this.fila});

  final FilaInforme fila;

  @override
  Widget build(BuildContext context) {
    final etiquetaCantidad = fila.cantidad == 1
        ? '1 alerta'
        : '${fila.cantidad} alertas';

    return Semantics(
      container: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(fila.nombre, style: const TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primarioSuave,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${fila.cantidad}',
              semanticsLabel: etiquetaCantidad,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
