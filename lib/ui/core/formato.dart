/// Textos con fechas en español para mostrar en pantalla.
library;

const diasCalendario = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

const _dias = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];

const _meses = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

String nombreDia(DateTime fecha) => _dias[fecha.weekday - 1];

/// "Vie", "Sáb", "Mié"...
String nombreDiaCorto(DateTime fecha) => nombreDia(fecha).substring(0, 3);

String nombreMes(int mes) => _meses[mes - 1];

/// "Viernes 9 de octubre"
String fechaLarga(DateTime fecha) =>
    '${nombreDia(fecha)} ${fecha.day} de ${nombreMes(fecha.month)}';

/// "Octubre 2026"
String mesYAnio(DateTime fecha) {
  final mes = nombreMes(fecha.month);
  return '${mes[0].toUpperCase()}${mes.substring(1)} ${fecha.year}';
}

/// "09/10/2026"
String fechaNumerica(DateTime fecha) {
  final dia = fecha.day.toString().padLeft(2, '0');
  final mes = fecha.month.toString().padLeft(2, '0');
  return '$dia/$mes/${fecha.year}';
}

/// "Hace 5 minutos", "Hace 1 hora", "Ayer a las 21:40", "Hace 3 días".
/// Sin abreviaturas: el lector de pantalla lee mal "min" o "h".
String tiempoTranscurrido(DateTime desde, DateTime ahora) {
  final diferencia = ahora.difference(desde);
  if (diferencia.inMinutes < 1) return 'Recién';
  if (diferencia.inMinutes < 60) {
    final minutos = diferencia.inMinutes;
    return minutos == 1 ? 'Hace 1 minuto' : 'Hace $minutos minutos';
  }

  final hoy = DateTime(ahora.year, ahora.month, ahora.day);
  final dia = DateTime(desde.year, desde.month, desde.day);
  final diasAtras = hoy.difference(dia).inDays;

  if (diasAtras == 0) {
    final horas = diferencia.inHours;
    return horas == 1 ? 'Hace 1 hora' : 'Hace $horas horas';
  }
  if (diasAtras == 1) {
    final hora = desde.hour.toString().padLeft(2, '0');
    final minutos = desde.minute.toString().padLeft(2, '0');
    return 'Ayer a las $hora:$minutos';
  }
  return 'Hace $diasAtras días';
}
