/// Cálculos con fechas que usa toda la app. Funciones puras: no dependen de
/// Flutter ni de la hora actual (la reciben por parámetro cuando la usan).
library;

/// Convierte "dd/mm/aaaa" en fecha. Devuelve null si no es una fecha válida
/// o si es posterior a [hoy].
DateTime? parsearFecha(String texto, {required DateTime hoy}) {
  final coincidencia = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(texto);
  if (coincidencia == null) return null;

  final dia = int.parse(coincidencia.group(1)!);
  final mes = int.parse(coincidencia.group(2)!);
  final anio = int.parse(coincidencia.group(3)!);
  final fecha = DateTime(anio, mes, dia);

  // DateTime acepta valores como 31/02 y los corre al mes siguiente.
  final esValida = fecha.day == dia && fecha.month == mes && fecha.year == anio;
  if (!esValida || anio < 1900 || fecha.isAfter(hoy)) return null;
  return fecha;
}

/// Años cumplidos a la fecha [hoy].
int calcularEdad(DateTime nacimiento, {required DateTime hoy}) {
  var edad = hoy.year - nacimiento.year;
  final todaviaNoCumplio =
      hoy.month < nacimiento.month ||
      (hoy.month == nacimiento.month && hoy.day < nacimiento.day);
  if (todaviaNoCumplio) edad--;
  return edad;
}

bool mismoDia(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool mismoMes(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;
