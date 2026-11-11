import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../widgets/dialogo_911.dart';

/// Se abre al tocar el botón SOS. Primero pide confirmación con un botón
/// grande; recién al confirmar se envía la alerta y se muestran las
/// opciones siguientes.
class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  bool _enviada = false;

  void _enviar() {
    HapticFeedback.heavyImpact();
    setState(() => _enviada = true);
    // Avisa al lector de pantalla que cambió el contenido.
    SemanticsService.sendAnnouncement(
      View.of(context),
      'Alerta enviada a tus vecinos',
      Directionality.of(context),
    );
  }

  void _cerrar([String? mensaje]) {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    if (mensaje != null) {
      messenger.showSnackBar(SnackBar(content: Text(mensaje)));
    }
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
                  child: _enviada ? _vistaEnviada() : _vistaConfirmar(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _vistaConfirmar() {
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
        const Spacer(),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: _enviar,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.superficie,
            foregroundColor: AppColors.emergencia,
            minimumSize: const Size(64, 96),
            textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          child: const Text('Sí, enviar alerta', textAlign: TextAlign.center),
        ),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: () => _cerrar(),
          style: _estiloContorno,
          child: const Text('No, cancelar', textAlign: TextAlign.center),
        ),
      ],
    );
  }

  Widget _vistaEnviada() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        const ExcludeSemantics(
          child: Icon(Icons.check_circle_outline, color: AppColors.sobreColor, size: 96),
        ),
        const SizedBox(height: 16),
        Semantics(
          header: true,
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
        const Text(
          'Avisamos a los vecinos de tu zona con tu ubicación. '
          'Si estás en peligro, llamá al 911.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.sobreColor, fontSize: 18),
        ),
        const Spacer(),
        const SizedBox(height: 32),
        FilledButton.icon(
          onPressed: () => mostrarDialogo911(context),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.superficie,
            foregroundColor: AppColors.emergencia,
            minimumSize: const Size(64, 80),
            textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          icon: const Icon(Icons.phone, size: 28),
          label: const Text('Llamar al 911'),
        ),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: () => _cerrar('Marcaste la alerta como resuelta'),
          style: _estiloContorno,
          child: const Text('Ya estoy a salvo', textAlign: TextAlign.center),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => _cerrar('Cancelaste la alerta: fue una falsa alarma'),
          style: _estiloContorno,
          child: const Text('Fue una falsa alarma', textAlign: TextAlign.center),
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
