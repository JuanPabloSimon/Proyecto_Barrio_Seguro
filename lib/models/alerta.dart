import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum EstadoAlerta {
  activa('Activa', 'Activas', AppColors.emergencia),
  enAtencion('En atención', 'En atención', AppColors.alerta),
  resuelta('Resuelta', 'Resueltas', AppColors.resuelta);

  const EstadoAlerta(this.etiqueta, this.etiquetaFiltro, this.color);

  final String etiqueta;
  final String etiquetaFiltro;
  final Color color;
}

class Alerta {
  const Alerta({
    required this.id,
    required this.tipo,
    required this.descripcion,
    required this.direccion,
    required this.hace,
    required this.estado,
    required this.posicion,
    required this.icono,
    this.reportadaPorMi = false,
  });

  final String id;
  final String tipo;
  final String descripcion;
  final String direccion;
  final String hace;
  final EstadoAlerta estado;

  /// Posición relativa (de 0 a 1) sobre el mapa ilustrativo.
  final Offset posicion;
  final IconData icono;
  final bool reportadaPorMi;
}
