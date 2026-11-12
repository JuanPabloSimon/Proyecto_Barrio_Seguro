import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' show CameraFit, MapController;

import '../../../dependencias.dart';
import '../../../domain/barrio.dart';
import '../../../domain/models/alerta.dart';
import '../../alerta_detalle/widgets/detalle_alerta_screen.dart';
import '../../core/estado_carga.dart';
import '../../core/presentacion_alerta.dart';
import '../../core/tema/app_colors.dart';
import '../../core/widgets/boton_sos.dart';
import '../../core/widgets/chip_estado.dart';
import '../../core/widgets/estado_de_carga.dart';
import '../../core/widgets/mapa_barrio.dart';
import '../../core/widgets/objetivo_tactil.dart';
import '../../core/widgets/pin_alerta.dart';
import '../view_models/mapa_view_model.dart';

class MapaScreen extends StatefulWidget {
  const MapaScreen({
    super.key,
    required this.viewModel,
    required this.dependencias,
  });

  final MapaViewModel viewModel;
  final Dependencias dependencias;

  @override
  State<MapaScreen> createState() => _MapaScreenState();
}

class _MapaScreenState extends State<MapaScreen> {
  /// El controlador del mapa es de la vista: mueve la cámara, no tiene datos.
  final _controlador = MapController();

  MapaViewModel get _vm => widget.viewModel;

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  /// Espacio libre al encuadrar, para que ningún pin (ni la mitad de su área
  /// táctil) quede debajo del botón SOS ni de los botones de zoom. El botón
  /// SOS crece con el texto del sistema, así que se calcula cada vez.
  EdgeInsets _margenMapa(BuildContext context) {
    const mitadPin = ObjetivoTactil.tamanioMinimo / 2;
    const separacionSos = 16.0; // la que deja el Scaffold debajo del botón
    const anchoControles = 12 + ObjetivoTactil.tamanioMinimo;
    return EdgeInsets.fromLTRB(
      mitadPin + 8,
      mitadPin + 8,
      anchoControles + mitadPin + ObjetivoTactil.separacion,
      separacionSos +
          BotonSos.altoActual(context) +
          mitadPin +
          ObjetivoTactil.separacion,
    );
  }

  // Botones de zoom: pellizcar la pantalla es difícil para mucha gente.
  void _cambiarZoom(double cambio) {
    final camara = _controlador.camera;
    final zoom = (camara.zoom + cambio).clamp(
      MapaBarrio.zoomMinimo,
      MapaBarrio.zoomMaximo,
    );
    _controlador.move(camara.center, zoom);
  }

  void _verTodoElRadio() {
    _controlador.fitCamera(
      CameraFit.bounds(
        bounds: MapaBarrio.limitesDelRadio,
        padding: _margenMapa(context),
      ),
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
                  _vm.hace(alerta),
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
                DetalleAlertaScreen.abrir(context, alerta, widget.dependencias);
              },
              child: const Text('Ver detalle'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pastilla(String texto, EstadoAlerta? valor) {
    final seleccionada = _vm.filtro == valor;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(texto),
        selected: seleccionada,
        // El check marca la opción elegida además del color.
        showCheckmark: true,
        checkmarkColor: AppColors.sobreColor,
        onSelected: (_) => _vm.elegirFiltro(valor),
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.superficie,
        labelStyle: TextStyle(
          color: seleccionada ? AppColors.sobreColor : AppColors.texto,
          fontWeight: FontWeight.w600,
        ),
        shape: const StadiumBorder(
          side: BorderSide(color: AppColors.bordeCampo),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mapa de alertas')),
      body: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) => switch (_vm.estado) {
          EstadoCarga.inicial ||
          EstadoCarga.cargando => const IndicadorDeCarga(),
          EstadoCarga.error => MensajeDeError(onReintentar: _vm.cargar),
          EstadoCarga.exito => _contenido(context),
        },
      ),
    );
  }

  Widget _contenido(BuildContext context) {
    final visibles = _vm.visibles;

    return Column(
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
                    margen: _margenMapa(context),
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
            child: const Icon(
              Icons.my_location,
              size: 12,
              color: AppColors.radio,
            ),
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
