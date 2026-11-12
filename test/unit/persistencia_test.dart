// Pruebas de la persistencia local: preferencias y almacenamiento seguro en
// memoria, y SQLite en la PC con sqflite_common_ffi (sin emulador).
//
// Para simular "cerrar y volver a abrir la app" se crea un objeto nuevo
// sobre el mismo almacenamiento: si ve lo que guardó el primero, la
// persistencia funciona.

import 'package:BarrioSeguro/data/repositories/alertas_repository.dart';
import 'package:BarrioSeguro/data/repositories/sesion_repository.dart';
import 'package:BarrioSeguro/data/repositories/turnos_repository.dart';
import 'package:BarrioSeguro/data/services/bus_de_eventos.dart';
import 'package:BarrioSeguro/data/services/local/alertas_dao.dart';
import 'package:BarrioSeguro/data/services/local/almacen_seguro.dart';
import 'package:BarrioSeguro/data/services/local/preferencias.dart';
import 'package:BarrioSeguro/data/services/local/turnos_dao.dart';
import 'package:BarrioSeguro/data/services/simulados/servidor_simulado.dart';
import 'package:BarrioSeguro/data/services/simulados/turnos_service_simulado.dart';
import 'package:BarrioSeguro/data/services/simulados/vecinos_service_simulado.dart';
import 'package:BarrioSeguro/data/services/turnos_service.dart';
import 'package:BarrioSeguro/domain/models/alerta.dart';
import 'package:BarrioSeguro/domain/models/turno.dart';
import 'package:BarrioSeguro/ui/perfil/view_models/perfil_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
