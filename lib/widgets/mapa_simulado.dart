import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/alerta.dart';
import '../theme/app_colors.dart';

/// Mapa dibujado a mano para el prototipo. En el Sprint 2 se reemplaza
/// por la API de mapas real, manteniendo los mismos pines y el radio.
class MapaSimulado extends StatelessWidget {
  const MapaSimulado({
    super.key,
    required this.alertas,
    this.onAlertaTap,
    this.mostrarRadio = true,
    this.tamanioPin = 36,
  });

  final List<Alerta> alertas;
  final ValueChanged<Alerta>? onAlertaTap;
  final bool mostrarRadio;
  final double tamanioPin;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ancho = constraints.maxWidth;
        final alto = constraints.maxHeight;
        final radio = math.min(ancho, alto) * 0.32;

        return ClipRect(
          child: Stack(
            children: [
              const Positioned.fill(child: CustomPaint(painter: _CallesPainter())),
              if (mostrarRadio)
                Positioned(
                  left: ancho / 2 - radio,
                  top: alto / 2 - radio,
                  child: Container(
                    width: radio * 2,
                    height: radio * 2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.radio.withValues(alpha: 0.12),
                      border: Border.all(
                        color: AppColors.radio.withValues(alpha: 0.6),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: ancho / 2 - 9,
                top: alto / 2 - 9,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.radio,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                ),
              ),
              for (final alerta in alertas)
                Positioned(
                  left: alerta.posicion.dx * ancho - tamanioPin / 2,
                  top: alerta.posicion.dy * alto - tamanioPin,
                  child: GestureDetector(
                    onTap: onAlertaTap == null ? null : () => onAlertaTap!(alerta),
                    child: Icon(
                      Icons.location_on,
                      size: tamanioPin,
                      color: alerta.estado.color,
                      shadows: const [Shadow(color: Colors.black26, blurRadius: 4)],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CallesPainter extends CustomPainter {
  const _CallesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFE9ECE6));

    final calle = Paint()
      ..color = Colors.white
      ..strokeWidth = 8;
    for (var i = 1; i < 6; i++) {
      final x = size.width * i / 6;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), calle);
    }
    for (var i = 1; i < 5; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), calle);
    }

    final avenida = Paint()
      ..color = const Color(0xFFFFF1CC)
      ..strokeWidth = 14;
    canvas.drawLine(
      Offset(0, size.height * 0.92),
      Offset(size.width, size.height * 0.08),
      avenida,
    );

    // Plaza
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.185,
          size.height * 0.42,
          size.width * 0.13,
          size.height * 0.16,
        ),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0xFFCFE3C8),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
