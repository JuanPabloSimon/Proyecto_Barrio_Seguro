// Utilidades de fechas en español, sin dependencias externas.

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

/// Convierte "dd/mm/aaaa" en fecha. Devuelve null si no es una fecha válida
/// o si está en el futuro.
DateTime? parsearFecha(String texto) {
  final coincidencia = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(texto);
  if (coincidencia == null) return null;

  final dia = int.parse(coincidencia.group(1)!);
  final mes = int.parse(coincidencia.group(2)!);
  final anio = int.parse(coincidencia.group(3)!);
  final fecha = DateTime(anio, mes, dia);

  // DateTime acepta valores como 31/02 y los corre al mes siguiente.
  final esValida = fecha.day == dia && fecha.month == mes && fecha.year == anio;
  if (!esValida || anio < 1900 || fecha.isAfter(DateTime.now())) return null;
  return fecha;
}

int calcularEdad(DateTime nacimiento, [DateTime? hoy]) {
  final referencia = hoy ?? DateTime.now();
  var edad = referencia.year - nacimiento.year;
  final todaviaNoCumplio = referencia.month < nacimiento.month ||
      (referencia.month == nacimiento.month && referencia.day < nacimiento.day);
  if (todaviaNoCumplio) edad--;
  return edad;
}

bool mismoDia(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
