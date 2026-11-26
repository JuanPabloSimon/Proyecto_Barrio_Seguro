import '../../domain/models/alerta.dart';

/// Nombres visibles de cada estado. Puro Dart: lo usan las vistas y los
/// ViewModels. Los íconos y colores están en presentacion_alerta.dart,
/// solo para las vistas.
extension TextosEstado on EstadoAlerta {
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
}
