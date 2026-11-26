import 'models/turno.dart';
import 'models/vecino.dart';

/// Cuándo un turno no se realiza y cuándo se le avisa al vecino que quedó
/// solo. Funciones puras: la hora llega por parámetro.
///
/// No está en `ReglasTurnos` ni se duplica en el backend: el servidor no
/// rechaza ni cambia nada por esta regla, solo decide qué muestra la app.
class ReglasTurnoIncompleto {
  ReglasTurnoIncompleto._();

  /// Desde cuánto antes del inicio se ve el aviso.
  static const anticipacionAviso = Duration(minutes: 30);

  /// Exactamente una persona anotada.
  static bool estaIncompleto(Turno turno) => turno.personasAnotadas == 1;

  /// Dos o más personas anotadas.
  static bool seRealiza(Turno turno) => turno.personasAnotadas >= 2;

  /// [ahora] en [inicio − anticipacionAviso, fin).
  static bool estaEnVentanaDeAviso(Turno turno, DateTime ahora) =>
      !ahora.isBefore(turno.inicio.subtract(anticipacionAviso)) &&
      ahora.isBefore(turno.fin);

  /// Los turnos de [turnos] en los que está [vecino], incompletos y en
  /// ventana de aviso, sin repetir (fecha + franja) y ordenados por inicio.
  /// No sabe nada de cierres: eso lo filtra el ViewModel.
  static List<Turno> paraAvisar({
    required Iterable<Turno> turnos,
    required Vecino vecino,
    required DateTime ahora,
  }) {
    final porClave = <String, Turno>{};
    for (final turno in turnos) {
      if (turno.incluye(vecino) &&
          estaIncompleto(turno) &&
          estaEnVentanaDeAviso(turno, ahora)) {
        porClave.putIfAbsent(claveDeCierre(vecino, turno), () => turno);
      }
    }
    return porClave.values.toList()
      ..sort((a, b) => a.inicio.compareTo(b.inicio));
  }

  /// True si [vecino] está en algún turno de [turnos] (incompleto o no)
  /// cuya ventana de aviso incluye [ahora]: hay que refrescar.
  static bool tieneTurnoEnVentana({
    required Iterable<Turno> turnos,
    required Vecino vecino,
    required DateTime ahora,
  }) => turnos.any((t) => t.incluye(vecino) && estaEnVentanaDeAviso(t, ahora));

  /// El mes de la fecha de [ahora] y el de la fecha anterior, como
  /// `DateTime(anio, mes)`, sin repetir: [mes de hoy] o [mes de hoy, mes
  /// de ayer].
  static List<DateTime> mesesParaAvisar(DateTime ahora) {
    final hoy = DateTime(ahora.year, ahora.month);
    final fechaDeAyer = DateTime(ahora.year, ahora.month, ahora.day - 1);
    final ayer = DateTime(fechaDeAyer.year, fechaDeAyer.month);
    return [hoy, if (ayer != hoy) ayer];
  }

  /// True si [vecino] es la guardia de ventana de [turno] (por id). Es el
  /// lugar que ocupa en ese turno, no su edad ni su preferencia.
  static bool esGuardiaVentanaEn(Turno turno, Vecino vecino) =>
      turno.guardiaVentana?.id == vecino.id;

  /// `'<vecino.id>|<aaaa-mm-dd>|<franja.name>'`, por ejemplo
  /// 'v3|2026-10-09|noche'.
  static String claveDeCierre(Vecino vecino, Turno turno) {
    final f = turno.fecha;
    final mes = f.month.toString().padLeft(2, '0');
    final dia = f.day.toString().padLeft(2, '0');
    return '${vecino.id}|${f.year}-$mes-$dia|${turno.franja.name}';
  }
}
