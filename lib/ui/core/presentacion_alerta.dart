import 'package:flutter/material.dart';

import '../../domain/models/alerta.dart';
import 'tema/app_colors.dart';

/// Cómo se muestra cada estado: texto, ícono y color (nunca solo color).
/// Vive en la capa de UI porque el modelo de dominio no conoce Flutter.
extension PresentacionEstado on EstadoAlerta {
  String get etiqueta => switch (this) {
    EstadoAlerta.activa => 'Activa',
    EstadoAlerta.enAtencion => 'En atención',
    EstadoAlerta.resuelta => 'Resuelta',
  };

  /// Texto de la pastilla de filtro del mapa.
  String get etiquetaFiltro => switch (this) {
    EstadoAlerta.activa => 'Activas',
    EstadoAlerta.enAtencion => 'En atención',
    EstadoAlerta.resuelta => 'Resueltas',
  };

  IconData get icono => switch (this) {
    EstadoAlerta.activa => Icons.priority_high,
    EstadoAlerta.enAtencion => Icons.directions_run,
    EstadoAlerta.resuelta => Icons.check,
  };

  /// Color sólido: lleva texto e íconos blancos encima.
  Color get color => switch (this) {
    EstadoAlerta.activa => AppColors.emergencia,
    EstadoAlerta.enAtencion => AppColors.alerta,
    EstadoAlerta.resuelta => AppColors.resuelta,
  };

  /// Fondo suave para íconos del color sólido.
  Color get colorSuave => switch (this) {
    EstadoAlerta.activa => AppColors.emergenciaSuave,
    EstadoAlerta.enAtencion => AppColors.alertaSuave,
    EstadoAlerta.resuelta => AppColors.resueltaSuave,
  };
}

extension PresentacionCategoria on CategoriaAlerta {
  IconData get icono => switch (this) {
    CategoriaAlerta.sos => Icons.campaign,
    CategoriaAlerta.actividadSospechosa => Icons.visibility_outlined,
    CategoriaAlerta.vehiculo => Icons.two_wheeler,
    CategoriaAlerta.robo => Icons.lock_open,
    CategoriaAlerta.arrebato => Icons.phone_android,
    CategoriaAlerta.ruidos => Icons.hearing,
  };
}
