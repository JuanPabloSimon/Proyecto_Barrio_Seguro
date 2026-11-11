import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' show CameraFit, MapController;

import '../data/barrio.dart';
import '../data/datos_demo.dart';
import '../models/alerta.dart';
import '../theme/app_colors.dart';
import '../widgets/chip_estado.dart';
import '../widgets/mapa_barrio.dart';
import '../widgets/objetivo_tactil.dart';
import '../widgets/pin_alerta.dart';
import 'detalle_alerta_screen.dart';

class MapaScreen extends StatefulWidget {
  const MapaScreen({super.key});

  @override
  State<MapaScreen> createState() => _MapaScreenState();
}

class _MapaScreenState extends State<MapaScreen> {
  /// Deja libre la parte de abajo del mapa, donde flota el botón SOS.
  static const _margenMapa = EdgeInsets.fromLTRB(16, 16, 72, 120);

  final _controlador = MapController();

  /// null = "Todas"
  EstadoAlerta? _filtro;

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  // Botones de zoom: pellizcar la pantalla es difícil para mucha gente.
  void _cambiarZoom(double cambio) {
    final camara = _controlador.camera;
    final zoom = (camara.zoom + cambio).clamp(MapaBarrio.zoomMinimo, MapaBarrio.zoomMaximo);
    _controlador.move(camara.center, zoom);
  }

  void _verTodoElRadio() {
    _controlador.fitCamera(
      CameraFit.bounds(bounds: Barrio.limitesDelRadio, padding: _margenMapa),
    );
  }

  void _mostrarResumen(Alerta alerta) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      // Con texto grande la hoja puede crecer y desplazarse.
      isScrollControlled: true,
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ChipEstado(estado: alerta.estado),
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
          color: seleccionada ? AppColors.sobreColor : AppColors.texto,
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
          // La leyenda va arriba del mapa y no encima: con texto grande se
          // reacomoda en varias líneas sin tapar los pines.
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _Leyenda(),
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Semantics(
                    container: true,
                    explicitChildNodes: true,
                    label: visibles.isEmpty
                        ? 'Mapa del ${Barrio.nombre} sin alertas para este filtro'
                        : 'Mapa del ${Barrio.nombre} con ${visibles.length} alertas. '
                            'Tocá un pin para ver el resumen',
                    child: MapaBarrio(
                      alertas: visibles,
                      onAlertaTap: _mostrarResumen,
                      controlador: _controlador,
                      margen: _margenMapa,
                      // Abre encuadrando las alertas para que los pines queden
                      // separados; "Ver todo el radio" muestra el círculo entero.
                      encuadre: EncuadreMapa.alertas,
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: _ControlesMapa(
                    onAcercar: () => _cambiarZoom(1),
                    onAlejar: () => _cambiarZoom(-1),
                    onVerTodo: _verTodoElRadio,
                  ),
                ),
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
    Widget item(Widget muestra, String texto) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          muestra,
          const SizedBox(width: 6),
          Flexible(child: Text(texto, style: const TextStyle(fontSize: 14))),
        ],
      );
    }

    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        for (final estado in EstadoAlerta.values)
          item(PinAlerta(estado: estado, diametro: 22), estado.etiqueta),
        item(
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
          'Vos y el radio de alertas (1 km)',
        ),
      ],
    );
  }
}

/// Botones para acercar, alejar y volver a ver todo el radio de alertas.
class _ControlesMapa extends StatelessWidget {
  const _ControlesMapa({
    required this.onAcercar,
    required this.onAlejar,
    required this.onVerTodo,
  });

  final VoidCallback onAcercar;
  final VoidCallback onAlejar;
  final VoidCallback onVerTodo;

  @override
  Widget build(BuildContext context) {
    final estilo = IconButton.styleFrom(
      backgroundColor: AppColors.superficie,
      foregroundColor: AppColors.texto,
      side: const BorderSide(color: AppColors.bordeCampo),
      minimumSize: const Size.square(ObjetivoTactil.tamanioMinimo),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Acercar el mapa',
          style: estilo,
          icon: const Icon(Icons.add),
          onPressed: onAcercar,
        ),
        const SizedBox(height: ObjetivoTactil.separacion),
        IconButton(
          tooltip: 'Alejar el mapa',
          style: estilo,
          icon: const Icon(Icons.remove),
          onPressed: onAlejar,
        ),
        const SizedBox(height: ObjetivoTactil.separacion),
        IconButton(
          tooltip: 'Ver todo el radio de alertas',
          style: estilo,
          icon: const Icon(Icons.zoom_out_map),
          onPressed: onVerTodo,
        ),
      ],
    );
  }
}
