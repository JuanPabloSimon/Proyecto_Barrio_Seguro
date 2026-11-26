// Pruebas de la detección de conexión: el servicio que hace `GET /salud`,
// el repositorio que la comparte y el ViewModel que decide cuándo mirar.

import 'dart:convert';
import 'dart:io';

import 'package:barrio_seguro/data/repositories/conexion_repository.dart';
import 'package:barrio_seguro/data/services/bus_de_eventos.dart';
import 'package:barrio_seguro/data/services/http/cliente_api.dart';
import 'package:barrio_seguro/data/services/http/conexion_service_http.dart';
import 'package:barrio_seguro/data/services/local/almacen_seguro.dart';
import 'package:barrio_seguro/data/services/reloj.dart';
import 'package:barrio_seguro/domain/evento_de_app.dart';
import 'package:barrio_seguro/ui/conexion/view_models/conexion_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../ayudas/bases_de_prueba.dart';
import '../ayudas/falsos.dart';

final _base = Uri.parse('http://10.0.2.2:8080');

void main() {
  group('ConexionServiceHttp', () {
    late AlmacenSeguro almacen;
    late List<http.Request> pedidos;

    setUp(() {
      almacen = almacenSeguroEnMemoria();
      pedidos = [];
    });

    ConexionServiceHttp servicioQue(
      Future<http.Response> Function(http.Request pedido) responder, {
      Reloj reloj = const RelojDelSistema(),
    }) {
      return ConexionServiceHttp(
        ClienteApi(
          base: _base,
          almacen: almacen,
          cliente: MockClient((pedido) {
            pedidos.add(pedido);
            return responder(pedido);
          }),
        ),
        reloj: reloj,
      );
    }

    test(
      '/salud con ahora mide el desfase en el punto medio del pedido',
      () async {
        // El teléfono marca 12:00:00 al salir y 12:00:02 al volver: el punto
        // medio es 12:00:01. El servidor dice 12:10:01: desfase de 10 minutos.
        final reloj = _RelojQueAvanza([
          DateTime(2026, 10, 1, 12),
          DateTime(2026, 10, 1, 12, 0, 2),
        ]);
        final servidor = DateTime(2026, 10, 1, 12, 10, 1);
        final servicio = servicioQue(
          (_) async => http.Response(
            jsonEncode({
              'estado': 'ok',
              'ahora': servidor.millisecondsSinceEpoch,
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
          reloj: reloj,
        );

        expect(servicio.desfase, isNull);
        expect(await servicio.hayConexion(), isTrue);
        expect(servicio.desfase, const Duration(minutes: 10));
      },
    );

    test(
      '/salud sin ahora no cambia el desfase y sigue dando conexión',
      () async {
        var conAhora = true;
        final ahora = DateTime(2026, 10, 1, 12);
        final servicio = servicioQue(
          (_) async => http.Response(
            jsonEncode({
              'estado': 'ok',
              if (conAhora)
                'ahora': ahora
                    .add(const Duration(seconds: 30))
                    .millisecondsSinceEpoch,
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
          reloj: RelojFijo(ahora),
        );

        await servicio.hayConexion();
        expect(servicio.desfase, const Duration(seconds: 30));

        conAhora = false;
        expect(await servicio.hayConexion(), isTrue);
        expect(servicio.desfase, const Duration(seconds: 30));
      },
    );

    test('/salud con {"estado":"ok"} da conexión', () async {
      final servicio = servicioQue(
        (_) async => http.Response(
          jsonEncode({'estado': 'ok'}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );

      expect(await servicio.hayConexion(), isTrue);
      expect(pedidos.single.method, 'GET');
      expect(pedidos.single.url.path, '/salud');
    });

    test('/salud con HTML de portal de acceso da sin conexión', () async {
      final servicio = servicioQue(
        (_) async => http.Response(
          '<html><body>Iniciá sesión en el wifi del bar</body></html>',
          200,
          headers: {'content-type': 'text/html'},
        ),
      );

      expect(await servicio.hayConexion(), isFalse);
    });

    test(
      '/salud con un JSON distinto de {"estado":"ok"} da sin conexión',
      () async {
        final servicio = servicioQue(
          (_) async => http.Response(jsonEncode({'estado': 'mal'}), 200),
        );

        expect(await servicio.hayConexion(), isFalse);
      },
    );

    test('/salud con 500 da sin conexión', () async {
      final servicio = servicioQue(
        (_) async => http.Response(jsonEncode({'error': 'Se rompió'}), 500),
      );

      expect(await servicio.hayConexion(), isFalse);
    });

    test('error de red da sin conexión', () async {
      final servicio = servicioQue(
        (_) async => throw const SocketException('sin señal'),
      );

      expect(await servicio.hayConexion(), isFalse);
    });

    test('espera 5 s como máximo', () {
      final servicio = servicioQue((_) async => http.Response('{}', 200));
      expect(servicio.espera, const Duration(seconds: 5));
    });

    testWidgets('/salud que tarda más de 5 s da sin conexión', (tester) async {
      final servicio = servicioQue((_) async {
        await Future<void>.delayed(const Duration(seconds: 6));
        return http.Response(jsonEncode({'estado': 'ok'}), 200);
      });

      bool? resultado;
      servicio.hayConexion().then((r) => resultado = r);

      await tester.pump(const Duration(seconds: 4));
      expect(resultado, isNull);
      await tester.pump(const Duration(seconds: 2));
      expect(resultado, isFalse);
    });

    testWidgets('/salud que responde en menos de 5 s da conexión', (
      tester,
    ) async {
      final servicio = servicioQue((_) async {
        await Future<void>.delayed(const Duration(seconds: 4));
        return http.Response(jsonEncode({'estado': 'ok'}), 200);
      });

      bool? resultado;
      servicio.hayConexion().then((r) => resultado = r);

      await tester.pump(const Duration(seconds: 4, milliseconds: 500));
      expect(resultado, isTrue);
    });
  });

  group('ConexionRepositoryRemoto', () {
    test('una comprobación buena guarda el desfase en el teléfono', () async {
      final servicio = ConexionFalsa(desfase: const Duration(minutes: 7));
      final avisos = AvisosRecibidosFalsos();
      final repositorio = ConexionRepositoryRemoto(
        service: servicio,
        avisos: avisos,
      );
      addTearDown(repositorio.cerrar);

      await repositorio.comprobar();
      await Future<void>.delayed(Duration.zero);
      expect(avisos.desfase, const Duration(minutes: 7));

      // Sin conexión, o sin desfase medido, no se pisa el guardado.
      servicio
        ..hay = false
        ..desfase = const Duration(hours: 3);
      await repositorio.comprobar();
      servicio
        ..hay = true
        ..desfase = null;
      await repositorio.comprobar();
      await Future<void>.delayed(Duration.zero);
      expect(avisos.desfase, const Duration(minutes: 7));
    });

    test('dos comprobar() simultáneos hacen un solo pedido', () async {
      final servicio = ConexionFalsa(demora: const Duration(milliseconds: 10));
      final repositorio = ConexionRepositoryRemoto(service: servicio);
      addTearDown(repositorio.cerrar);

      final resultados = await Future.wait([
        repositorio.comprobar(),
        repositorio.comprobar(),
      ]);

      expect(resultados, [true, true]);
      expect(servicio.comprobaciones, 1);

      // Terminado el pedido, la próxima comprobación pide de nuevo.
      await repositorio.comprobar();
      expect(servicio.comprobaciones, 2);
    });

    test('hayConexion es null hasta la primera comprobación', () async {
      final servicio = ConexionFalsa(hay: false);
      final repositorio = ConexionRepositoryRemoto(service: servicio);
      addTearDown(repositorio.cerrar);

      expect(repositorio.hayConexion, isNull);
      expect(await repositorio.comprobar(), isFalse);
      expect(repositorio.hayConexion, isFalse);
    });

    test('cambios emite solo cuando cambia el resultado', () async {
      final servicio = ConexionFalsa();
      final repositorio = ConexionRepositoryRemoto(service: servicio);
      addTearDown(repositorio.cerrar);
      final emitidos = <bool>[];
      repositorio.cambios.listen(emitidos.add);

      await repositorio.comprobar(); // null → true
      await repositorio.comprobar(); // true → true: no emite
      servicio.hay = false;
      await repositorio.comprobar(); // true → false
      await repositorio.comprobar(); // false → false: no emite
      servicio.hay = true;
      await repositorio.comprobar(); // false → true
      await Future<void>.delayed(Duration.zero);

      expect(emitidos, [true, false, true]);
    });
  });

  group('ConexionViewModel', () {
    late ConexionRepositoryFalsa conexion;
    late BusDeEventos bus;
    late List<EventoDeApp> eventos;

    setUp(() {
      conexion = ConexionRepositoryFalsa();
      bus = BusDeEventos();
      eventos = [];
      bus.eventos.listen(eventos.add);
    });

    // Cada prueba termina con vm.dispose(): flutter_test revisa que no
    // queden relojes vivos antes de correr los addTearDown.
    ConexionViewModel crear() =>
        ConexionViewModel(conexion: conexion, bus: bus);

    testWidgets('al empezar comprueba la conexión', (tester) async {
      final vm = crear();
      expect(vm.estado, EstadoConexion.comprobando);

      vm.empezar();
      await tester.pump();

      expect(conexion.comprobaciones, 1);
      expect(vm.estado, EstadoConexion.conectado);
      expect(vm.sinConexion, isFalse);
      vm.dispose();
    });

    testWidgets('con conexión vuelve a comprobar a los 30 s', (tester) async {
      final vm = crear()..empezar();
      await tester.pump();
      expect(conexion.comprobaciones, 1);

      await tester.pump(const Duration(seconds: 29));
      expect(conexion.comprobaciones, 1);
      await tester.pump(const Duration(seconds: 1));
      expect(conexion.comprobaciones, 2);
      await tester.pump(const Duration(seconds: 30));
      expect(conexion.comprobaciones, 3);
      vm.dispose();
    });

    testWidgets('sin conexión vuelve a comprobar a los 5 s', (tester) async {
      conexion.hay = false;
      final vm = crear()..empezar();
      await tester.pump();
      expect(vm.estado, EstadoConexion.sinConexion);
      expect(conexion.comprobaciones, 1);

      await tester.pump(const Duration(seconds: 4));
      expect(conexion.comprobaciones, 1);
      await tester.pump(const Duration(seconds: 1));
      expect(conexion.comprobaciones, 2);
      await tester.pump(const Duration(seconds: 5));
      expect(conexion.comprobaciones, 3);
      vm.dispose();
    });

    testWidgets('en segundo plano no comprueba', (tester) async {
      final vm = crear()..empezar();
      await tester.pump();
      expect(conexion.comprobaciones, 1);

      vm.alPasarASegundoPlano();
      await tester.pump(const Duration(minutes: 5));

      expect(conexion.comprobaciones, 1);
      vm.dispose();
    });

    testWidgets('al volver a primer plano comprueba en el momento', (
      tester,
    ) async {
      final vm = crear()..empezar();
      await tester.pump();
      vm.alPasarASegundoPlano();
      await tester.pump(const Duration(minutes: 5));
      conexion.hay = false;

      vm.alVolverAPrimerPlano();
      await tester.pump();

      expect(conexion.comprobaciones, 2);
      expect(vm.estado, EstadoConexion.sinConexion);
      // Y el reloj vuelve a andar (sin conexión, cada 5 s).
      await tester.pump(const Duration(seconds: 5));
      expect(conexion.comprobaciones, 3);
      vm.dispose();
    });

    testWidgets(
      'si un repositorio dispara una comprobación sin conexión el estado pasa a sinConexion',
      (tester) async {
        final vm = crear()..empezar();
        await tester.pump();
        expect(vm.estado, EstadoConexion.conectado);

        // Un pedido de alertas falló por la red y el repositorio pidió
        // una comprobación por su cuenta.
        conexion.hay = false;
        await conexion.comprobar();
        await tester.pump();

        expect(vm.estado, EstadoConexion.sinConexion);
        vm.dispose();
      },
    );

    testWidgets(
      'al volver la conexión publica AlertasActualizadas y TurnosActualizados',
      (tester) async {
        conexion.hay = false;
        final vm = crear()..empezar();
        await tester.pump();
        expect(vm.sinConexion, isTrue);
        expect(eventos, isEmpty);

        conexion.hay = true;
        await tester.pump(const Duration(seconds: 5));
        await tester.pump();

        expect(vm.estado, EstadoConexion.conectado);
        expect(eventos, hasLength(2));
        expect(eventos, contains(isA<AlertasActualizadas>()));
        expect(eventos, contains(isA<TurnosActualizados>()));
        vm.dispose();
      },
    );

    testWidgets('con conexión desde el arranque no publica eventos', (
      tester,
    ) async {
      final vm = crear()..empezar();
      await tester.pump();
      await tester.pump(const Duration(seconds: 30));
      await tester.pump();

      expect(eventos, isEmpty);
      vm.dispose();
    });

    testWidgets('dispose cancela el reloj y la suscripción', (tester) async {
      final vm = ConexionViewModel(conexion: conexion, bus: bus)..empezar();
      await tester.pump();
      expect(conexion.tieneOyentes, isTrue);

      vm.dispose();
      await tester.pump(const Duration(minutes: 5));

      expect(conexion.comprobaciones, 1);
      expect(conexion.tieneOyentes, isFalse);
    });
  });
}

/// Devuelve las [horas] en orden, una por llamada (la última se repite).
class _RelojQueAvanza implements Reloj {
  _RelojQueAvanza(this.horas);

  final List<DateTime> horas;
  var _i = 0;

  @override
  DateTime ahora() => horas[_i < horas.length - 1 ? _i++ : _i];
}
