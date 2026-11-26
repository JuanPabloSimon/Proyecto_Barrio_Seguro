// Pruebas de la capa de datos: los repositorios convierten el JSON del
// servicio en modelos, mantienen un Future con estado y guardan una caché.

import 'dart:async';
import 'dart:convert';

import 'package:barrio_seguro/data/repositories/alertas_repository.dart';
import 'package:barrio_seguro/data/repositories/avisos_recibidos_repository.dart';
import 'package:barrio_seguro/data/repositories/futuro_con_estado.dart';
import 'package:barrio_seguro/data/repositories/turnos_repository.dart';
import 'package:barrio_seguro/data/services/alertas_service.dart';
import 'package:barrio_seguro/data/services/error_del_servidor.dart';
import 'package:barrio_seguro/data/services/local/preferencias.dart';
import 'package:barrio_seguro/data/services/reloj.dart';
import 'package:barrio_seguro/data/services/simulados/servidor_simulado.dart';
import 'package:barrio_seguro/data/services/simulados/turnos_service_simulado.dart';
import 'package:barrio_seguro/domain/models/alerta.dart';
import 'package:barrio_seguro/domain/models/turno.dart';
import 'package:barrio_seguro/domain/models/vecino.dart';
import 'package:flutter_test/flutter_test.dart';

import '../ayudas/bases_de_prueba.dart';
import '../ayudas/falsos.dart';

/// Servicio controlado por un [Completer] para observar el estado `cargando`
/// mientras el [Future] sigue en vuelo.
class _AlertasServiceControlado implements AlertasService {
  int pedidos = 0;
  Completer<List<Map<String, dynamic>>> proximo =
      Completer<List<Map<String, dynamic>>>();

  @override
  Future<List<Map<String, dynamic>>> obtenerAlertas() {
    pedidos++;
    return proximo.future;
  }

  @override
  Future<Map<String, dynamic>> crearAlerta(Map<String, dynamic> datos) async =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> cambiarEstado(String id, String estado) async =>
      throw UnimplementedError();
}

