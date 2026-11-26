// Pruebas de la persistencia local: preferencias y almacenamiento seguro en
// memoria, y SQLite en la PC con sqflite_common_ffi (sin emulador).
//
// Para simular "cerrar y volver a abrir la app" se crea un objeto nuevo
// sobre el mismo almacenamiento: si ve lo que guardó el primero, la
// persistencia funciona.

import 'dart:convert';
import 'dart:io';

import 'package:barrio_seguro/data/repositories/alertas_repository.dart';
import 'package:barrio_seguro/data/repositories/sesion_repository.dart';
import 'package:barrio_seguro/data/repositories/turnos_repository.dart';
import 'package:barrio_seguro/data/services/bus_de_eventos.dart';
import 'package:barrio_seguro/data/services/error_del_servidor.dart';
import 'package:barrio_seguro/data/services/descarga_csv_service.dart';
import 'package:barrio_seguro/data/services/local/alertas_dao.dart';
import 'package:barrio_seguro/data/services/local/almacen_seguro.dart';
import 'package:barrio_seguro/data/services/local/base_de_datos.dart';
import 'package:barrio_seguro/data/services/local/preferencias.dart';
import 'package:barrio_seguro/data/services/local/turnos_dao.dart';
import 'package:barrio_seguro/data/services/simulados/servidor_simulado.dart';
import 'package:barrio_seguro/data/services/simulados/turnos_service_simulado.dart';
import 'package:barrio_seguro/data/services/simulados/vecinos_service_simulado.dart';
import 'package:barrio_seguro/data/services/turnos_service.dart';
import 'package:barrio_seguro/domain/models/alerta.dart';
import 'package:barrio_seguro/domain/models/turno.dart';
import 'package:barrio_seguro/domain/models/vecino.dart';
import 'package:barrio_seguro/ui/perfil/view_models/perfil_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../ayudas/app_de_prueba.dart';
import '../ayudas/bases_de_prueba.dart';
import '../ayudas/falsos.dart';

/// Servicio de turnos que falla siempre, como sin conexión.
class TurnosServiceSinConexion implements TurnosService {
  @override
  Future<List<Map<String, dynamic>>> obtenerTurnos({
    required int anio,
    required int mes,
  }) => throw Exception('sin conexión');

  @override
  Future<Map<String, dynamic>> anotarse({
    required String fecha,
    required String franja,
    required String vecinoId,
  }) => throw Exception('sin conexión');

  @override
  Future<Map<String, dynamic>> salir({
    required String fecha,
    required String franja,
    required String vecinoId,
  }) => throw Exception('sin conexión');
}

/// Servicio de turnos cuya API responde siempre con un error.
class TurnosServiceQueRechaza extends TurnosServiceSinConexion {
  @override
  Future<List<Map<String, dynamic>>> obtenerTurnos({
    required int anio,
    required int mes,
  }) => throw const ErrorDelServidor('No se pudo.');
}

/// Las tablas que tiene la base, según sqlite_master.
Future<List<String>> tablasDe(Database db) async {
  final filas = await db.query(
    'sqlite_master',
    columns: ['name'],
    where: 'type = ?',
    whereArgs: ['table'],
  );
  return [for (final f in filas) f['name']! as String];
}

/// La tabla `alertas` como era hasta la v3 del esquema, sin
/// `reportada_por_nombre`: así se arman las bases de versiones anteriores.
const sqlCrearAlertasHastaV3 = '''
CREATE TABLE alertas (
  id TEXT PRIMARY KEY,
  categoria TEXT NOT NULL,
  tipo TEXT NOT NULL,
  descripcion TEXT NOT NULL,
  direccion TEXT NOT NULL,
  creada_en INTEGER NOT NULL,
  estado TEXT NOT NULL,
  latitud REAL NOT NULL,
  longitud REAL NOT NULL,
  reportada_por TEXT NOT NULL
)
''';

