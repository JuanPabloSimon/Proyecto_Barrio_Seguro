import 'package:latlong2/latlong.dart' show LatLng;

import '../../domain/models/alerta.dart';
import '../services/alertas_service.dart';
import '../services/local/alertas_dao.dart';

/// Fuente de verdad de las alertas del barrio.
abstract class AlertasRepository {
  /// Todas las alertas, de la más nueva a la más vieja. Con [refrescar] las
  /// vuelve a pedir aunque las tenga en caché.
  ///
  /// Sin conexión devuelve la copia guardada en el teléfono, si hay una.
  Future<List<Alerta>> obtenerAlertas({bool refrescar = false});

  /// True si lo último que devolvió [obtenerAlertas] es la copia guardada
  /// porque no hubo conexión.
  bool get sinConexion;

  Future<Alerta> crearAlerta({
    required CategoriaAlerta categoria,
    required String tipo,
    required String descripcion,
    required String direccion,
    required LatLng ubicacion,
    required String reportadaPor,
  });

  Future<Alerta> cambiarEstado(String id, EstadoAlerta estado);
}

/// Pide las alertas al servidor y guarda una copia en memoria (para no
/// pedirlas de nuevo en cada pantalla) y otra en el teléfono, con [dao],
/// para verlas sin conexión. Sin [dao] (en la web o en pruebas) solo usa la
/// memoria.
class AlertasRepositoryRemoto implements AlertasRepository {
  AlertasRepositoryRemoto({required this._service, this._dao});

  final AlertasService _service;
  final AlertasDao? _dao;
  List<Alerta>? _cache;

  bool _sinConexion = false;
  @override
  bool get sinConexion => _sinConexion;

  @override
  Future<List<Alerta>> obtenerAlertas({bool refrescar = false}) async {
    final enCache = _cache;
    if (enCache != null && !refrescar && !_sinConexion) return enCache;

    final List<Map<String, dynamic>> crudas;
    try {
      crudas = await _service.obtenerAlertas();
    } catch (_) {
      final guardadas = await _leerCopia();
      if (guardadas.isEmpty) rethrow;
      _sinConexion = true;
      return _cache = List.unmodifiable(guardadas);
    }

    final alertas = crudas.map(Alerta.fromJson).toList()
      ..sort((a, b) => b.creadaEn.compareTo(a.creadaEn));
    _sinConexion = false;
    _cache = List.unmodifiable(alertas);
    await _guardarCopia((dao) => dao.reemplazarTodas(alertas));
    return _cache!;
  }

  Future<List<Alerta>> _leerCopia() async {
    try {
      return await _dao?.listar() ?? const [];
    } catch (_) {
      return const [];
    }
  }

  /// Si la copia local falla, la app sigue: el dato ya llegó del servidor.
  Future<void> _guardarCopia(
    Future<void> Function(AlertasDao dao) guardar,
  ) async {
    final dao = _dao;
    if (dao == null) return;
    try {
      await guardar(dao);
    } catch (_) {}
  }

  @override
  Future<Alerta> crearAlerta({
    required CategoriaAlerta categoria,
    required String tipo,
    required String descripcion,
    required String direccion,
    required LatLng ubicacion,
    required String reportadaPor,
  }) async {
    final json = await _service.crearAlerta({
      'categoria': categoria.valorApi,
      'tipo': tipo,
      'descripcion': descripcion,
      'direccion': direccion,
      'latitud': ubicacion.latitude,
      'longitud': ubicacion.longitude,
      'reportada_por': reportadaPor,
    });
    final alerta = Alerta.fromJson(json);
    final enCache = _cache;
    if (enCache != null) _cache = List.unmodifiable([alerta, ...enCache]);
    await _guardarCopia((dao) => dao.guardar(alerta));
    return alerta;
  }

  @override
  Future<Alerta> cambiarEstado(String id, EstadoAlerta estado) async {
    final alerta = Alerta.fromJson(
      await _service.cambiarEstado(id, estado.valorApi),
    );
    final enCache = _cache;
    if (enCache != null) {
      _cache = List.unmodifiable([
        for (final a in enCache) a.id == id ? alerta : a,
      ]);
    }
    await _guardarCopia((dao) => dao.guardar(alerta));
    return alerta;
  }
}
