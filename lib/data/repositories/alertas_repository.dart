import 'dart:async';

import 'package:latlong2/latlong.dart' show LatLng;

import '../../domain/models/alerta.dart';
import '../services/alertas_service.dart';
import '../services/error_del_servidor.dart';
import '../services/local/alertas_dao.dart';
import 'conexion_repository.dart';
import 'futuro_con_estado.dart';

/// Fuente de verdad de las alertas del barrio.
abstract class AlertasRepository {
  /// Todas las alertas, de la más nueva a la más vieja. Con [refrescar] las
  /// vuelve a pedir aunque las tenga en caché.
  ///
  /// Si el pedido falla, devuelve la copia guardada en el teléfono (la
  /// caché), si hay una, y marca [sinConexion].
  Future<List<Alerta>> obtenerAlertas({bool refrescar = false});

  /// True si lo último que devolvió [obtenerAlertas] es la copia guardada
  /// porque no hubo conexión.
  bool get sinConexion;

  /// La app requiere conexión: si el pedido falla (por la red o porque la
  /// API la rechaza, con ErrorDelServidor), lanza el error y no guarda
  /// nada para mandarlo después.
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

/// Pide las alertas al servidor manteniendo un [FuturoConEstado] (para no
/// disparar pedidos duplicados mientras carga ni pedirlas de nuevo en cada
/// pantalla) y guarda una copia en el teléfono, con [dao], que sirve de
/// caché. Sin [dao] (en la web o en pruebas) solo usa la memoria.
///
/// Con [conexion], cada vez que un pedido falla por la red (no cuando la
/// API responde con un error) pide una comprobación de la conexión, para
/// que la app tape las pantallas sin esperar al próximo ciclo.
class AlertasRepositoryRemoto implements AlertasRepository {
  AlertasRepositoryRemoto({required this._service, this._dao, this._conexion});

  final AlertasService _service;
  final AlertasDao? _dao;
  final ConexionRepository? _conexion;
  final FuturoConEstado<List<Alerta>> _pedido = FuturoConEstado<List<Alerta>>();

  /// Estado actual del [Future] de carga de alertas (`inicial`, `cargando`,
  /// `exito` o `error`).
  EstadoFuturo get estado => _pedido.estado;

  /// El contenedor del [Future] con estado de las alertas.
  FuturoConEstado<List<Alerta>> get pedido => _pedido;

  bool _sinConexion = false;
  @override
  bool get sinConexion => _sinConexion;

  @override
  Future<List<Alerta>> obtenerAlertas({bool refrescar = false}) {
    return _pedido.ejecutar(
      _cargarAlertas,
      refrescar: refrescar || _sinConexion,
    );
  }

  Future<List<Alerta>> _cargarAlertas() async {
    final List<Map<String, dynamic>> crudas;
    try {
      crudas = await _service.obtenerAlertas();
    } catch (error) {
      _avisarSiFueLaRed(error);
      final guardadas = await _leerCopia();
      if (guardadas.isEmpty) rethrow;
      _sinConexion = true;
      return List.unmodifiable(guardadas);
    }

    final alertas = crudas.map(Alerta.fromJson).toList()
      ..sort((a, b) => b.creadaEn.compareTo(a.creadaEn));
    _sinConexion = false;
    await _guardarCopia((dao) => dao.reemplazarTodas(alertas));
    return List.unmodifiable(alertas);
  }

  /// Un error de red (no uno de la API) puede querer decir que se cortó la
  /// conexión: se comprueba ya, sin esperar el resultado.
  void _avisarSiFueLaRed(Object error) {
    if (error is ErrorDelServidor) return;
    final conexion = _conexion;
    if (conexion != null) unawaited(conexion.comprobar());
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
    final datos = {
      'categoria': categoria.valorApi,
      'tipo': tipo,
      'descripcion': descripcion,
      'direccion': direccion,
      'latitud': ubicacion.latitude,
      'longitud': ubicacion.longitude,
      'reportada_por': reportadaPor,
    };

    final Alerta alerta;
    try {
      alerta = Alerta.fromJson(await _service.crearAlerta(datos));
    } catch (error) {
      // Sin conexión no se guarda nada para mandar después: el error llega
      // al vecino, que puede volver a intentar o llamar al 911.
      _avisarSiFueLaRed(error);
      rethrow;
    }

    _agregarALaCache(alerta);
    await _guardarCopia((dao) => dao.guardar(alerta));
    return alerta;
  }

  void _agregarALaCache(Alerta alerta) {
    final enCache = _pedido.valor;
    if (enCache != null) {
      _pedido.fijarValor(List.unmodifiable([alerta, ...enCache]));
    }
  }

  @override
  Future<Alerta> cambiarEstado(String id, EstadoAlerta estado) async {
    final alerta = Alerta.fromJson(
      await _service.cambiarEstado(id, estado.valorApi),
    );
    await _guardarCopia((dao) => dao.guardar(alerta));
    final enCache = _pedido.valor;
    if (enCache != null) {
      _pedido.fijarValor(
        List.unmodifiable([for (final a in enCache) a.id == id ? alerta : a]),
      );
    }
    return alerta;
  }
}
