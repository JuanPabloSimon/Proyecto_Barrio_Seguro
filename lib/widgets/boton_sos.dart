import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// Botón SOS: hay que mantenerlo presionado [duracion] para enviar la alerta.
/// Un anillo muestra el progreso; si se suelta antes, se cancela.
class BotonSos extends StatefulWidget {
  const BotonSos({super.key, required this.onActivado});

  static const duracion = Duration(seconds: 3);

  final VoidCallback onActivado;

  @override
  State<BotonSos> createState() => _BotonSosState();
}

class _BotonSosState extends State<BotonSos> with SingleTickerProviderStateMixin {
  late final AnimationController _progreso = AnimationController(
    vsync: this,
    duration: BotonSos.duracion,
    reverseDuration: const Duration(milliseconds: 250),
  )..addStatusListener(_alCambiarEstado);

  @override
  void dispose() {
    _progreso.dispose();
    super.dispose();
  }

  void _alCambiarEstado(AnimationStatus estado) {
    if (estado != AnimationStatus.completed) return;
    HapticFeedback.heavyImpact();
    _progreso.reset();
    widget.onActivado();
  }

  void _presionar() {
    HapticFeedback.selectionClick();
    _progreso.forward(from: 0);
  }

  void _soltar() {
    if (!_progreso.isAnimating || _progreso.status != AnimationStatus.forward) return;
    _progreso.reverse();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Mantené presionado SOS durante 3 segundos para enviar la alerta'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'SOS. Mantené presionado 3 segundos para enviar una alerta',
      child: Listener(
        onPointerDown: (_) => _presionar(),
        onPointerUp: (_) => _soltar(),
        onPointerCancel: (_) => _soltar(),
        child: AnimatedBuilder(
          animation: _progreso,
          builder: (context, _) {
            return SizedBox(
              width: 92,
              height: 92,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 92,
                    height: 92,
                    child: CircularProgressIndicator(
                      value: _progreso.value,
                      strokeWidth: 6,
                      color: AppColors.emergencia,
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                  Transform.scale(
                    scale: 1 - 0.08 * _progreso.value,
                    child: Container(
                      width: 74,
                      height: 74,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.emergencia,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Text(
                        'SOS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
