/// Reglas de los avisos que llegan con demora: cuándo un aviso es tardío y
/// qué dice. Puro Dart.
library;

import 'models/alerta.dart';

/// Hasta esta demora (inclusive) el aviso llegó a tiempo.
const demoraParaTardia = Duration(minutes: 5);

/// Con más demora que esto, el aviso ya no se muestra.
const demoraMaximaParaAvisar = Duration(hours: 2);

/// Cómo llegó el aviso de una alerta a este teléfono.
enum PuntualidadAviso { aTiempo, tardio, demasiadoTardio }

/// R1. [llegada] en hora del servidor (ver AvisosRecibidosRepository).
///
/// Una demora negativa (el desfase medido no es exacto) cuenta como a
/// tiempo.
PuntualidadAviso clasificarAviso({
  required DateTime creadaEn,
  required DateTime llegada,
}) {
  final demora = llegada.difference(creadaEn);
  if (demora <= demoraParaTardia) return PuntualidadAviso.aTiempo;
  if (demora <= demoraMaximaParaAvisar) return PuntualidadAviso.tardio;
  return PuntualidadAviso.demasiadoTardio;
}

/// tardio o demasiadoTardio.
bool esTardia(PuntualidadAviso puntualidad) =>
    puntualidad != PuntualidadAviso.aTiempo;

/// R16. Nombre corto de cada categoría para el título del aviso tardío.
extension NombreCortoCategoria on CategoriaAlerta {
  /// "SOS", "Actividad sospechosa", "Vehículo sospechoso", "Robo",
  /// "Ruidos"; null para arrebato, que ya no se puede reportar y queda solo
  /// para leer alertas viejas (su aviso usa el título de la alerta).
  String? get nombreCorto => switch (this) {
    CategoriaAlerta.sos => 'SOS',
    CategoriaAlerta.actividadSospechosa => 'Actividad sospechosa',
    CategoriaAlerta.vehiculo => 'Vehículo sospechoso',
    CategoriaAlerta.robo => 'Robo',
    CategoriaAlerta.arrebato => null,
    CategoriaAlerta.ruidos => 'Ruidos',
  };
}

/// R16. El nombre corto de la categoría o, si no tiene, el tipo tal cual.
String tipoParaAviso(Alerta alerta) =>
    alerta.categoria.nombreCorto ?? alerta.tipo;

/// "15:10", "09:05". Zona del teléfono, 24 h (R17).
String horaYMinutos(DateTime fecha) {
  final local = fecha.toLocal();
  final hora = local.hour.toString().padLeft(2, '0');
  final minutos = local.minute.toString().padLeft(2, '0');
  return '$hora:$minutos';
}

/// "SOS de Marta 15:10"; sin nombre, "SOS de un vecino 15:10" (R14, R16,
/// R18). La hora es la de la alerta, sin fecha (R17).
String tituloAvisoTardio(Alerta alerta) {
  final nombre = alerta.reportadaPorNombre.trim();
  final quien = nombre.isEmpty ? 'un vecino' : nombre;
  return '${tipoParaAviso(alerta)} de $quien ${horaYMinutos(alerta.creadaEn)}';
}

/// R14. Cuerpo del aviso tardío.
const cuerpoAvisoTardio =
    'Llegó con demora por falta de señal. Puede que ya no esté pasando.';
