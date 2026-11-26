import 'package:flutter/material.dart';

import '../../domain/models/alerta.dart';
import 'tema/app_colors.dart';

export 'textos_estado.dart';

/// Íconos y colores de cada estado (nunca solo color): solo para las
/// vistas. Los nombres visibles están en textos_estado.dart, que se
/// exporta desde acá para que las vistas sigan con un solo import.
/// Vive en la capa de UI porque el modelo de dominio no conoce Flutter.
extension PresentacionEstado on EstadoAlerta {
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