void main() {
  test(
    'el repositorio de alertas pide una sola vez y después usa la caché',
    () async {
      final servicio = AlertasServiceContador();
      final repositorio = AlertasRepositoryRemoto(service: servicio);

      expect(repositorio.estado, EstadoFuturo.inicial);
      await repositorio.obtenerAlertas();
      expect(repositorio.estado, EstadoFuturo.exito);
      await repositorio.obtenerAlertas();
      expect(servicio.pedidos, 1);

      await repositorio.obtenerAlertas(refrescar: true);
      expect(servicio.pedidos, 2);
    },
  );

  group('Future con estado en repositorios', () {
    test(
      'transiciona inicial -> cargando -> exito y comparte el Future en vuelo',
      () async {
        final servicio = _AlertasServiceControlado();
        final repositorio = AlertasRepositoryRemoto(service: servicio);

        expect(repositorio.estado, EstadoFuturo.inicial);
        expect(repositorio.pedido.enCurso, isNull);

        // Dos pantallas piden las alertas al mismo tiempo mientras sigue
        // cargando.
        final primero = repositorio.obtenerAlertas();
        final segundo = repositorio.obtenerAlertas();

        expect(repositorio.estado, EstadoFuturo.cargando);
        expect(repositorio.pedido.cargando, isTrue);
        expect(repositorio.pedido.enCurso, isNotNull);
        expect(identical(primero, segundo), isTrue);
        expect(servicio.pedidos, 1);

        servicio.proximo.complete([alertaDePrueba().toJson()]);
        final resultados = await Future.wait([primero, segundo]);

        expect(repositorio.estado, EstadoFuturo.exito);
        expect(repositorio.pedido.enCurso, isNull);
        expect(resultados[0].single.id, 'a1');
        expect(resultados[1].single.id, 'a1');
      },
    );

    test('si el pedido falla sin copia local, pasa a estado error y permite reintentar', () async {
      final servicio = AlertasServiceContador()..falla = true;
      final repositorio = AlertasRepositoryRemoto(service: servicio);

      await expectLater(repositorio.obtenerAlertas(), throwsException);
      expect(repositorio.estado, EstadoFuturo.error);
      expect(repositorio.pedido.error, isNotNull);

      servicio.falla = false;
      final alertas = await repositorio.obtenerAlertas();
      expect(repositorio.estado, EstadoFuturo.exito);
      expect(repositorio.pedido.error, isNull);
      expect(alertas, hasLength(1));
    });

    test(
      'TurnosRepositoryRemoto mantiene un Future con estado por cada mes',
      () async {
        final octubre = DateTime(2026, 10);
        final servidor = ServidorSimulado(
          reloj: RelojFijo(DateTime(2026, 10, 1, 12)),
          demora: const Duration(milliseconds: 20),
        );
        final repositorio = TurnosRepositoryRemoto(
          service: TurnosServiceSimulado(servidor),
        );

        expect(repositorio.estadoDelMes(octubre), EstadoFuturo.inicial);

        final p1 = repositorio.obtenerTurnos(octubre);
        final p2 = repositorio.obtenerTurnos(octubre);
        expect(repositorio.estadoDelMes(octubre), EstadoFuturo.cargando);
        expect(identical(p1, p2), isTrue);

        await Future.wait([p1, p2]);
        expect(repositorio.estadoDelMes(octubre), EstadoFuturo.exito);
      },
    );
  });

  group('Turnos contra el servidor simulado', () {
    late TurnosRepositoryRemoto repositorio;
    final octubre = DateTime(2026, 10);

    setUp(() {
      final servidor = ServidorSimulado(
        reloj: RelojFijo(DateTime(2026, 10, 1, 12)),
        demora: Duration.zero,
      );
      repositorio = TurnosRepositoryRemoto(
        service: TurnosServiceSimulado(servidor),
      );
    });

    test('convierte el JSON en turnos con sus vecinos', () async {
      final turnos = await repositorio.obtenerTurnos(octubre);
      final delNueve = turnos.firstWhere((t) => t.fecha.day == 9);
      expect(
        delNueve.patrulleros.map((v) => v.nombre),
        contains('Clara Medina'),
      );
      expect(delNueve.guardiaVentana?.nombre, 'Ernesto Funes');
    });

    test('el servidor rechaza un tercer turno en el mes', () async {
      final clara = Vecino(
        id: 'clara',
        nombre: 'Clara Medina',
        fechaNacimiento: DateTime(1981),
      );
      // Clara ya tiene el del 9: este es el segundo.
      await repositorio.anotarse(clara, DateTime(2026, 10, 30), Franja.noche);

      await expectLater(
        () => repositorio.anotarse(clara, DateTime(2026, 10, 31), Franja.noche),
        throwsA(isA<ErrorDelServidor>()),
      );
    });

    test('anotarse actualiza la caché del mes', () async {
      final clara = Vecino(
        id: 'clara',
        nombre: 'Clara Medina',
        fechaNacimiento: DateTime(1981),
      );
      await repositorio.obtenerTurnos(octubre);
      await repositorio.anotarse(clara, DateTime(2026, 10, 30), Franja.noche);

      final turnos = await repositorio.obtenerTurnos(octubre);
      final del30 = turnos.firstWhere((t) => t.fecha.day == 30);
      expect(del30.incluye(clara), isTrue);
    });
  });

  group('Rol contra el servidor simulado', () {
    late ServidorSimulado servidor;

    setUp(() {
      servidor = ServidorSimulado(
        reloj: RelojFijo(DateTime(2026, 10, 1, 12)),
        demora: Duration.zero,
      );
    });

    test('la vecina de ejemplo es de la comisión y el resto no', () {
      final clara = servidor.ingresar('261 555-0142', 'x')['vecino'];
      expect(clara['id'], 'clara');
      expect(clara['rol'], 'comision');
      expect(Vecino.fromJson(clara as Map<String, dynamic>).esComision, isTrue);

      // Los 11 vecinos de ejemplo restantes, todos comunes.
      for (final id in [
        'jorge',
        'ana',
        'martin',
        'pedro',
        'laura',
        'sofia',
        'raul',
        'ines',
        'rosa',
        'ernesto',
        'elena',
      ]) {
        final vecino = servidor.actualizarVecino(id, {});
        expect(vecino['rol'], 'vecino', reason: id);
      }
    });

    test('quien se registra queda como vecino aunque mande rol comision', () {
      final sesion = servidor.registrar({
        'nombre': 'Nuevo Vecino',
        'fecha_nacimiento': '1990-01-01',
        'rol': 'comision',
      });
      final vecino = sesion['vecino'] as Map<String, dynamic>;
      expect(vecino['rol'], 'vecino');
      expect(Vecino.fromJson(vecino).rol, RolVecino.vecino);

      // Y queda guardado así: una actualización posterior lo confirma.
      final guardado = servidor.actualizarVecino(vecino['id'] as String, {});
      expect(guardado['rol'], 'vecino');
    });

    test('cambiar el rol en la actualización falla con el mensaje del '
        'servidor', () {
      for (final (id, otroRol) in [('rosa', 'comision'), ('clara', 'vecino')]) {
        expect(
          () => servidor.actualizarVecino(id, {
            'rol': otroRol,
            'nombre': 'Otro Nombre',
          }),
          throwsA(
            isA<ErrorDelServidor>().having(
              (e) => e.mensaje,
              'mensaje',
              'El rol no se puede cambiar desde la app.',
            ),
          ),
          reason: id,
        );
        // Nada cambió.
        final igual = servidor.actualizarVecino(id, {});
        expect(igual['rol'], otroRol == 'comision' ? 'vecino' : 'comision');
        expect(igual['nombre'], isNot('Otro Nombre'));
      }
    });

    test('actualizar con el mismo rol no falla', () {
      final rosa = servidor.actualizarVecino('rosa', {
        'rol': 'vecino',
        'telefono': '261 555-0001',
      });
      expect(rosa['rol'], 'vecino');
      expect(rosa['telefono'], '261 555-0001');

      final clara = servidor.actualizarVecino('clara', {'rol': 'comision'});
      expect(clara['rol'], 'comision');
    });

    /// Todos los vecinos de [turno]: patrulleros y guardia de ventana.
    List<Map<String, dynamic>> vecinosDe(Map<String, dynamic> turno) => [
      ...(turno['patrulleros'] as List).cast<Map<String, dynamic>>(),
      if (turno['guardia_ventana'] != null)
        turno['guardia_ventana'] as Map<String, dynamic>,
    ];

    test('los vecinos de los turnos no traen el rol', () {
      final turnos = servidor.turnosDelMes(2026, 10);
      final delNueve = turnos.firstWhere(
        (t) => t['fecha'] == '2026-10-09' && t['franja'] == 'noche',
      );
      expect(vecinosDe(delNueve).map((v) => v['id']), [
        'clara',
        'sofia',
        'ernesto',
      ]);
      for (final turno in turnos) {
        for (final vecino in vecinosDe(turno)) {
          expect(vecino.containsKey('rol'), isFalse, reason: '${vecino['id']}');
        }
      }

      final anotado = servidor.anotarse('2026-10-30', 'noche', 'clara');
      expect(vecinosDe(anotado).map((v) => v['id']), contains('clara'));
      for (final vecino in vecinosDe(anotado)) {
        expect(vecino.containsKey('rol'), isFalse, reason: '${vecino['id']}');
      }

      final sinClara = servidor.salir('2026-10-09', 'noche', 'clara');
      expect(vecinosDe(sinClara), isNotEmpty);
      for (final vecino in vecinosDe(sinClara)) {
        expect(vecino.containsKey('rol'), isFalse, reason: '${vecino['id']}');
      }
    });

    test('sacar el rol de los turnos no le quita el rol a la vecina', () {
      servidor.turnosDelMes(2026, 10);
      servidor.anotarse('2026-10-30', 'noche', 'clara');

      final clara = servidor.ingresar('261 555-0142', 'x')['vecino'];
      expect(clara['rol'], 'comision');
    });
  });

  test('crear una alerta la agrega al principio de la caché', () async {
    final falsas = AlertasFalsas([alertaDePrueba()]);
    await falsas.crearAlerta(
      categoria: alertaDePrueba().categoria,
      tipo: 'SOS',
      descripcion: '',
      direccion: '',
      ubicacion: alertaDePrueba().ubicacion,
      reportadaPor: 'clara',
    );
    final alertas = await falsas.obtenerAlertas();
    expect(alertas.first.id, startsWith('nueva'));
  });

  group('Llegadas de los avisos', () {
    final ahora = DateTime(2026, 10, 1, 12);

    AvisosRecibidosRepositoryLocal crear(Preferencias preferencias) =>
        AvisosRecibidosRepositoryLocal(
          preferencias: preferencias,
          reloj: RelojFijo(ahora),
        );

    test(
      'la llegada es la hora del teléfono más el desfase guardado',
      () async {
        final preferencias = preferenciasEnMemoria();
        final avisos = crear(preferencias);
        await avisos.guardarDesfase(const Duration(minutes: -3));
        expect(await preferencias.desfaseReloj(), -180000);

        final llegada = await avisos.registrarLlegada('a1');

        expect(llegada, ahora.subtract(const Duration(minutes: 3)));
        expect((await avisos.llegadas())['a1'], llegada);
      },
    );

    test('sin desfase guardado la llegada es la hora del teléfono', () async {
      final avisos = crear(preferenciasEnMemoria());
      expect(await avisos.registrarLlegada('a1'), ahora);
    });

    test('la segunda llegada de la misma alerta conserva la primera', () async {
      final preferencias = preferenciasEnMemoria();
      await crear(preferencias).registrarLlegada('a1');

      // Más tarde, otra instancia (por ejemplo, el isolate del push).
      final despues = AvisosRecibidosRepositoryLocal(
        preferencias: preferencias,
        reloj: RelojFijo(ahora.add(const Duration(hours: 1))),
      );
      expect(await despues.registrarLlegada('a1'), ahora);
      expect((await despues.llegadas())['a1'], ahora);
    });

    test('las llegadas de más de 30 días se borran al registrar', () async {
      final viejo = ahora.subtract(const Duration(days: 31));
      final reciente = ahora.subtract(const Duration(days: 29));
      final preferencias = preferenciasEnMemoria({
        Preferencias.claveAvisosRecibidos: jsonEncode({
          'vieja': viejo.millisecondsSinceEpoch,
          'reciente': reciente.millisecondsSinceEpoch,
        }),
      });
      final avisos = crear(preferencias);

      await avisos.registrarLlegada('nueva');

      expect((await avisos.llegadas()).keys.toSet(), {'reciente', 'nueva'});
    });

    test('una clave ilegible se lee como sin llegadas', () async {
      final avisos = crear(
        preferenciasEnMemoria({Preferencias.claveAvisosRecibidos: 'no-json'}),
      );
      expect(await avisos.llegadas(), isEmpty);
    });
  });

  test('el servidor simulado devuelve el primer nombre de quien reportó', () {
    final servidor = ServidorSimulado(
      reloj: RelojFijo(DateTime(2026, 10, 1, 12)),
      demora: Duration.zero,
    );

    final porId = {for (final a in servidor.alertas()) a['id']: a};
    expect(porId['a1']!['reportada_por_nombre'], 'Clara');
    expect(porId['a2']!['reportada_por_nombre'], 'Martín');

    final creada = servidor.crearAlerta({
      'categoria': 'robo',
      'tipo': 'Robo',
      'descripcion': '',
      'direccion': '',
      'latitud': -32.87,
      'longitud': -68.87,
      'reportada_por': 'rosa',
    });
    expect(creada['reportada_por_nombre'], 'Rosa');
    expect(
      servidor.cambiarEstadoDeAlerta('a1', 'resuelta')['reportada_por_nombre'],
      'Clara',
    );

    // Un vecino que no existe da nombre vacío.
    final huerfana = servidor.crearAlerta({
      'categoria': 'robo',
      'tipo': 'Robo',
      'descripcion': '',
      'direccion': '',
      'latitud': -32.87,
      'longitud': -68.87,
      'reportada_por': 'nadie',
    });
    expect(Alerta.fromJson(huerfana).reportadaPorNombre, '');
  });
}
