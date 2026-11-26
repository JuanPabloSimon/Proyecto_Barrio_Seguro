import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../dependencias.dart';
import '../../../domain/avisos_tardios.dart';
import '../../../domain/models/alerta.dart';
import '../../../domain/reglas_alertas.dart';
import '../../core/presentacion_alerta.dart';
import '../../core/tema/app_colors.dart';
import '../../core/ubicacion_de_alerta.dart';
import '../../core/widgets/aviso.dart';
import '../../core/widgets/con_view_model.dart';
import '../view_models/reportar_alerta_view_model.dart';
import 'confirmar_descarte.dart';

/// Formulario "Reportar alerta": tipo, título, descripción y dirección.
///
/// Es una pantalla completa con forma de diálogo (no una hoja inferior):
/// con el texto grande y el teclado abierto usa todo el alto y se desplaza
/// hasta "Enviar alerta".
class ReportarAlertaScreen extends StatefulWidget {
  const ReportarAlertaScreen({super.key, required this.viewModel});

  final ReportarAlertaViewModel viewModel;

  /// Empuja la pantalla completa con su ViewModel.
  static void abrir(BuildContext context, Dependencias dependencias) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => ConViewModel(
          crear: () => ReportarAlertaViewModel(
            alertas: dependencias.alertas,
            sesion: dependencias.sesion,
            bus: dependencias.bus,
            ubicacion: UbicacionDeAlerta(
              capacidades: dependencias.capacidades,
              preferencias: dependencias.preferencias,
              ubicacion: dependencias.ubicacion,
            ),
          )..cargar(),
          builder: (_, vm) => ReportarAlertaScreen(viewModel: vm),
        ),
      ),
    );
  }

  @override
  State<ReportarAlertaScreen> createState() => _ReportarAlertaScreenState();
}

class _ReportarAlertaScreenState extends State<ReportarAlertaScreen> {
  // Lo escrito vive acá y no se pierde si la compuerta de conexión tapa la
  // pantalla: la tapa sin desmontarla.
  final _titulo = TextEditingController();
  final _descripcion = TextEditingController();
  final _direccion = TextEditingController();

  final _focoTipo = FocusNode();
  final _focoTitulo = FocusNode();
  final _focoDescripcion = FocusNode();
  final _focoDireccion = FocusNode();
  final _desplazamiento = ScrollController();

  late final Listenable _cambios = Listenable.merge([
    widget.viewModel,
    _titulo,
    _descripcion,
    _direccion,
  ]);

  ReportarAlertaViewModel get _vm => widget.viewModel;

  @override
  void dispose() {
    _titulo.dispose();
    _descripcion.dispose();
    _direccion.dispose();
    _focoTipo.dispose();
    _focoTitulo.dispose();
    _focoDescripcion.dispose();
    _focoDireccion.dispose();
    _desplazamiento.dispose();
    super.dispose();
  }

  bool get _hayDatos => _vm.hayDatos(
    titulo: _titulo.text,
    descripcion: _descripcion.text,
    direccion: _direccion.text,
  );

  FocusNode _focoDe(CampoReporte campo) => switch (campo) {
    CampoReporte.tipo => _focoTipo,
    CampoReporte.titulo => _focoTitulo,
    CampoReporte.descripcion => _focoDescripcion,
    CampoReporte.direccion => _focoDireccion,
  };

  void _elegir(CategoriaAlerta? tipo) {
    if (tipo == null) return;
    final titulo = _vm.tituloAlElegir(tipo, tituloActual: _titulo.text);
    if (titulo != _titulo.text) _titulo.text = titulo;
  }

  /// La X y "Cancelar" hacen lo mismo que el botón Atrás: pasan por el
  /// [PopScope], que pregunta si hay datos escritos.
  void _cerrar() => Navigator.of(context).maybePop();

