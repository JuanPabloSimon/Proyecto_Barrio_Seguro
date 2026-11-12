import 'package:flutter/material.dart';

import '../tema/app_colors.dart';

/// Lo que se ve mientras llegan los datos.
class IndicadorDeCarga extends StatelessWidget {
  const IndicadorDeCarga({super.key, this.mensaje = 'Cargando'});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Center(child: CircularProgressIndicator(semanticsLabel: mensaje));
  }
}

/// Lo que se ve si no se pudieron traer los datos, con un botón para
/// volver a intentar. El mensaje no desaparece solo.
class MensajeDeError extends StatelessWidget {
  const MensajeDeError({
    super.key,
    required this.onReintentar,
    this.mensaje = 'No pudimos cargar los datos. Revisá tu conexión.',
  });

  final VoidCallback onReintentar;
  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ExcludeSemantics(
              child: Icon(
                Icons.wifi_off,
                size: 48,
                color: AppColors.textoSecundario,
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(mensaje, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onReintentar,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
