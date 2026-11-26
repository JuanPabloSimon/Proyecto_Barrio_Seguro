import 'dart:async';

import '../../domain/models/turno.dart';
import '../../domain/models/vecino.dart';
import '../services/error_del_servidor.dart';
import '../services/local/turnos_dao.dart';
import '../services/turnos_service.dart';
import 'conexion_repository.dart';
import 'futuro_con_estado.dart';

/// Fuente de verdad de los turnos de patrullaje.
abstract class TurnosRepository {
  /// Turnos con al menos un vecino anotado en el mes de [mes].
  ///
  /// Si el pedido falla, devuelve la copia guardada en el teléfono (la
  /// caché), si hay una, y marca [sinConexion].
  Future<List<Turno>> obtenerTurnos(DateTime mes, {bool refrescar = false});

  /// True si lo último que devolvió [obtenerTurnos] es la copia guardada
  /// porque no hubo conexión.
  bool get sinConexion;

  Future<Turno> anotarse(Vecino vecino, DateTime fecha, Franja franja);

  Future<Turno> salir(Vecino vecino, DateTime fecha, Franja franja);
}

/// Como `AlertasRepositoryRemoto`: mantiene un [FuturoConEstado] por mes
/// (para deduplicar pedidos concurrentes y guardar caché en memoria) y una
/// copia en el teléfono con [dao] que sirve de caché. Con [conexion], si el
/// pedido falla por la red, pide una comprobación de la conexión.
class TurnosRepositoryRemoto implements TurnosRepository {
  TurnosRepositoryRemoto({required this._service, this._dao, this._conexion});

  final TurnosService _service;
  final TurnosDao? _dao;
  final ConexionRepository? _conexion;

  bool _sinConexion = false;
  @override
  bool get sinConexion => _sinConexion;

  /// Un [FuturoConEstado] por mes ("2026-10"): cada mes se pide una sola vez
  /// y las llamadas simultáneas comparten el mismo [Future] en vuelo.
  final Map<String, FuturoConEstado<List<Turno>>> _pedidos = {};

  String _claveMes(DateTime fecha) => '${fecha.year}-${fecha.month}';

  /// Estado actual del [Future] correspondiente a [mes].
  EstadoFuturo estadoDelMes(DateTime mes) =>
      _pedidos[_claveMes(mes)]?.estado ?? EstadoFuturo.inicial;

  /// "2026-10-09": el formato de fechas que usa la API.
  String _fechaApi(DateTime fecha) => fecha.toIso8601String().substring(0, 10);

  @override
  Future<List<Turno>> obtenerTurnos(DateTime mes, {bool refrescar = false}) {
    final pedido = _pedidos.putIfAbsent(
      _claveMes(mes),
      FuturoConEstado<List<Turno>>.new,
    );
    return pedido.ejecutar(
      () => _cargarTurnos(mes),
      refrescar: refrescar || _sinConexion,
    );
  }

  Future<List<Turno>> _cargarTurnos(DateTime mes) async {
    final List<Map<String, dynamic>> crudos;
    try {
      crudos = await _service.obtenerTurnos(anio: mes.year, mes: mes.month);
    } catch (error) {
      // Un error de red (no uno de la API) puede querer decir que se cortó
      // la conexión: se comprueba ya, sin esperar el resultado.
      final conexion = _conexion;
      if (error is! ErrorDelServidor && conexion != null) {
        unawaited(conexion.comprobar());
      }
      final guardados = await _leerCopia(mes);
      if (guardados.isEmpty) rethrow;
      _sinConexion = true;
      return List.unmodifiable(guardados);
    }

    final turnos = List<Turno>.unmodifiable(crudos.map(Turno.fromJson));
    _sinConexion = false;
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
    final pedido = _pedidos[clave];
    final enCache = pedido?.valor;
    if (pedido != null && enCache != null) {
      bool esElMismo(Turno t) =>
          _fechaApi(t.fecha) == _fechaApi(turno.fecha) &&
          t.franja == turno.franja;
      pedido.fijarValor(
        List.unmodifiable([
          for (final t in enCache)
            if (!esElMismo(t)) t,
          turno,
        ]),
      );
    }
    await _guardarCopia((dao) => dao.guardar(turno));
    return turno;
  }
}
