import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// Botón SOS flotante. Un solo toque abre la pantalla de confirmación,
/// donde se envía la alerta con otro toque: es lo más fácil para personas
/// mayores (no exige mantener el dedo apretado) y evita envíos accidentales.
///
/// Es el botón más grande de las pantallas principales (mínimo 184x88 dp)
/// y crece con el tamaño de texto del sistema.
class BotonSos extends StatelessWidget {
  const BotonSos({super.key, required this.onPressed});

  static const anchoMinimo = 184.0;
  static const altoMinimo = 88.0;

  final VoidCallback onPressed;

  void _tocar() {
    HapticFeedback.mediumImpact();
    onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: 'SOS. Pedir ayuda a los vecinos',
      onTap: _tocar,
      excludeSemantics: true,
      child: Material(
        color: AppColors.emergencia,
        elevation: 6,
        shape: const StadiumBorder(
          side: BorderSide(color: AppColors.superficie, width: 4),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _tocar,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: anchoMinimo,
              minHeight: altoMinimo,
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.campaign, color: AppColors.sobreColor, size: 34),
                  SizedBox(width: 10),
                  Text(
                    'SOS',
                    style: TextStyle(
                      color: AppColors.sobreColor,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
