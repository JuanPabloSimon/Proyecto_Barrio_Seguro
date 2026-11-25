// Pruebas de los avisos de alertas nuevas y del envío de alertas
// pendientes (las que se crearon sin señal).

import 'dart:io';

import 'package:barrio_seguro/data/repositories/alertas_repository.dart';
import 'package:barrio_seguro/data/services/alertas_service.dart';
import 'package:barrio_seguro/data/services/bus_de_eventos.dart';
import 'package:barrio_seguro/data/services/error_del_servidor.dart';
import 'package:barrio_seguro/data/services/local/alertas_dao.dart';
import 'package:barrio_seguro/data/services/local/base_de_datos.dart';
import 'package:barrio_seguro/data/services/local/pendientes_dao.dart';
import 'package:barrio_seguro/data/services/local/preferencias.dart';
import 'package:barrio_seguro/data/services/push_service.dart';
import 'package:barrio_seguro/data/services/tareas/envio_de_pendientes.dart';
import 'package:barrio_seguro/data/services/tareas/tarea_de_fondo.dart';
import 'package:barrio_seguro/domain/evento_de_app.dart';
import 'package:barrio_seguro/domain/models/alerta.dart';
import 'package:barrio_seguro/ui/perfil/view_models/perfil_view_model.dart';
import 'package:barrio_seguro/ui/principal/vigilante_de_alertas.dart';
import 'package:barrio_seguro/ui/sos/view_models/sos_view_model.dart';
import 'package:flutter/widgets.dart';
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

    testWidgets(
      'reacciona a eventos del sistema: pausa el reloj en segundo plano y revisa al volver (onResume)',
      (tester) async {
        final vigilante = crear()..empezar();
        addTearDown(vigilante.detener);
        await tester.pump();
        expect(vigilante.enPrimerPlano, isTrue);

        // El sistema operativo pasa la app a segundo plano.
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        expect(vigilante.enPrimerPlano, isFalse);

        // Otro vecino reporta una alerta mientras la app estaba en pausa.
        alertas.alertas.insert(
          0,
          alertaDePrueba(id: 'al-volver', reportadaPor: 'jorge'),
        );

        // El sistema operativo devuelve la app a primer plano (onResume).
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();

        expect(vigilante.enPrimerPlano, isTrue);
        expect(notificaciones.avisadas.map((a) => a.id), ['al-volver']);
        expect(alertas.enviosDePendientes, greaterThanOrEqualTo(2));

        vigilante.detener();
      },
    );
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

    test('ejecutarTareaDeFondo procesa pendientes aun sin API_URL y actualiza AlertasDao', () async {
      final pendientes = PendientesDao(db);
      final alertasDao = AlertasDao(db);
      await pendientes.agregar({
        'categoria': 'sos',
        'tipo': 'Pedido de ayuda (SOS)',
        'descripcion': 'Desde segundo plano',
        'direccion': 'Calle Plantamura',
        'latitud': -32.876568,
        'longitud': -68.870672,
        'reportada_por': 'clara',
        'creada_en': DateTime(2026, 10, 1, 12).millisecondsSinceEpoch,
      });

      final ok = await ejecutarTareaDeFondo(
        tareaEnviarPendientes,
        db: db,
        urlBaseApi: '',
      );

      expect(ok, isTrue);
      expect(await pendientes.listar(), isEmpty);
      final guardadas = await alertasDao.listar();
      expect(guardadas, hasLength(1));
      expect(guardadas.single.descripcion, 'Desde segundo plano');
    });

    test('si la tarea de fondo ya envió las pendientes, el repositorio limpia la caché', () async {
      final pendientes = PendientesDao(db);
      final alertasDao = AlertasDao(db);
      final api = AlertasServiceDePrueba()..sinSenal = true;
      final repositorio = AlertasRepositoryRemoto(
        service: api,
        dao: alertasDao,
        pendientes: pendientes,
        reloj: relojDePrueba,
      );

      final pendiente = await repositorio.crearAlerta(
        categoria: CategoriaAlerta.sos,
        tipo: 'Pedido de ayuda (SOS)',
        descripcion: '',
        direccion: 'Barrio Soberanía',
        ubicacion: const LatLng(-32.876568, -68.870672),
        reportadaPor: 'clara',
      );
      expect(repositorio.estaPendiente(pendiente.id), isTrue);

      // Ahora el worker de segundo plano la envía mientras la app está en
      // segundo plano.
      api.sinSenal = false;
      final ok = await ejecutarTareaDeFondo(
        tareaEnviarPendientes,
        db: db,
        servicio: api,
      );
      expect(ok, isTrue);
      expect(await pendientes.listar(), isEmpty);

      // Cuando la app vuelve a primer plano, enviarPendientes detecta que
      // la cola ya se vació en segundo plano e invalida la caché.
      await repositorio.enviarPendientes();
      final actuales = await repositorio.obtenerAlertas();
      expect(actuales.where((a) => repositorio.estaPendiente(a.id)), isEmpty);
      expect(actuales.map((a) => a.id), ['srv-0']);
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

  group('Avisos push con la app cerrada', () {
    late NotificacionesFalsas notificaciones;
    late Preferencias preferencias;

    Map<String, dynamic> datosPush({
      String id = 'a-push-1',
      String estado = 'activa',
      String reportadaPor = 'jorge',
    }) => {
      'id': id,
      'categoria': 'sos',
      'tipo': 'Pedido de ayuda (SOS)',
      'descripcion': 'Urgencia en la vereda',
      'direccion': 'Calle Plantamura',
      'creada_en': '${DateTime(2026, 10, 1, 12).millisecondsSinceEpoch}',
      'estado': estado,
      'latitud': '-32.877264',
      'longitud': '-68.868785',
      'reportada_por': reportadaPor,
    };

    setUp(() async {
      notificaciones = NotificacionesFalsas();
      preferencias = preferenciasEnMemoria();
      await preferencias.guardarNotificaciones(true);
      await preferencias.guardarVecino(vecinaDePrueba);
    });

    test('con la app cerrada, cuando otro vecino crea una alerta, muestra una notificación', () async {
      final mostrada = await procesarAvisoPush(
        datosPush(id: 'ajena', reportadaPor: 'jorge'),
        preferencias: preferencias,
        notificaciones: notificaciones,
      );

      expect(mostrada, isTrue);
      expect(notificaciones.avisadas.map((a) => a.id), ['ajena']);
      expect(notificaciones.avisadas.single.direccion, 'Calle Plantamura');
    });

    test('el vecino que creó la alerta no recibe su propio aviso', () async {
      final mostrada = await procesarAvisoPush(
        datosPush(id: 'propia', reportadaPor: 'clara'),
        preferencias: preferencias,
        notificaciones: notificaciones,
      );

      expect(mostrada, isFalse);
      expect(notificaciones.avisadas, isEmpty);
    });

    test('si la alerta ya está resuelta cuando se va a mostrar el aviso, no se avisa', () async {
      final mostrada = await procesarAvisoPush(
        datosPush(id: 'resuelta', estado: 'resuelta', reportadaPor: 'jorge'),
        preferencias: preferencias,
        notificaciones: notificaciones,
      );

      expect(mostrada, isFalse);
      expect(notificaciones.avisadas, isEmpty);
    });

    test(
      'sin avisos activos o con datos inválidos no muestra notificación',
      () async {
        await preferencias.guardarNotificaciones(false);
        expect(
          await procesarAvisoPush(
            datosPush(),
            preferencias: preferencias,
            notificaciones: notificaciones,
          ),
          isFalse,
        );

        await preferencias.guardarNotificaciones(true);
        expect(
          await procesarAvisoPush(
            {'id': 'incompleta'},
            preferencias: preferencias,
            notificaciones: notificaciones,
          ),
          isFalse,
        );
        expect(notificaciones.avisadas, isEmpty);
      },
    );

    test(
      'activar avisos suscribe al push y apagarlos o cerrar sesión desuscribe',
      () async {
        final push = PushFalso();
        final vm = PerfilViewModel(
          sesion: SesionFalsa(vecinaDePrueba),
          bus: BusDeEventos(),
          reloj: relojDePrueba,
          capacidades: const CapacidadesFalsas(),
          politicas: const PoliticasFalsas(),
          preferencias: preferenciasEnMemoria(),
          ubicacion: UbicacionFalsa(),
          notificacionesService: NotificacionesFalsas(),
          pushService: push,
        );
        await vm.cargar();

        expect(await vm.activarAvisos(), isNull);
        expect(push.suscripto, isTrue);
        expect(push.suscripciones, 1);

        await vm.cambiarNotificaciones(false);
        expect(push.suscripto, isFalse);
        expect(push.desuscripciones, 1);

        await vm.activarAvisos();
        expect(push.suscripto, isTrue);

        await vm.cerrarSesion();
        expect(push.suscripto, isFalse);
        expect(push.desuscripciones, 2);
      },
    );

    test('sin el permiso de notificaciones o si el push falla la app sigue funcionando igual', () async {
      final push = PushFalso(falla: true);
      final vmSinPermiso = PerfilViewModel(
        sesion: SesionFalsa(vecinaDePrueba),
        bus: BusDeEventos(),
        reloj: relojDePrueba,
        capacidades: const CapacidadesFalsas(),
        politicas: const PoliticasFalsas(),
        preferencias: preferenciasEnMemoria(),
        ubicacion: UbicacionFalsa(),
        notificacionesService: NotificacionesFalsas(permiso: false),
        pushService: push,
      );
      await vmSinPermiso.cargar();

      final aviso = await vmSinPermiso.activarAvisos();
      expect(aviso, contains('Sin permiso'));
      expect(vmSinPermiso.notificaciones, isFalse);
      expect(push.suscripciones, 0);

      // Con permiso pero con fallo de red en el servicio de push, no
      // bloquea el cambio de preferencia ni el cierre de sesión.
      final vmConFalloPush = PerfilViewModel(
        sesion: SesionFalsa(vecinaDePrueba),
        bus: BusDeEventos(),
        reloj: relojDePrueba,
        capacidades: const CapacidadesFalsas(),
        politicas: const PoliticasFalsas(),
        preferencias: preferenciasEnMemoria(),
        ubicacion: UbicacionFalsa(),
        notificacionesService: NotificacionesFalsas(permiso: true),
        pushService: push,
      );
      await vmConFalloPush.cargar();

      expect(await vmConFalloPush.activarAvisos(), isNull);
      expect(vmConFalloPush.notificaciones, isTrue);
      await vmConFalloPush.cerrarSesion();
    });
  });
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
