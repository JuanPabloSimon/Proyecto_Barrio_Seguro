// Pruebas de los avisos de alertas nuevas y del envío de alertas
// pendientes (las que se crearon sin señal).

import 'dart:io';

import 'package:BarrioSeguro/data/repositories/alertas_repository.dart';
import 'package:BarrioSeguro/data/services/alertas_service.dart';
import 'package:BarrioSeguro/data/services/bus_de_eventos.dart';
import 'package:BarrioSeguro/data/services/error_del_servidor.dart';
import 'package:BarrioSeguro/data/services/local/base_de_datos.dart';
import 'package:BarrioSeguro/data/services/local/pendientes_dao.dart';
import 'package:BarrioSeguro/data/services/local/preferencias.dart';
import 'package:BarrioSeguro/data/services/tareas/envio_de_pendientes.dart';
import 'package:BarrioSeguro/domain/evento_de_app.dart';
import 'package:BarrioSeguro/domain/models/alerta.dart';
import 'package:BarrioSeguro/ui/principal/vigilante_de_alertas.dart';
import 'package:BarrioSeguro/ui/sos/view_models/sos_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../ayudas/app_de_prueba.dart';
import '../ayudas/bases_de_prueba.dart';
import '../ayudas/falsos.dart';

/// La "API" de alertas: guarda lo que recibe. Con [sinSenal] falla como
/// sin conexión; con [rechaza], la API responde con un error.
class AlertasServiceDePrueba implements AlertasService {
  final List<Map<String, dynamic>> recibidas = [];
  bool sinSenal = false;
  bool rechaza = false;

  void _revisar() {
    if (sinSenal) throw const SocketException('sin señal');
    if (rechaza) throw const ErrorDelServidor('Elegí qué tipo de alerta es.');
  }

  @override
  Future<List<Map<String, dynamic>>> obtenerAlertas() async {
    _revisar();
    return [
      for (var i = 0; i < recibidas.length; i++)
        {
          ...recibidas[i],
          'id': 'srv-$i',
          'estado': 'activa',
          'creada_en': recibidas[i]['creada_en'] ?? 0,
        },
    ];
  }

  @override
  Future<Map<String, dynamic>> crearAlerta(Map<String, dynamic> datos) async {
    _revisar();
    recibidas.add(datos);
    return {
      ...datos,
      'id': 'srv-${recibidas.length - 1}',
      'estado': 'activa',
      'creada_en': 0,
    };
  }

  @override
  Future<Map<String, dynamic>> cambiarEstado(String id, String estado) =>
      throw UnimplementedError();
}