/// Una fila de `alertas` como la guardaba la app hasta la v3.
Map<String, Object?> filaHastaV3(Alerta alerta) =>
    alerta.toMap()..remove('reportada_por_nombre');

void main() {
  late Database db;

  setUp(() async => db = await baseEnMemoria());
  tearDown(() => db.close());

  group('Preferencias', () {
    test('sin nada guardado usan los valores por defecto', () async {
      final preferencias = preferenciasEnMemoria();
      expect(await preferencias.compartirUbicacion(), isFalse);
      expect(await preferencias.notificaciones(), isFalse);
      expect(await preferencias.vecino(), isNull);
    });

    test(
      'los ajustes del perfil sobreviven a "cerrar y abrir" la app',
      () async {
        final preferencias = preferenciasEnMemoria();
        PerfilViewModel crear() => PerfilViewModel(
          sesion: SesionFalsa(vecinaDePrueba),
          bus: BusDeEventos(),
          reloj: relojDePrueba,
          capacidades: const CapacidadesFalsas(),
          politicas: const PoliticasFalsas(),
          preferencias: preferencias,
          ubicacion: UbicacionFalsa(),
          notificacionesService: NotificacionesFalsas(),
        );

        final primeraVez = crear();
        await primeraVez.cargar();
        await primeraVez.cambiarCompartirUbicacion(true);
        await primeraVez.cambiarNotificaciones(true);

        final segundaVez = crear();
        await segundaVez.cargar();
        expect(segundaVez.compartirUbicacion, isTrue);
        expect(segundaVez.notificaciones, isTrue);
      },
    );
  });

  group('Sesión', () {
    late Preferencias preferencias;
    late AlmacenSeguro almacen;
    late ServidorSimulado servidor;

    setUp(() {
      servidor = ServidorSimulado(reloj: relojDePrueba, demora: Duration.zero);
      preferencias = preferenciasEnMemoria();
      almacen = almacenSeguroEnMemoria();
    });

    SesionRepositoryRemoto crear(ServidorSimulado servidor) =>
        SesionRepositoryRemoto(
          service: VecinosServiceSimulado(servidor),
          preferencias: preferencias,
          almacen: almacen,
        );

    test('al volver a abrir la app, la sesión sigue abierta', () async {
      await crear(servidor).ingresar(usuario: 'clara', clave: '1234');
      expect(await almacen.token(), isNotNull);

      final alAbrir = crear(servidor);
      await alAbrir.restaurar();
      expect(alAbrir.usuario?.nombre, 'Clara Medina');
    });

    test('al cerrar sesión se borran el token y los datos', () async {
      final sesion = crear(servidor);
      await sesion.ingresar(usuario: 'clara', clave: '1234');
      await sesion.cerrarSesion();
      expect(await almacen.token(), isNull);

      final alAbrir = crear(servidor);
      await alAbrir.restaurar();
      expect(alAbrir.usuario, isNull);
    });

    test('sin token no hay sesión, aunque queden datos viejos', () async {
      await preferencias.guardarVecino(vecinaDePrueba);
      final alAbrir = crear(servidor);
      await alAbrir.restaurar();
      expect(alAbrir.usuario, isNull);
    });

    test('una sesión guardada sin rol se restaura como vecino', () async {
      // Así quedaba guardada la sesión antes de que existiera el rol.
      final sinRol = jsonEncode({
        'id': 'clara',
        'nombre': 'Clara Medina',
        'fecha_nacimiento': '1981-05-14',
        'telefono': '261 555-0142',
        'calle': 'Las Heras',
        'cuadra': '1200',
      });
      final alAbrir = SesionRepositoryRemoto(
        service: VecinosServiceSimulado(servidor),
        preferencias: preferenciasEnMemoria({Preferencias.claveVecino: sinRol}),
        almacen: almacenSeguroEnMemoria({AlmacenSeguro.claveToken: 't'}),
      );

      await alAbrir.restaurar();

      expect(alAbrir.usuario?.nombre, 'Clara Medina');
      expect(alAbrir.usuario?.rol, RolVecino.vecino);
      expect(alAbrir.usuario?.esComision, isFalse);
    });
  });

  group('AlertasDao', () {
    test(
      'guarda y lee todos los campos, de la más nueva a la más vieja',
      () async {
        final dao = AlertasDao(db);
        final vieja = alertaDePrueba(id: 'vieja');
        final nueva = Alerta.fromJson({
          ...alertaDePrueba(
            id: 'nueva',
            estado: EstadoAlerta.enAtencion,
          ).toJson(),
          'creada_en': DateTime(2026, 10, 1, 11, 58).millisecondsSinceEpoch,
        });

        await dao.reemplazarTodas([vieja, nueva]);
        final leidas = await dao.listar();

        expect(leidas.map((a) => a.id), ['nueva', 'vieja']);
        expect(leidas.first.estado, EstadoAlerta.enAtencion);
        expect(leidas.first.ubicacion, nueva.ubicacion);
        expect(leidas.last.creadaEn, vieja.creadaEn);
      },
    );

    test('la copia local guarda y lee reportada_por_nombre', () async {
      final dao = AlertasDao(db);
      await dao.reemplazarTodas([
        alertaDePrueba(id: 'con', reportadaPorNombre: 'Marta'),
        alertaDePrueba(id: 'sin'),
      ]);
      final leidas = {for (final a in await dao.listar()) a.id: a};
      expect(leidas['con']!.reportadaPorNombre, 'Marta');
      expect(leidas['sin']!.reportadaPorNombre, '');
    });

    test('reemplazarTodas borra lo que ya no está en el servidor', () async {
      final dao = AlertasDao(db);
      await dao.reemplazarTodas([
        alertaDePrueba(id: 'a'),
        alertaDePrueba(id: 'b'),
      ]);
      await dao.reemplazarTodas([alertaDePrueba(id: 'c')]);
      expect((await dao.listar()).map((a) => a.id), ['c']);
    });

    test('guardar con el mismo id actualiza la alerta', () async {
      final dao = AlertasDao(db);
      await dao.guardar(alertaDePrueba());
      await dao.guardar(alertaDePrueba(estado: EstadoAlerta.resuelta));
      final leidas = await dao.listar();
      expect(leidas, hasLength(1));
      expect(leidas.single.estado, EstadoAlerta.resuelta);
    });
  });

  group('TurnosDao', () {
    test('lee solo los turnos del mes, con sus vecinos', () async {
      final dao = TurnosDao(db);
      await dao.reemplazarMes(DateTime(2026, 10), [
        Turno(
          fecha: DateTime(2026, 10, 9),
          franja: Franja.noche,
          patrulleros: [vecinaDePrueba],
          guardiaVentana: vecinoMayor,
        ),
      ]);
      await dao.reemplazarMes(DateTime(2026, 11), [
        Turno(fecha: DateTime(2026, 11, 2), franja: Franja.temprano),
      ]);

      final octubre = await dao.delMes(DateTime(2026, 10));
      expect(octubre, hasLength(1));
      expect(octubre.single.franja, Franja.noche);
      expect(octubre.single.incluye(vecinaDePrueba), isTrue);
      expect(octubre.single.guardiaVentana?.nombre, 'Rosa Ibáñez');
    });

    test('la copia local de los turnos no guarda el rol', () async {
      final dao = TurnosDao(db);
      final patrullero = Vecino(
        id: 'clara',
        nombre: 'Clara Medina',
        fechaNacimiento: DateTime(1981, 5, 14),
        rol: RolVecino.comision,
      );
      await dao.reemplazarMes(DateTime(2026, 10), [
        Turno(
          fecha: DateTime(2026, 10, 9),
          franja: Franja.noche,
          patrulleros: [patrullero],
          guardiaVentana: vecinoMayor,
        ),
      ]);

      final fila = (await db.query('turnos')).single;
      final patrulleros = jsonDecode(fila['patrulleros'] as String) as List;
      final guardia =
          jsonDecode(fila['guardia_ventana'] as String) as Map<String, dynamic>;
      expect(patrulleros, hasLength(1));
      for (final vecino in [
        ...patrulleros.cast<Map<String, dynamic>>(),
        guardia,
      ]) {
        expect(vecino.containsKey('rol'), isFalse, reason: '${vecino['id']}');
      }

      final leido = (await dao.delMes(DateTime(2026, 10))).single;
      expect(leido.incluye(patrullero), isTrue);
      expect(leido.guardiaVentana?.id, 'rosa');
    });
  });

  group('Sin conexión', () {
    test('las alertas guardadas se ven al abrir la app sin conexión', () async {
      final servicio = AlertasServiceContador();
      await AlertasRepositoryRemoto(
        service: servicio,
        dao: AlertasDao(db),
      ).obtenerAlertas();

      servicio.falla = true;
      final alAbrir = AlertasRepositoryRemoto(
        service: servicio,
        dao: AlertasDao(db),
      );
      final alertas = await alAbrir.obtenerAlertas();

      expect(alertas.single.id, alertaDePrueba().id);
      expect(alAbrir.sinConexion, isTrue);
    });

    test('al volver la conexión deja de mostrar el aviso', () async {
      final servicio = AlertasServiceContador();
      final repositorio = AlertasRepositoryRemoto(
        service: servicio,
        dao: AlertasDao(db),
      );
      await repositorio.obtenerAlertas();
      servicio.falla = true;
      await repositorio.obtenerAlertas(refrescar: true);
      expect(repositorio.sinConexion, isTrue);

      servicio.falla = false;
      await repositorio.obtenerAlertas();
      expect(repositorio.sinConexion, isFalse);
    });

    test(
      'sin conexión y sin nada guardado, el error llega a la pantalla',
      () async {
        final servicio = AlertasServiceContador()..falla = true;
        final repositorio = AlertasRepositoryRemoto(
          service: servicio,
          dao: AlertasDao(db),
        );
        await expectLater(repositorio.obtenerAlertas(), throwsException);
      },
    );

    test('los turnos guardados se ven sin conexión', () async {
      final servidor = ServidorSimulado(
        reloj: relojDePrueba,
        demora: Duration.zero,
      );
      final octubre = DateTime(2026, 10);
      await TurnosRepositoryRemoto(
        service: TurnosServiceSimulado(servidor),
        dao: TurnosDao(db),
      ).obtenerTurnos(octubre);

      final alAbrir = TurnosRepositoryRemoto(
        service: TurnosServiceSinConexion(),
        dao: TurnosDao(db),
      );
      final turnos = await alAbrir.obtenerTurnos(octubre);

      expect(turnos, isNotEmpty);
      expect(alAbrir.sinConexion, isTrue);
    });
  });

  group('Sin envío diferido', () {
    Future<Alerta> crearSos(AlertasRepository repositorio) =>
        repositorio.crearAlerta(
          categoria: CategoriaAlerta.sos,
          tipo: 'Pedido de ayuda (SOS)',
          descripcion: '',
          direccion: 'Barrio Soberanía',
          ubicacion: const LatLng(-32.876568, -68.870672),
          reportadaPor: 'clara',
        );

    test(
      'crear una alerta sin red lanza el error y no guarda nada en el teléfono',
      () async {
        final conexion = ConexionRepositoryFalsa(hay: false);
        final repositorio = AlertasRepositoryRemoto(
          service: AlertasServiceQueFalla(const SocketException('sin señal')),
          dao: AlertasDao(db),
          conexion: conexion,
        );

        await expectLater(
          crearSos(repositorio),
          throwsA(isA<SocketException>()),
        );

        expect(await db.query('alertas'), isEmpty);
        expect(await tablasDe(db), isNot(contains('alertas_pendientes')));
        // Y la falla de red dispara una comprobación de la conexión.
        expect(conexion.comprobaciones, 1);
      },
    );

    test('si la API rechaza la alerta, el error llega tal cual', () async {
      final repositorio = AlertasRepositoryRemoto(
        service: AlertasServiceQueFalla(const ErrorDelServidor('No.')),
        dao: AlertasDao(db),
      );

      await expectLater(
        crearSos(repositorio),
        throwsA(isA<ErrorDelServidor>()),
      );
      expect(await db.query('alertas'), isEmpty);
    });

    test('si falla la red al pedir alertas se comprueba la conexión', () async {
      final conexion = ConexionRepositoryFalsa(hay: false);
      final repositorio = AlertasRepositoryRemoto(
        service: AlertasServiceContador()..falla = true,
        dao: AlertasDao(db),
        conexion: conexion,
      );

      await expectLater(repositorio.obtenerAlertas(), throwsException);

      expect(conexion.comprobaciones, 1);
    });

    test('si falla la red al pedir turnos se comprueba la conexión', () async {
      final conexion = ConexionRepositoryFalsa(hay: false);
      final repositorio = TurnosRepositoryRemoto(
        service: TurnosServiceSinConexion(),
        dao: TurnosDao(db),
        conexion: conexion,
      );

      await expectLater(
        repositorio.obtenerTurnos(DateTime(2026, 10)),
        throwsException,
      );

      expect(conexion.comprobaciones, 1);
    });

    test('un ErrorDelServidor no dispara la comprobación', () async {
      final conexion = ConexionRepositoryFalsa();
      final alertas = AlertasRepositoryRemoto(
        service: AlertasServiceQueFalla(const ErrorDelServidor('No.')),
        conexion: conexion,
      );
      final turnos = TurnosRepositoryRemoto(
        service: TurnosServiceQueRechaza(),
        conexion: conexion,
      );

      await expectLater(
        alertas.obtenerAlertas(),
        throwsA(isA<ErrorDelServidor>()),
      );
      await expectLater(crearSos(alertas), throwsA(isA<ErrorDelServidor>()));
      await expectLater(
        turnos.obtenerTurnos(DateTime(2026, 10)),
        throwsA(isA<ErrorDelServidor>()),
      );

      expect(conexion.comprobaciones, 0);
    });
  });

  group('Esquema de la base', () {
    late Directory carpeta;
    late String ruta;

    setUp(() {
      sqfliteFfiInit();
      carpeta = Directory.systemTemp.createTempSync('barrio_seguro');
      ruta = '${carpeta.path}/barrio_seguro.db';
    });
    tearDown(() => carpeta.deleteSync(recursive: true));

    test('una base nueva no tiene tabla de alertas pendientes', () async {
      final nueva = await abrirBaseDeDatos(databaseFactoryFfi, ruta);
      addTearDown(nueva.close);

      expect(await nueva.getVersion(), 4);
      final tablas = await tablasDe(nueva);
      expect(tablas, containsAll(['alertas', 'turnos']));
      expect(tablas, isNot(contains('alertas_pendientes')));
    });

    test('la migración de la v2 a la v3 borra alertas_pendientes y conserva alertas y turnos', () async {
      // Una base de la versión 2 de la app, con una alerta, un turno y
      // una alerta pendiente de envío.
      final vieja = await databaseFactoryFfi.openDatabase(
        ruta,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, _) async {
            await db.execute(sqlCrearAlertasHastaV3);
            await db.execute(sqlCrearTurnos);
            await db.execute(
              'CREATE TABLE alertas_pendientes ('
              'id INTEGER PRIMARY KEY AUTOINCREMENT, datos TEXT NOT NULL)',
            );
          },
        ),
      );
      await vieja.insert('alertas', filaHastaV3(alertaDePrueba()));
      await TurnosDao(vieja).guardar(
        Turno(
          fecha: DateTime(2026, 10, 9),
          franja: Franja.noche,
          patrulleros: [vecinaDePrueba],
        ),
      );
      await vieja.insert('alertas_pendientes', {
        'datos': jsonEncode({'categoria': 'sos'}),
      });
      await vieja.close();

      final nueva = await abrirBaseDeDatos(databaseFactoryFfi, ruta);
      addTearDown(nueva.close);

      expect(await nueva.getVersion(), versionDelEsquema);
      expect(await tablasDe(nueva), isNot(contains('alertas_pendientes')));
      expect(await AlertasDao(nueva).listar(), hasLength(1));
      expect(await TurnosDao(nueva).delMes(DateTime(2026, 10)), hasLength(1));
    });

    test('la migración de la v1 a la v3 conserva las alertas', () async {
      final vieja = await databaseFactoryFfi.openDatabase(
        ruta,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            await db.execute(sqlCrearAlertasHastaV3);
            await db.execute(sqlCrearTurnos);
          },
        ),
      );
      await vieja.insert('alertas', filaHastaV3(alertaDePrueba()));
      await vieja.close();

      final nueva = await abrirBaseDeDatos(databaseFactoryFfi, ruta);
      addTearDown(nueva.close);

      expect(await nueva.getVersion(), versionDelEsquema);
      expect(await AlertasDao(nueva).listar(), hasLength(1));
      expect(await tablasDe(nueva), isNot(contains('alertas_pendientes')));
    });

    test(
      'migración v3 → v4 agrega reportada_por_nombre sin perder alertas',
      () async {
        final vieja = await databaseFactoryFfi.openDatabase(
          ruta,
          options: OpenDatabaseOptions(
            version: 3,
            onCreate: (db, _) async {
              await db.execute(sqlCrearAlertasHastaV3);
              await db.execute(sqlCrearTurnos);
            },
          ),
        );
        await vieja.insert('alertas', filaHastaV3(alertaDePrueba(id: 'a')));
        await vieja.insert('alertas', filaHastaV3(alertaDePrueba(id: 'b')));
        await vieja.close();

        final nueva = await abrirBaseDeDatos(databaseFactoryFfi, ruta);
        addTearDown(nueva.close);

        expect(await nueva.getVersion(), 4);
        final columnas = await nueva.rawQuery('PRAGMA table_info(alertas)');
        expect(
          columnas.map((c) => c['name']),
          contains('reportada_por_nombre'),
        );
        final dao = AlertasDao(nueva);
        final leidas = await dao.listar();
        expect(leidas.map((a) => a.id).toSet(), {'a', 'b'});
        expect(leidas.every((a) => a.reportadaPorNombre == ''), isTrue);

        // Y después de migrar se guarda el nombre.
        await dao.guardar(alertaDePrueba(id: 'a', reportadaPorNombre: 'Marta'));
        final a = (await dao.listar()).firstWhere((x) => x.id == 'a');
        expect(a.reportadaPorNombre, 'Marta');
      },
    );
  });

  group('Descarga de CSV', () {
    test('DescargaCsvServiceLocal guarda el archivo CSV en disco', () async {
      final carpeta = Directory.systemTemp.createTempSync('barrio_seguro_csv');
      addTearDown(() => carpeta.deleteSync(recursive: true));
      final servicio = DescargaCsvServiceLocal(carpetaDestino: carpeta);

      final ruta = await servicio.guardarCsv(
        nombreArchivo: 'informe_alertas_2026_10.csv',
        contenido: 'Sección,Detalle,Cantidad\nResumen,Total del mes,3\n',
      );

      expect(ruta, isNotNull);
      final archivo = File(ruta!);
      expect(archivo.existsSync(), isTrue);
      expect(archivo.readAsStringSync(), contains('Resumen,Total del mes,3'));
    });
  });
}
