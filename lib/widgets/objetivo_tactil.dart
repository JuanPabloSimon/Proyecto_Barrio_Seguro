import 'package:flutter/material.dart';

/// Envuelve un elemento tocable para garantizar un área táctil de al menos
/// 48x48 dp aunque lo visible sea más chico, y lo anuncia en lectores de
/// pantalla como un solo botón con [etiqueta].
///
/// Usarlo para pines, celdas y cualquier tocable hecho a mano en vez de
/// agrandar el ícono o el texto.
class ObjetivoTactil extends StatelessWidget {
  const ObjetivoTactil({
    super.key,
    required this.etiqueta,
    required this.onTap,
    required this.child,
    this.seleccionado,
    this.forma = const CircleBorder(),
  });

  /// Lado mínimo del área táctil (Android pide 48 dp; iOS, 44 pt).
  static const tamanioMinimo = 48.0;

  /// Separación mínima entre dos objetivos táctiles vecinos.
  static const separacion = 8.0;

  /// Lo que lee el lector de pantalla, por ejemplo "Viernes 9 de octubre,
  /// tenés turno".
  final String etiqueta;
  final VoidCallback onTap;
  final Widget child;

  /// Si no es null, se anuncia como elemento seleccionable.
  final bool? seleccionado;

  /// Forma del efecto al tocar.
  final ShapeBorder forma;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      selected: seleccionado,
      label: etiqueta,
      onTap: onTap,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: tamanioMinimo,
          minHeight: tamanioMinimo,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            customBorder: forma,
            child: Center(widthFactor: 1, heightFactor: 1, child: child),
          ),
        ),
      ),
    );
  }
}
