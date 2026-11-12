import '../../domain/models/turno.dart';
import '../../domain/models/vecino.dart';
import '../services/local/turnos_dao.dart';
import '../services/turnos_service.dart';

/// Fuente de verdad de los turnos de patrullaje.
abstract class TurnosRepository {
  /// Turnos con al menos un vecino anotado en el mes de [mes].
  ///
  /// Sin conexión devuelve la copia guardada en el teléfono, si hay una.
  Future<List<Turno>> obtenerTurnos(DateTime mes, {bool refrescar = false});

  /// True si lo último que devolvió [obtenerTurnos] es la copia guardada
  /// porque no hubo conexión.
  bool get sinConexion;

  Future<Turno> anotarse(Vecino vecino, DateTime fecha, Franja franja);

  Future<Turno> salir(Vecino vecino, DateTime fecha, Franja franja);
}

/// Como `AlertasRepositoryRemoto`: caché en memoria por mes y copia en el
/// teléfono con [dao] para ver los turnos sin conexión.
class TurnosRepositoryRemoto implements TurnosRepository {
  TurnosRepositoryRemoto({required this._service, this._dao});

  final TurnosService _service;
  final TurnosDao? _dao;

  bool _sinConexion = false;
  @override
  bool get sinConexion => _sinConexion;

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
    if (enCache != null && !refrescar && !_sinConexion) return enCache;

    final List<Map<String, dynamic>> crudos;
    try {
      crudos = await _service.obtenerTurnos(anio: mes.year, mes: mes.month);
    } catch (_) {
      final guardados = await _leerCopia(mes);
      if (guardados.isEmpty) rethrow;
      _sinConexion = true;
      return _cache[clave] = List.unmodifiable(guardados);
    }

    final turnos = List<Turno>.unmodifiable(crudos.map(Turno.fromJson));
    _sinConexion = false;
    _cache[clave] = turnos;
    await _guardarCopia((dao) => dao.reemplazarMes(mes, turnos));
    return turnos;
  }

  Future<List<Turno>> _leerCopia(DateTime mes) async {
    try {
      return await _dao?.delMes(mes) ?? const [];
    } catch (_) {
      return const [];
    }
  }

  /// Si la copia local falla, la app sigue: el dato ya llegó del servidor.
  Future<void> _guardarCopia(
    Future<void> Function(TurnosDao dao) guardar,
  ) async {
    final dao = _dao;
    if (dao == null) return;
    try {
      await guardar(dao);
    } catch (_) {}
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

  /// Reemplaza (o agrega) el turno en la caché de su mes y en la copia
  /// del teléfono.
  Future<Turno> _actualizarCache(Turno turno) async {
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
    await _guardarCopia((dao) => dao.guardar(turno));
    return turno;
  }
}
