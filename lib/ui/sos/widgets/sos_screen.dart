import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/services/telefono_service.dart';
import '../../../plataforma/capacidades.dart';
import '../../core/tema/app_colors.dart';
import '../../core/widgets/aviso.dart';
import '../../core/widgets/dialogo_911.dart';
import '../view_models/sos_view_model.dart';
import 'confirmar_cierre_sos.dart';

const _estiloBotonContornoSos = OutlinedButton.styleFrom;

ButtonStyle _crearEstiloContornoSos() => _estiloBotonContornoSos(
  foregroundColor: AppColors.sobreColor,
  side: const BorderSide(color: AppColors.sobreColor, width: 2),
  minimumSize: const Size(64, 64),
  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
);

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

  /// "Volver" o el botón Atrás con la alerta enviada: se cierra la pantalla
  /// sin tocar la alerta, que sigue activa, y se avisa dónde encontrarla.
  void _volver(BuildContext context) {
    final navegador = Navigator.of(context);
    final mensajero = ScaffoldMessenger.of(context);
    navegador.pop();
    mostrarAvisoEn(
      mensajero,
      'Tu alerta sigue activa. La encontrás en Perfil, en '
      '"Mis alertas reportadas".',
    );
  }

  /// "Ya estoy a salvo" o "Fue una falsa alarma": primero se confirma,
  /// después se cierra la alerta en el servidor y se vuelve a la app. Si
  /// el vecino no confirma, no cambia nada.
  Future<void> _confirmarYCerrar(BuildContext context, CierreSos cierre) async {
    final confirmo = await confirmarCierreSos(context, cierre);
    if (!confirmo || !context.mounted) return;
    final ok = await viewModel.cerrarAlerta();
    if (!context.mounted) return;
    final mensaje = switch (cierre) {
      CierreSos.aSalvo => 'Marcaste la alerta como resuelta',
      CierreSos.falsaAlarma => 'Cancelaste la alerta: fue una falsa alarma',
    };
    _cerrar(
      context,
      ok ? mensaje : 'No pudimos cerrar la alerta. Hacelo desde "Mis alertas".',
    );
  }

  @override
  Widget build(BuildContext context) {
    // Con la alerta enviada, el botón Atrás hace lo mismo que "Volver". En
    // los otros pasos cierra como siempre.
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, pantalla) => PopScope(
        canPop: viewModel.paso != PasoSos.enviada,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _volver(context);
        },
        child: pantalla!,
      ),
      child: Scaffold(
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
                          ? _VistaSosEnviada(
                              conUbicacionExacta: viewModel.conUbicacionExacta,
                              capacidades: capacidades,
                              telefono: telefono,
                              onCerrar: (cierre) =>
                                  _confirmarYCerrar(context, cierre),
                              onVolver: () => _volver(context),
                            )
                          : _VistaConfirmarSos(
                              paso: viewModel.paso,
                              capacidades: capacidades,
                              telefono: telefono,
                              onEnviar: _enviar,
                              onCancelar: () => _cerrar(context),
                            ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _VistaConfirmarSos extends StatelessWidget {
  const _VistaConfirmarSos({
    required this.paso,
    required this.capacidades,
    required this.telefono,
    required this.onEnviar,
    required this.onCancelar,
  });

  final PasoSos paso;
  final Capacidades capacidades;
  final TelefonoService telefono;
  final VoidCallback onEnviar;
  final VoidCallback onCancelar;

  @override
  Widget build(BuildContext context) {
    final enviando = paso == PasoSos.enviando;
    final fallo = paso == PasoSos.error;

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
          onPressed: enviando ? null : onEnviar,
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
          onPressed: enviando ? null : onCancelar,
          style: _crearEstiloContornoSos(),
          child: const Text('No, cancelar', textAlign: TextAlign.center),
        ),
      ],
    );
  }
}

class _VistaSosEnviada extends StatelessWidget {
  const _VistaSosEnviada({
    required this.conUbicacionExacta,
    required this.capacidades,
    required this.telefono,
    required this.onCerrar,
    required this.onVolver,
  });

  final bool conUbicacionExacta;
  final Capacidades capacidades;
  final TelefonoService telefono;
  final ValueChanged<CierreSos> onCerrar;
  final VoidCallback onVolver;

  @override
  Widget build(BuildContext context) {
    final estiloContorno = _crearEstiloContornoSos();

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
          child: const Text(
            'Alerta enviada',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.sobreColor,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          conUbicacionExacta
              ? 'Avisamos a los vecinos de tu zona con tu ubicación exacta. '
                    'Si estás en peligro, llamá al 911.'
              : 'Avisamos a los vecinos de tu zona. Les mandamos la zona del '
                    'barrio, no tu ubicación exacta. '
                    'Si estás en peligro, llamá al 911.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.sobreColor, fontSize: 18),
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
          onPressed: () => onCerrar(CierreSos.aSalvo),
          style: estiloContorno,
          child: const Text('Ya estoy a salvo', textAlign: TextAlign.center),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => onCerrar(CierreSos.falsaAlarma),
          style: estiloContorno,
          child: const Text(
            'Fue una falsa alarma',
            textAlign: TextAlign.center,
          ),
        ),
        // Último: es la acción menos urgente. Sale sin cerrar la alerta.
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: onVolver,
          style: estiloContorno,
          icon: const Icon(Icons.arrow_back),
          label: const Text('Volver', textAlign: TextAlign.center),
        ),
      ],
    );
  }
}
