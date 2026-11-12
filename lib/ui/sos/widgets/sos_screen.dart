import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/services/telefono_service.dart';
import '../../../plataforma/capacidades.dart';
import '../../core/tema/app_colors.dart';
import '../../core/widgets/aviso.dart';
import '../../core/widgets/dialogo_911.dart';
import '../view_models/sos_view_model.dart';

/// Se abre al tocar el botón SOS. Primero pide confirmación con un botón
/// grande; recién al confirmar se envía la alerta y se muestran las
/// opciones siguientes.
class SosScreen extends StatelessWidget {
  const SosScreen({
    super.key,
    required this.viewModel,
    required this.capacidades,
    required this.telefono,
  });

  final SosViewModel viewModel;

  /// Para el botón "Llamar al 911".
  final Capacidades capacidades;
  final TelefonoService telefono;

  void _enviar() {
    HapticFeedback.heavyImpact();
    viewModel.enviar();
  }

  void _cerrar(BuildContext context, [String? mensaje]) {
    final anterior = Navigator.of(context);
    anterior.pop();
    if (mensaje != null) mostrarAviso(anterior.context, mensaje);
  }

  /// "Ya estoy a salvo" o "Fue una falsa alarma": primero se cierra la
  /// alerta en el servidor y después se vuelve a la app.
  Future<void> _cerrarAlerta(BuildContext context, String mensaje) async {
    final ok = await viewModel.cerrarAlerta();
    if (!context.mounted) return;
    _cerrar(
      context,
      ok ? mensaje : 'No pudimos cerrar la alerta. Hacelo desde "Mis alertas".',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.emergencia,
      body: SafeArea(
        // Con texto grande el contenido puede no entrar: se vuelve
        // desplazable en vez de desbordar.
        child: LayoutBuilder(
          builder: (context, constraints) {
            final altoDisponible = constraints.maxHeight - 48;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: altoDisponible > 0 ? altoDisponible : 0,
                ),
                child: IntrinsicHeight(
                  child: ListenableBuilder(
                    listenable: viewModel,
                    builder: (context, _) => viewModel.paso == PasoSos.enviada
                        ? _vistaEnviada(context)
                        : _vistaConfirmar(context),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _vistaConfirmar(BuildContext context) {
    final enviando = viewModel.paso == PasoSos.enviando;
    final fallo = viewModel.paso == PasoSos.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        const ExcludeSemantics(
          child: Icon(Icons.campaign, color: AppColors.sobreColor, size: 80),
        ),
        const SizedBox(height: 16),
        Semantics(
          header: true,
          child: const Text(
            '¿Enviar alerta SOS?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.sobreColor,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Tus vecinos van a recibir un aviso con tu ubicación.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.sobreColor, fontSize: 18),
        ),
        if (fallo) ...[
          const SizedBox(height: 16),
          // El error queda en pantalla: no desaparece solo.
          Semantics(
            liveRegion: true,
            child: const Text(
              'No pudimos enviar la alerta. Probá de nuevo o llamá al 911.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.sobreColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        const Spacer(),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: enviando ? null : _enviar,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.superficie,
            foregroundColor: AppColors.emergencia,
            minimumSize: const Size(64, 96),
            textStyle: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          child: enviando
              ? const SizedBox.square(
                  dimension: 32,
                  child: CircularProgressIndicator(
                    color: AppColors.emergencia,
                    semanticsLabel: 'Enviando la alerta',
                  ),
                )
              : Text(
                  fallo ? 'Volver a intentar' : 'Sí, enviar alerta',
                  textAlign: TextAlign.center,
                ),
        ),
        if (fallo) ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => mostrarDialogo911(
              context,
              capacidades: capacidades,
              telefono: telefono,
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.superficie,
              foregroundColor: AppColors.emergencia,
              minimumSize: const Size(64, 64),
              textStyle: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            icon: const Icon(Icons.phone),
            label: const Text('Llamar al 911'),
          ),
        ],
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: enviando ? null : () => _cerrar(context),
          style: _estiloContorno,
          child: const Text('No, cancelar', textAlign: TextAlign.center),
        ),
      ],
    );
  }

  Widget _vistaEnviada(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        const ExcludeSemantics(
          child: Icon(
            Icons.check_circle_outline,
            color: AppColors.sobreColor,
            size: 96,
          ),
        ),
        const SizedBox(height: 16),
        // liveRegion: el lector de pantalla lo anuncia al aparecer. Reemplaza
        // al anuncio directo, que Android marca como obsoleto.
        Semantics(
          header: true,
          liveRegion: true,
          child: Text(
            viewModel.pendiente ? 'Alerta guardada' : 'Alerta enviada',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.sobreColor,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          viewModel.pendiente
              ? 'No hay señal. La alerta se va a enviar sola apenas vuelva '
                    'la conexión. Si estás en peligro, llamá al 911.'
              : viewModel.conUbicacionExacta
              ? 'Avisamos a los vecinos de tu zona con tu ubicación exacta. '
                    'Si estás en peligro, llamá al 911.'
              : 'Avisamos a los vecinos de tu zona. Les mandamos la zona del '
                    'barrio, no tu ubicación exacta. '
                    'Si estás en peligro, llamá al 911.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.sobreColor, fontSize: 18),
        ),
        const Spacer(),
        const SizedBox(height: 32),
        FilledButton.icon(
          onPressed: () => mostrarDialogo911(
            context,
            capacidades: capacidades,
            telefono: telefono,
          ),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.superficie,
            foregroundColor: AppColors.emergencia,
            minimumSize: const Size(64, 80),
            textStyle: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          icon: const Icon(Icons.phone, size: 28),
          label: const Text('Llamar al 911'),
        ),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: () =>
              _cerrarAlerta(context, 'Marcaste la alerta como resuelta'),
          style: _estiloContorno,
          child: const Text('Ya estoy a salvo', textAlign: TextAlign.center),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => _cerrarAlerta(
            context,
            'Cancelaste la alerta: fue una falsa alarma',
          ),
          style: _estiloContorno,
          child: const Text(
            'Fue una falsa alarma',
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  ButtonStyle get _estiloContorno => OutlinedButton.styleFrom(
    foregroundColor: AppColors.sobreColor,
    side: const BorderSide(color: AppColors.sobreColor, width: 2),
    minimumSize: const Size(64, 64),
    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
  );
}
