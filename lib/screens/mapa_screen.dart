import 'package:flutter/material.dart';

import '../data/datos_demo.dart';
import '../models/alerta.dart';
import '../theme/app_colors.dart';
import '../widgets/chip_estado.dart';
import '../widgets/mapa_simulado.dart';
import '../widgets/pin_alerta.dart';
import 'detalle_alerta_screen.dart';

class MapaScreen extends StatefulWidget {
  const MapaScreen({super.key});

  @override
  State<MapaScreen> createState() => _MapaScreenState();
}

class _MapaScreenState extends State<MapaScreen> {
  /// null = "Todas"
  EstadoAlerta? _filtro;

  void _mostrarResumen(Alerta alerta) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ChipEstado(estado: alerta.estado),
                const Spacer(),
                Text(
                  alerta.hace,
                  style: const TextStyle(color: AppColors.textoSecundario),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              alerta.tipo,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(alerta.direccion),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                DetalleAlertaScreen.abrir(context, alerta);
              },
              child: const Text('Ver detalle'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pastilla(String texto, EstadoAlerta? valor) {
    final seleccionada = _filtro == valor;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(texto),
        selected: seleccionada,
        // El check marca la opción elegida además del color.
        showCheckmark: true,
        checkmarkColor: AppColors.sobreColor,
        onSelected: (_) => setState(() => _filtro = valor),
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.superficie,
        labelStyle: TextStyle(
          color: seleccionada ? Colors.white : AppColors.texto,
          fontWeight: FontWeight.w600,
        ),
        shape: const StadiumBorder(side: BorderSide(color: AppColors.bordeCampo)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibles = _filtro == null
        ? alertasDemo
        : alertasDemo.where((a) => a.estado == _filtro).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Mapa de alertas')),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 12),
            child: Row(
              children: [
                _pastilla('Todas', null),
                for (final estado in EstadoAlerta.values)
                  _pastilla(estado.etiquetaFiltro, estado),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                MapaSimulado(alertas: visibles, onAlertaTap: _mostrarResumen),
                const Positioned(left: 12, top: 12, child: _Leyenda()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Leyenda extends StatelessWidget {
  const _Leyenda();

  @override
  Widget build(BuildContext context) {
    Widget fila(Widget muestra, String texto) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            muestra,
            const SizedBox(width: 8),
            Text(texto, style: const TextStyle(fontSize: 14)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final estado in EstadoAlerta.values)
            fila(PinAlerta(estado: estado, diametro: 22), estado.etiqueta),
          fila(
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.superficie,
                border: Border.all(color: AppColors.radio, width: 3),
              ),
              child: const Icon(Icons.my_location, size: 12, color: AppColors.radio),
            ),
            'Vos y tu radio',
          ),
        ],
      ),
    );
  }
}
