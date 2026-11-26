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

/// Aviso de una alerta resuelta que se volvió a abrir (feature
/// estado_alerta, R46): "Se reabrió una alerta: Robo".
String tituloAvisoReapertura(Alerta alerta) =>
    'Se reabrió una alerta: ${tipoParaAviso(alerta)}';

/// R47. El título de [tituloAvisoReapertura] con la hora de la reapertura:
/// "Se reabrió una alerta: Robo 15:10".
String tituloAvisoReaperturaTardia(Alerta alerta, DateTime reabiertaEn) =>
    '${tituloAvisoReapertura(alerta)} ${horaYMinutos(reabiertaEn)}';

/// R46. "`<dirección>`. Tocá para ver dónde."; sin dirección, "Tocá para ver
/// dónde.".
String cuerpoAvisoReapertura(Alerta alerta) {
  final direccion = alerta.direccion.trim();
  return direccion.isEmpty
      ? 'Tocá para ver dónde.'
      : '$direccion. Tocá para ver dónde.';
}

/// estado_alerta R60 a R62. El vigilante no conoce `reabierta_en`: solo
/// sabe que la reapertura pasó entre [revisionAnterior] y [ahora]. Con
/// más de [demoraMaximaParaAvisar] entre las dos, la trata como tardía.
/// Una diferencia negativa (cambió la hora del teléfono) no es tardía.
bool reaperturaDelVigilanteTardia({
  required DateTime revisionAnterior,
  required DateTime ahora,
}) => ahora.difference(revisionAnterior) > demoraMaximaParaAvisar;
