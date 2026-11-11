import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Cada estado tiene texto, ícono y color: la información nunca depende
/// solo del color.
enum EstadoAlerta {
  activa(
    'Activa',
    'Activas',
    Icons.priority_high,
    AppColors.emergencia,
    AppColors.emergenciaSuave,
  ),
  enAtencion(
    'En atención',
    'En atención',
    Icons.directions_run,
    AppColors.alerta,
    AppColors.alertaSuave,
  ),
  resuelta(
    'Resuelta',
    'Resueltas',
    Icons.check,
    AppColors.resuelta,
    AppColors.resueltaSuave,
  );

  const EstadoAlerta(
    this.etiqueta,
    this.etiquetaFiltro,
    this.icono,
    this.color,
    this.colorSuave,
  );

  final String etiqueta;
  final String etiquetaFiltro;
  final IconData icono;

  /// Color sólido: lleva texto e íconos blancos encima.
  final Color color;

  /// Fondo suave para íconos del color sólido.
  final Color colorSuave;
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
    required this.reportadaPor,
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

  /// Id del vecino que la reportó.
  final String reportadaPor;
}