  Future<void> _confirmarYCerrar() async {
    final descartar = await confirmarDescarte(context);
    if (!descartar || !mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _enviar() async {
    // Se toman antes del await: después la pantalla ya no existe.
    final navegador = Navigator.of(context);
    final mensajero = ScaffoldMessenger.of(context);
    final creada = await _vm.enviar(
      titulo: _titulo.text,
      descripcion: _descripcion.text,
      direccion: _direccion.text,
    );
    if (creada) {
      navegador.pop();
      mostrarAvisoEn(mensajero, mensajeAlertaReportada);
      return;
    }
    if (!mounted) return;
    final campo = _vm.primerError;
    if (campo == null) return;
    final foco = _focoDe(campo);
    // Con el texto grande, los tipos y el título pueden haber quedado tan
    // arriba que la lista ya no los tiene armados: se vuelve al principio
    // para que existan antes de pedirles el foco.
    final armado = foco.context?.mounted ?? false;
    if (!armado && _desplazamiento.hasClients) {
      _desplazamiento.jumpTo(0);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }
    foco.requestFocus();
    final contexto = foco.context;
    if (contexto != null && contexto.mounted) {
      Scrollable.ensureVisible(contexto);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _cambios,
      builder: (context, _) {
        final enviando = _vm.enviando;
        return PopScope(
          // Mientras se envía no se cierra; con datos escritos, se pregunta.
          canPop: !enviando && !_hayDatos,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop || _vm.enviando) return;
            _confirmarYCerrar();
          },
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                tooltip: 'Cerrar',
                icon: const Icon(Icons.close),
                onPressed: enviando ? null : _cerrar,
              ),
              title: const Text('Reportar alerta'),
            ),
            body: ListView(
              controller: _desplazamiento,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                const _Encabezado('¿Qué pasó?'),
                const SizedBox(height: 4),
                _SelectorDeTipo(
                  tipos: _vm.tipos,
                  elegido: _vm.tipo,
                  focoPrimero: _focoTipo,
                  onElegir: _elegir,
                ),
                if (_vm.errorDe(CampoReporte.tipo) case final error?) ...[
                  const SizedBox(height: 4),
                  _ErrorEnVivo(error),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: _titulo,
                  focusNode: _focoTitulo,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: ReglasAlertas.maxTitulo,
                  maxLengthEnforcement: MaxLengthEnforcement.none,
                  decoration: InputDecoration(
                    labelText: 'Título',
                    helperText: 'Lo ven tus vecinos en la lista y el mapa.',
                    helperMaxLines: 3,
                    errorText: _vm.errorDe(CampoReporte.titulo),
                    errorMaxLines: 3,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descripcion,
                  focusNode: _focoDescripcion,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: ReglasAlertas.maxDescripcion,
                  maxLengthEnforcement: MaxLengthEnforcement.none,
                  decoration: InputDecoration(
                    labelText: 'Descripción (opcional)',
                    alignLabelWithHint: true,
                    errorText: _vm.errorDe(CampoReporte.descripcion),
                    errorMaxLines: 3,
                  ),
                ),
                const SizedBox(height: 16),
                const _Encabezado('¿Dónde?'),
                const SizedBox(height: 8),
                _UbicacionQueVa(exacta: _vm.conUbicacionExacta),
                const SizedBox(height: 16),
                TextField(
                  controller: _direccion,
                  focusNode: _focoDireccion,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: ReglasAlertas.maxDireccion,
                  maxLengthEnforcement: MaxLengthEnforcement.none,
                  decoration: InputDecoration(
                    labelText: 'Dirección o referencia (opcional)',
                    helperText: 'Por ejemplo: Cabildo de Mendoza y Ascasubi',
                    helperMaxLines: 3,
                    errorText: _vm.errorDe(CampoReporte.direccion),
                    errorMaxLines: 3,
                  ),
                ),
                if (_vm.errorDeEnvio case final error?) ...[
                  const SizedBox(height: 16),
                  _ErrorEnVivo(error),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: enviando ? null : _enviar,
                  icon: enviando
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.textoSecundario,
                            semanticsLabel: 'Enviando la alerta',
                          ),
                        )
                      : const Icon(Icons.send),
                  label: const Text('Enviar alerta'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: enviando ? null : _cerrar,
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        texto,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// Un [RadioListTile] por tipo. El elegido se ve con la marca del radio,
/// no solo con color, y el lector de pantalla lo anuncia como elegido.
class _SelectorDeTipo extends StatelessWidget {
  const _SelectorDeTipo({
    required this.tipos,
    required this.elegido,
    required this.focoPrimero,
    required this.onElegir,
  });

  final List<CategoriaAlerta> tipos;
  final CategoriaAlerta? elegido;
  final FocusNode focoPrimero;
  final ValueChanged<CategoriaAlerta?> onElegir;

  @override
  Widget build(BuildContext context) {
    return RadioGroup<CategoriaAlerta>(
      groupValue: elegido,
      onChanged: onElegir,
      child: Column(
        children: [
          for (final (i, tipo) in tipos.indexed)
            RadioListTile<CategoriaAlerta>(
              value: tipo,
              focusNode: i == 0 ? focoPrimero : null,
              contentPadding: const EdgeInsets.only(right: 8),
              title: Text(tipo.nombreCorto ?? tipo.valorApi),
              secondary: ExcludeSemantics(
                child: Icon(tipo.icono, color: AppColors.primary),
              ),
            ),
        ],
      ),
    );
  }
}

/// Error debajo de los tipos o de envío: ícono y texto, anunciado al
/// aparecer.
class _ErrorEnVivo extends StatelessWidget {
  const _ErrorEnVivo(this.mensaje);

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.emergencia),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mensaje,
              style: const TextStyle(
                color: AppColors.emergencia,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Qué posición va a llevar la alerta (R11, R12).
class _UbicacionQueVa extends StatelessWidget {
  const _UbicacionQueVa({required this.exacta});

  final bool exacta;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          exacta ? Icons.my_location : Icons.location_city,
          color: AppColors.primary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            exacta
                ? 'Vamos a mandar tu ubicación exacta.'
                : 'Vamos a mandar la zona del barrio, no tu ubicación exacta.',
          ),
        ),
      ],
    );
  }
}
