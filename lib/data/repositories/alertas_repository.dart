import 'package:latlong2/latlong.dart' show LatLng;

import '../../domain/models/alerta.dart';
import '../services/alertas_service.dart';

/// Fuente de verdad de las alertas del barrio.
abstract class AlertasRepository {
  /// Todas las alertas, de la más nueva a la más vieja. Con [refrescar] las
  /// vuelve a pedir aunque las tenga en caché.
  Future<List<Alerta>> obtenerAlertas({bool refrescar = false});

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

class AlertasRepositoryRemoto implements AlertasRepository {
  AlertasRepositoryRemoto({required this._service});

  final AlertasService _service;
  List<Alerta>? _cache;

  @override
  Future<List<Alerta>> obtenerAlertas({bool refrescar = false}) async {
    final enCache = _cache;
    if (enCache != null && !refrescar) return enCache;

    final crudas = await _service.obtenerAlertas();
    final alertas = crudas.map(Alerta.fromJson).toList()
      ..sort((a, b) => b.creadaEn.compareTo(a.creadaEn));
    _cache = List.unmodifiable(alertas);
    return _cache!;
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
    return alerta;
  }
}
