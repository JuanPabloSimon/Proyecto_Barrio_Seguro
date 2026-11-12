import 'package:flutter/material.dart';

/// Tarjeta que se toca entera. El lector de pantalla la anuncia como un solo
/// botón con [etiqueta] (por ejemplo "Alerta de intento de robo, hace 1
/// hora, activa") en vez de leer cada texto suelto.
class TarjetaTocable extends StatelessWidget {
  const TarjetaTocable({
    super.key,
    required this.etiqueta,
    required this.onTap,
    required this.child,
    this.color,
    this.forma,
    this.padding = const EdgeInsets.all(16),
  });

  final String etiqueta;
  final VoidCallback onTap;
  final Widget child;
  final Color? color;
  final ShapeBorder? forma;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: etiqueta,
      onTap: onTap,
      excludeSemantics: true,
      child: Card(
        color: color,
        shape: forma,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
