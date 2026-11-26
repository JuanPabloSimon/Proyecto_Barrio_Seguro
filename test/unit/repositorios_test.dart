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
import 'package:barrio_seguro/data/services/simulados/alertas_service_simulado.dart';
import 'package:barrio_seguro/data/services/simulados/servidor_simulado.dart';
import 'package:barrio_seguro/data/services/simulados/turnos_service_simulado.dart';
import 'package:barrio_seguro/domain/models/alerta.dart';
import 'package:barrio_seguro/domain/models/turno.dart';
import 'package:barrio_seguro/domain/models/vecino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import '../ayudas/app_de_prueba.dart';
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

  group('Alertas contra el servidor simulado', () {
    late ServidorSimulado servidor;
    late AlertasRepositoryRemoto repositorio;

    setUp(() {
      servidor = ServidorSimulado(
        reloj: RelojFijo(DateTime(2026, 10, 1, 12)),
        demora: Duration.zero,
      );
      repositorio = AlertasRepositoryRemoto(
        service: AlertasServiceSimulado(servidor),
      );
    });

    Future<Alerta> crear({
      CategoriaAlerta categoria = CategoriaAlerta.actividadSospechosa,
      String tipo = 'Actividad sospechosa',
    }) => repositorio.crearAlerta(
      categoria: categoria,
      tipo: tipo,
      descripcion: '',
      direccion: '',
      ubicacion: const LatLng(-32.877, -68.87),
      reportadaPor: 'clara',
    );

    Matcher errorCon(String mensaje) => throwsA(
      isA<ErrorDelServidor>().having((e) => e.mensaje, 'mensaje', mensaje),
    );

    test('el servidor simulado rechaza una alerta de arrebato con '
        '"Elegí qué tipo de alerta es."', () async {
      await expectLater(
        () => crear(categoria: CategoriaAlerta.arrebato, tipo: 'Arrebato'),
        errorCon('Elegí qué tipo de alerta es.'),
      );
      expect(
        servidor.alertas().where((a) => a['categoria'] == 'arrebato'),
        isEmpty,
      );
    });

    test(
      'el servidor simulado rechaza un título vacío con el mismo mensaje que '
      'la API',
      () async {
        await expectLater(
          () => crear(tipo: '   '),
          errorCon('Escribí un título para la alerta.'),
        );
        expect(
          () => servidor.crearAlerta({
            'categoria': 'robo',
            'tipo': 'Robo',
            'descripcion': 'a' * 501,
            'direccion': '',
            'latitud': -32.87,
            'longitud': -68.87,
            'reportada_por': 'clara',
          }),
          errorCon('Acortá la descripción: puede tener hasta 500 letras.'),
        );
        expect(
          () => servidor.crearAlerta({
            'categoria': 'robo',
            'tipo': 'Robo',
            'descripcion': '',
            'direccion': 'a' * 121,
            'latitud': -32.87,
            'longitud': -68.87,
            'reportada_por': 'clara',
          }),
          errorCon('Acortá la dirección: puede tener hasta 120 letras.'),
        );
      },
    );

    test('una alerta nueva del servidor simulado queda activa', () async {
      final alerta = await crear();
      expect(alerta.estado, EstadoAlerta.activa);
      expect(alerta.categoria, CategoriaAlerta.actividadSospechosa);
      final guardada = servidor.alertas().firstWhere(
        (a) => a['id'] == alerta.id,
      );
      expect(guardada['estado'], 'activa');
    });

    test(
      'los datos del servidor simulado no tienen alertas de arrebato y a4 es '
      '"Robo de celular"',
      () {
        final alertas = servidor.alertas();
        expect(alertas.where((a) => a['categoria'] == 'arrebato'), isEmpty);
        final a4 = alertas.firstWhere((a) => a['id'] == 'a4');
        expect(a4['categoria'], 'robo');
        expect(a4['tipo'], 'Robo de celular');
        expect(
          a4['descripcion'],
          'Le sacaron el celular a una vecina en la parada del colectivo.',
        );
        expect(a4['direccion'], 'Parada de colectivo de Carlos W. Lencinas');
        expect(a4['latitud'], -32.879792);
        expect(a4['longitud'], -68.868027);
        expect(a4['estado'], 'resuelta');
        expect(a4['reportada_por'], 'clara');
      },
    );

    String estadoDe(String id) =>
        servidor.alertas().firstWhere((a) => a['id'] == id)['estado'] as String;

    Map<String, dynamic> registrarVecinoComun() => servidor.registrar({
      'nombre': 'Nuevo Vecino',
      'fecha_nacimiento': '1990-01-01',
    });

    test(
      'la comisión cambia el estado de una alerta ajena en el simulado',
      () async {
        // La sesión arranca en Clara, que es de la comisión; a2 es de Martín.
        final alerta = await repositorio.cambiarEstado(
          'a2',
          EstadoAlerta.enAtencion,
        );
        expect(alerta.estado, EstadoAlerta.enAtencion);
        expect(alerta.reportadaPor, 'martin');
        expect(estadoDe('a2'), 'en_atencion');

        final resuelta = await repositorio.cambiarEstado(
          'a2',
          EstadoAlerta.resuelta,
        );
        expect(resuelta.estado, EstadoAlerta.resuelta);
        expect(estadoDe('a2'), 'resuelta');
      },
    );

    test('quien la reportó cambia el estado en el simulado', () async {
      final id = (registrarVecinoComun()['vecino'] as Map)['id'] as String;
      final creada = Alerta.fromJson(
        servidor.crearAlerta({
          'categoria': 'robo',
          'tipo': 'Robo',
          'descripcion': '',
          'direccion': '',
          'latitud': -32.87,
          'longitud': -68.87,
          'reportada_por': id,
        }),
      );

      final alerta = await repositorio.cambiarEstado(
        creada.id,
        EstadoAlerta.resuelta,
      );

      expect(alerta.estado, EstadoAlerta.resuelta);
      expect(estadoDe(creada.id), 'resuelta');
    });

    test('un vecino común no cambia una alerta ajena en el simulado', () async {
      registrarVecinoComun();
      await expectLater(
        () => repositorio.cambiarEstado('a1', EstadoAlerta.resuelta),
        errorCon(
          'Solo quien reportó la alerta o la comisión vecinal pueden '
          'cambiar su estado.',
        ),
      );
      expect(estadoDe('a1'), 'activa');
    });

    test('el simulado reabre una alerta resuelta', () async {
      expect(estadoDe('a4'), 'resuelta');
      final alerta = await repositorio.cambiarEstado('a4', EstadoAlerta.activa);
      expect(alerta.estado, EstadoAlerta.activa);
      expect(estadoDe('a4'), 'activa');
    });

    test('el simulado rechaza un estado que no existe o una alerta que no '
        'existe', () {
      expect(
        () => servidor.cambiarEstadoDeAlerta('a1', 'cerrada'),
        errorCon('Ese estado no existe.'),
      );
      expect(
        () => servidor.cambiarEstadoDeAlerta('no-existe', 'activa'),
        errorCon('No encontramos esa alerta.'),
      );
      expect(estadoDe('a1'), 'activa');
    });

    test('al volver a ingresar la sesión vuelve a la vecina de ejemplo', () {
      registrarVecinoComun();
      servidor.ingresar('261 555-0142', 'x');
      expect(
        servidor.cambiarEstadoDeAlerta('a2', 'activa')['estado'],
        'activa',
      );
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

  group('Guardia normal contra el servidor simulado', () {
    late ServidorSimulado servidor;

    setUp(() {
      servidor = ServidorSimulado(reloj: relojDePrueba, demora: Duration.zero);
    });

    /// El turno de [fecha] y [franja] como lo devuelve el simulado.
    Map<String, dynamic> turnoDe(String fecha, String franja) {
      final dia = DateTime.parse(fecha);
      return servidor
          .turnosDelMes(dia.year, dia.month)
          .firstWhere((t) => t['fecha'] == fecha && t['franja'] == franja);
    }

    List<String> idsDe(Object? vecinos) => [
      for (final v in vecinos as List) (v as Map<String, dynamic>)['id'],
    ];

    test('Rosa activa la guardia normal y queda guardada', () {
      final activada = servidor.actualizarVecino('rosa', {
        'guardia_normal': true,
      });
      expect(activada['guardia_normal'], isTrue);

      final sinElCampo = servidor.actualizarVecino('rosa', {'calle': 'Otra'});
      expect(sinElCampo['guardia_normal'], isTrue);
      expect(sinElCampo['calle'], 'Otra');
    });

    test('un menor no puede activarla', () {
      final antes = servidor.actualizarVecino('clara', {});
      expect(
        () => servidor.actualizarVecino('clara', {
          'nombre': 'Otro nombre',
          'guardia_normal': true,
        }),
        throwsA(
          isA<ErrorDelServidor>().having(
            (e) => e.mensaje,
            'mensaje',
            'Solo los vecinos de 70 años o más pueden elegir la guardia '
                'normal.',
          ),
        ),
      );
      expect(servidor.actualizarVecino('clara', {}), antes);

      final conFalse = servidor.actualizarVecino('clara', {
        'guardia_normal': false,
      });
      expect(conFalse['guardia_normal'], isFalse);
    });

    test('un valor que no es booleano se rechaza', () {
      final antes = servidor.actualizarVecino('rosa', {});
      expect(
        () => servidor.actualizarVecino('rosa', {
          'calle': 'Otra',
          'guardia_normal': 'si',
        }),
        throwsA(
          isA<ErrorDelServidor>().having(
            (e) => e.mensaje,
            'mensaje',
            'La opción de guardia normal no es válida.',
          ),
        ),
      );
      expect(servidor.actualizarVecino('rosa', {}), antes);
    });

    test('quien se registra arranca sin guardia normal', () {
      final sesion = servidor.registrar({
        'nombre': 'Nuevo Mayor',
        'fecha_nacimiento': '1940-01-01',
        'guardia_normal': true,
      });
      final vecino = sesion['vecino'] as Map<String, dynamic>;
      expect(vecino['guardia_normal'], isFalse);
      expect(Vecino.fromJson(vecino).guardiaNormal, isFalse);
    });

    test('Rosa sin guardia normal se anota como guardia de ventana', () {
      final turno = servidor.anotarse('2026-11-06', 'noche', 'rosa');
      expect((turno['guardia_ventana'] as Map<String, dynamic>)['id'], 'rosa');
      expect(idsDe(turno['patrulleros']), isEmpty);
    });

    test('Rosa con guardia normal se anota en la patrulla', () {
      servidor.actualizarVecino('rosa', {'guardia_normal': true});
      final turno = servidor.anotarse('2026-11-13', 'noche', 'rosa');
      expect(idsDe(turno['patrulleros']), ['rosa']);
      expect(turno['guardia_ventana'], isNull);
    });

    test('cambiar la guardia normal no mueve los turnos ya tomados', () {
      expect(
        (turnoDe('2026-10-02', 'noche')['guardia_ventana'] as Map)['id'],
        'rosa',
      );

      servidor.actualizarVecino('rosa', {'guardia_normal': true});
      final octubre = turnoDe('2026-10-02', 'noche');
      expect((octubre['guardia_ventana'] as Map)['id'], 'rosa');
      expect(idsDe(octubre['patrulleros']), ['jorge', 'ana']);

      servidor.anotarse('2026-11-06', 'noche', 'rosa');
      servidor.actualizarVecino('rosa', {'guardia_normal': false});
      final noviembre = turnoDe('2026-11-06', 'noche');
      expect(idsDe(noviembre['patrulleros']), ['rosa']);
      expect(noviembre['guardia_ventana'], isNull);
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

    test(
      'horaDelServidor suma el desfase y no guarda ninguna llegada',
      () async {
        final preferencias = preferenciasEnMemoria();
        final avisos = crear(preferencias);
        expect(await avisos.horaDelServidor(), ahora);

        await avisos.guardarDesfase(const Duration(minutes: 2));
        expect(
          await avisos.horaDelServidor(),
          ahora.add(const Duration(minutes: 2)),
        );
        expect(await avisos.llegadas(), isEmpty);
        expect(await preferencias.avisosRecibidos(), isEmpty);
      },
    );

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
