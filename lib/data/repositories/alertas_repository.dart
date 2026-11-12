import 'package:latlong2/latlong.dart' show LatLng;

import '../../domain/models/alerta.dart';
import '../services/alertas_service.dart';
import '../services/error_del_servidor.dart';
import '../services/local/alertas_dao.dart';
import '../services/local/pendientes_dao.dart';
import '../services/reloj.dart';
import '../services/tareas/envio_de_pendientes.dart';
import '../services/tareas/tareas_service.dart';

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

  /// Si no hay señal, la alerta queda guardada en el teléfono y se envía
  /// sola cuando vuelve la conexión (ver [estaPendiente]). Si la API la
  /// rechaza, lanza ErrorDelServidor.
  Future<Alerta> crearAlerta({
    required CategoriaAlerta categoria,
    required String tipo,
    required String descripcion,
    required String direccion,
    required LatLng ubicacion,
    required String reportadaPor,
  });

  Future<Alerta> cambiarEstado(String id, EstadoAlerta estado);

  /// True si la alerta todavía no llegó al servidor.
  bool estaPendiente(String id);

  /// Manda las alertas pendientes, si hay señal. Se llama al abrir la app
  /// y al volver a primer plano.
  Future<void> enviarPendientes();
}

/// Pide las alertas al servidor y guarda una copia en memoria (para no
/// pedirlas de nuevo en cada pantalla) y otra en el teléfono, con [dao],
/// para verlas sin conexión. Sin [dao] (en la web o en pruebas) solo usa la
/// memoria.
///
/// Con [pendientes], las alertas creadas sin señal quedan guardadas y
/// [tareas] programa su envío para cuando vuelva la conexión.
class AlertasRepositoryRemoto implements AlertasRepository {
  AlertasRepositoryRemoto({
    required this._service,
    this._dao,
    this._pendientes,
    this._tareas = const TareasNinguna(),
    this._reloj = const RelojDelSistema(),
  });

  final AlertasService _service;
  final AlertasDao? _dao;
  final PendientesDao? _pendientes;
  final TareasService _tareas;
  final Reloj _reloj;
  List<Alerta>? _cache;

  /// Las alertas pendientes usan este prefijo más el id local de la base.
  static const _prefijoPendiente = 'pendiente-';

  bool _sinConexion = false;
  @override
  bool get sinConexion => _sinConexion;

  @override
  bool estaPendiente(String id) => id.startsWith(_prefijoPendiente);

  @override
  Future<List<Alerta>> obtenerAlertas({bool refrescar = false}) async {
    final enCache = _cache;
    if (enCache != null && !refrescar && !_sinConexion) return enCache;

    final List<Map<String, dynamic>> crudas;
    try {
      crudas = await _service.obtenerAlertas();
    } catch (_) {
      final guardadas = [...await _leerPendientes(), ...await _leerCopia()];
      if (guardadas.isEmpty) rethrow;
      _sinConexion = true;
      return _cache = List.unmodifiable(guardadas);
    }

    final alertas = crudas.map(Alerta.fromJson).toList()
      ..sort((a, b) => b.creadaEn.compareTo(a.creadaEn));
    _sinConexion = false;
    await _guardarCopia((dao) => dao.reemplazarTodas(alertas));
    // Las pendientes todavía no están en el servidor: se muestran igual.
    _cache = List.unmodifiable([...await _leerPendientes(), ...alertas]);
    return _cache!;
  }

  Future<List<Alerta>> _leerCopia() async {
    try {
      return await _dao?.listar() ?? const [];
    } catch (_) {
      return const [];
    }
  }

  Future<List<Alerta>> _leerPendientes() async {
    try {
      final pendientes = await _pendientes?.listar() ?? const [];
      return [
        for (final p in pendientes.reversed)
          Alerta.fromJson({
            ...p.datos,
            'id': '$_prefijoPendiente${p.id}',
            'estado': EstadoAlerta.activa.valorApi,
          }),
      ];
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
    } on ErrorDelServidor {
      rethrow; // la API la rechazó: guardarla no sirve
    } catch (_) {
      final pendiente = await _guardarPendiente(datos);
      if (pendiente == null) rethrow;
      return pendiente;
    }

    _agregarALaCache(alerta);
    await _guardarCopia((dao) => dao.guardar(alerta));
    return alerta;
  }

  /// Sin señal: la alerta queda en el teléfono y se programa su envío.
  Future<Alerta?> _guardarPendiente(Map<String, dynamic> datos) async {
    final pendientes = _pendientes;
    if (pendientes == null) return null;
    final conFecha = {
      ...datos,
      'creada_en': _reloj.ahora().millisecondsSinceEpoch,
    };
    final id = await pendientes.agregar(conFecha);
    try {
      await _tareas.programarEnvioDePendientes();
    } catch (_) {
      // Si no se pudo programar, se manda al volver a abrir la app.
    }
    final alerta = Alerta.fromJson({
      ...conFecha,
      'id': '$_prefijoPendiente$id',
      'estado': EstadoAlerta.activa.valorApi,
    });
    _agregarALaCache(alerta);
    return alerta;
  }

  void _agregarALaCache(Alerta alerta) {
    final enCache = _cache;
    if (enCache != null) _cache = List.unmodifiable([alerta, ...enCache]);
  }

  @override
  Future<Alerta> cambiarEstado(String id, EstadoAlerta estado) async {
    final Alerta alerta;
    if (estaPendiente(id)) {
      // Todavía no llegó al servidor: cerrarla es no mandarla.
      final actual = (_cache ?? await _leerPendientes()).firstWhere(
        (a) => a.id == id,
      );
      await _pendientes?.borrar(
        int.parse(id.substring(_prefijoPendiente.length)),
      );
      alerta = Alerta.fromJson({...actual.toJson(), 'estado': estado.valorApi});
    } else {
      alerta = Alerta.fromJson(
        await _service.cambiarEstado(id, estado.valorApi),
      );
      await _guardarCopia((dao) => dao.guardar(alerta));
    }
    final enCache = _cache;
    if (enCache != null) {
      _cache = List.unmodifiable([
        for (final a in enCache) a.id == id ? alerta : a,
      ]);
    }
    return alerta;
  }

  @override
  Future<void> enviarPendientes() async {
    final pendientes = _pendientes;
    if (pendientes == null) return;
    try {
      if ((await pendientes.listar()).isEmpty) return;
      await enviarAlertasPendientes(pendientes: pendientes, servicio: _service);
      // Las que se mandaron ahora tienen id del servidor: se vuelve a pedir.
      _cache = null;
    } catch (_) {
      // Sin señal: quedan para la próxima.
    }
  }
}
