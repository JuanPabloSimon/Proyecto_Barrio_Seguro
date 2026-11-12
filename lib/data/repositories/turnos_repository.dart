import '../../domain/models/turno.dart';
import '../../domain/models/vecino.dart';
import '../services/turnos_service.dart';

/// Fuente de verdad de los turnos de patrullaje.
abstract class TurnosRepository {
  /// Turnos con al menos un vecino anotado en el mes de [mes].
  Future<List<Turno>> obtenerTurnos(DateTime mes, {bool refrescar = false});

  Future<Turno> anotarse(Vecino vecino, DateTime fecha, Franja franja);

  Future<Turno> salir(Vecino vecino, DateTime fecha, Franja franja);
}

class TurnosRepositoryRemoto implements TurnosRepository {
  TurnosRepositoryRemoto({required this._service});

  final TurnosService _service;

  /// Un mes por clave ("2026-10"): cada mes se pide una sola vez.
  final Map<String, List<Turno>> _cache = {};

  String _claveMes(DateTime fecha) => '${fecha.year}-${fecha.month}';

  /// "2026-10-09": el formato de fechas que usa la API.
  String _fechaApi(DateTime fecha) => fecha.toIso8601String().substring(0, 10);

  @override
  Future<List<Turno>> obtenerTurnos(
    DateTime mes, {
    bool refrescar = false,
  }) async {
    final clave = _claveMes(mes);
    final enCache = _cache[clave];
    if (enCache != null && !refrescar) return enCache;

    final crudos = await _service.obtenerTurnos(anio: mes.year, mes: mes.month);
    final turnos = List<Turno>.unmodifiable(crudos.map(Turno.fromJson));
    _cache[clave] = turnos;
    return turnos;
  }

  @override
  Future<Turno> anotarse(Vecino vecino, DateTime fecha, Franja franja) async {
    final json = await _service.anotarse(
      fecha: _fechaApi(fecha),
      franja: franja.name,
      vecinoId: vecino.id,
    );
    return _actualizarCache(Turno.fromJson(json));
  }

  @override
  Future<Turno> salir(Vecino vecino, DateTime fecha, Franja franja) async {
    final json = await _service.salir(
      fecha: _fechaApi(fecha),
      franja: franja.name,
      vecinoId: vecino.id,
    );
    return _actualizarCache(Turno.fromJson(json));
  }

  /// Reemplaza (o agrega) el turno en la caché de su mes.
  Turno _actualizarCache(Turno turno) {
    final clave = _claveMes(turno.fecha);
    final enCache = _cache[clave];
    if (enCache != null) {
      bool esElMismo(Turno t) =>
          _fechaApi(t.fecha) == _fechaApi(turno.fecha) &&
          t.franja == turno.franja;
      _cache[clave] = List.unmodifiable([
        for (final t in enCache)
          if (!esElMismo(t)) t,
        turno,
      ]);
    }
    return turno;
  }
}