void main() {
  group('Vigilante de alertas', () {
    late AlertasFalsas alertas;
    late NotificacionesFalsas notificaciones;
    late Preferencias preferencias;
    late BusDeEventos bus;

    setUp(() async {
      alertas = AlertasFalsas([
        alertaDePrueba(id: 'vieja', reportadaPor: 'jorge'),
      ]);
      notificaciones = NotificacionesFalsas();
      preferencias = preferenciasEnMemoria();
      await preferencias.guardarNotificaciones(true);
      bus = BusDeEventos();
    });

    VigilanteDeAlertas crear() => VigilanteDeAlertas(
      alertas: alertas,
      sesion: SesionFalsa(vecinaDePrueba),
      notificaciones: notificaciones,
      preferencias: preferencias,
      bus: bus,
    );

    test('lo que ya estaba al abrir la app no se avisa', () async {
      await crear().revisar();
      expect(notificaciones.avisadas, isEmpty);
    });

    test('avisa las alertas nuevas de otros vecinos', () async {
      final vigilante = crear();
      await vigilante.revisar();
      alertas.alertas.insert(
        0,
        alertaDePrueba(id: 'nueva', reportadaPor: 'jorge'),
      );

      await vigilante.revisar();

      expect(notificaciones.avisadas.map((a) => a.id), ['nueva']);
    });

    test('no avisa las propias ni las ya resueltas', () async {
      final vigilante = crear();
      await vigilante.revisar();
      alertas.alertas.insertAll(0, [
        alertaDePrueba(id: 'mia', reportadaPor: 'clara'),
        alertaDePrueba(
          id: 'cerrada',
          reportadaPor: 'jorge',
          estado: EstadoAlerta.resuelta,
        ),
      ]);

      await vigilante.revisar();

      expect(notificaciones.avisadas, isEmpty);
    });

    test(
      'con los avisos apagados no notifica, pero actualiza las pantallas',
      () async {
        await preferencias.guardarNotificaciones(false);
        final eventos = <Object>[];
        bus.eventos.listen(eventos.add);
        final vigilante = crear();
        await vigilante.revisar();
        alertas.alertas.insert(
          0,
          alertaDePrueba(id: 'nueva', reportadaPor: 'jorge'),
        );

        await vigilante.revisar();
        await Future<void>.delayed(Duration.zero);

        expect(notificaciones.avisadas, isEmpty);
        expect(eventos, contains(isA<AlertasActualizadas>()));
      },
    );

    test('cada revisión intenta mandar las alertas pendientes', () async {
      await crear().revisar();
      expect(alertas.enviosDePendientes, 1);
    });
  });

  group('Alertas sin señal', () {
    late Database db;
    late AlertasServiceDePrueba api;
    late TareasFalsas tareas;
    late AlertasRepositoryRemoto repositorio;

    setUp(() async {
      db = await baseEnMemoria();
      api = AlertasServiceDePrueba();
      tareas = TareasFalsas();
      repositorio = AlertasRepositoryRemoto(
        service: api,
        pendientes: PendientesDao(db),
        tareas: tareas,
        reloj: relojDePrueba,
      );
    });
    tearDown(() => db.close());

    Future<Alerta> crearSos() => repositorio.crearAlerta(
      categoria: CategoriaAlerta.sos,
      tipo: 'Pedido de ayuda (SOS)',
      descripcion: '',
      direccion: 'Barrio Soberanía',
      ubicacion: const LatLng(-32.876568, -68.870672),
      reportadaPor: 'clara',
    );

    test('queda guardada, se ve en la lista y se programa el envío', () async {
      api.sinSenal = true;
      final alerta = await crearSos();

      expect(repositorio.estaPendiente(alerta.id), isTrue);
      expect(tareas.programadas, 1);
      final lista = await repositorio.obtenerAlertas();
      expect(lista.map((a) => a.id), contains(alerta.id));
    });

    test('al volver la señal se manda una sola vez', () async {
      api.sinSenal = true;
      await crearSos();

      api.sinSenal = false;
      await repositorio.enviarPendientes();
      await repositorio.enviarPendientes();

      expect(api.recibidas, hasLength(1));
      expect(await PendientesDao(db).listar(), isEmpty);
      final lista = await repositorio.obtenerAlertas();
      expect(lista.where((a) => repositorio.estaPendiente(a.id)), isEmpty);
    });

    test(
      'si la API la rechaza no se guarda: el error llega al vecino',
      () async {
        api.rechaza = true;
        await expectLater(crearSos(), throwsA(isA<ErrorDelServidor>()));
        expect(await PendientesDao(db).listar(), isEmpty);
      },
    );

    test('cerrar una alerta pendiente la saca de la cola', () async {
      api.sinSenal = true;
      final alerta = await crearSos();

      final cerrada = await repositorio.cambiarEstado(
        alerta.id,
        EstadoAlerta.resuelta,
      );

      expect(cerrada.estado, EstadoAlerta.resuelta);
      expect(await PendientesDao(db).listar(), isEmpty);
    });

    test('el SOS sin señal avisa que se va a enviar solo', () async {
      api.sinSenal = true;
      final vm = SosViewModel(
        alertas: repositorio,
        sesion: SesionFalsa(vecinaDePrueba),
        bus: BusDeEventos(),
        preferencias: preferenciasEnMemoria(),
        ubicacion: UbicacionFalsa(),
        capacidades: const CapacidadesFalsas(),
      );

      await vm.enviar();

      expect(vm.paso, PasoSos.enviada);
      expect(vm.pendiente, isTrue);
    });
  });

  group('Tarea de envío', () {
    late Database db;
    setUp(() async => db = await baseEnMemoria());
    tearDown(() => db.close());

    test('sin red devuelve false para que el sistema reintente', () async {
      final pendientes = PendientesDao(db);
      await pendientes.agregar({'categoria': 'sos'});
      final api = AlertasServiceDePrueba()..sinSenal = true;

      final ok = await enviarAlertasPendientes(
        pendientes: pendientes,
        servicio: api,
      );

      expect(ok, isFalse);
      expect(await pendientes.listar(), hasLength(1));
    });

    test('una alerta rechazada se descarta y no frena a las demás', () async {
      final pendientes = PendientesDao(db);
      await pendientes.agregar({'categoria': 'ovni'});
      await pendientes.agregar({'categoria': 'sos'});
      var pedidos = 0;
      final api = _ServicioQueRechazaLaPrimera(() => pedidos++);

      final ok = await enviarAlertasPendientes(
        pendientes: pendientes,
        servicio: api,
      );

      expect(ok, isTrue);
      expect(pedidos, 2);
      expect(await pendientes.listar(), isEmpty);
    });
  });

  test(
    'la migración agrega la tabla de pendientes sin borrar alertas',
    () async {
      sqfliteFfiInit();
      final carpeta = Directory.systemTemp.createTempSync('barrio_seguro');
      addTearDown(() => carpeta.deleteSync(recursive: true));
      final ruta = '${carpeta.path}/barrio_seguro.db';

      // Una base de la versión 1 de la app, con una alerta guardada.
      final vieja = await databaseFactoryFfi.openDatabase(
        ruta,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            await db.execute(sqlCrearAlertas);
            await db.execute(sqlCrearTurnos);
          },
        ),
      );
      await vieja.insert('alertas', alertaDePrueba().toMap());
      await vieja.close();

      final nueva = await abrirBaseDeDatos(databaseFactoryFfi, ruta);
      addTearDown(nueva.close);

      expect(await nueva.getVersion(), versionDelEsquema);
      expect(await nueva.query('alertas'), hasLength(1));
      expect(await PendientesDao(nueva).listar(), isEmpty);
    },
  );
}

class _ServicioQueRechazaLaPrimera extends AlertasServiceDePrueba {
  _ServicioQueRechazaLaPrimera(this._alPedir);

  final void Function() _alPedir;
  var _primera = true;

  @override
  Future<Map<String, dynamic>> crearAlerta(Map<String, dynamic> datos) async {
    _alPedir();
    if (_primera) {
      _primera = false;
      throw const ErrorDelServidor('Elegí qué tipo de alerta es.');
    }
    return super.crearAlerta(datos);
  }
}
