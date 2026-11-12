// Pruebas de los servicios HTTP sin red: MockClient (de package:http)
// responde en lugar de la API y deja revisar cada pedido.

import 'dart:convert';

import 'package:barrio_seguro/data/repositories/sesion_repository.dart';
import 'package:barrio_seguro/data/services/error_del_servidor.dart';
import 'package:barrio_seguro/data/services/http/alertas_service_http.dart';
import 'package:barrio_seguro/data/services/http/cliente_api.dart';
import 'package:barrio_seguro/data/services/http/turnos_service_http.dart';
import 'package:barrio_seguro/data/services/http/vecinos_service_http.dart';
import 'package:barrio_seguro/data/services/local/almacen_seguro.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../ayudas/bases_de_prueba.dart';
import '../ayudas/falsos.dart';

final base = Uri.parse('http://10.0.2.2:8080');

http.Response json(int codigo, Object? cuerpo) => http.Response(
  jsonEncode(cuerpo),
  codigo,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  late AlmacenSeguro almacen;
  late List<http.Request> pedidos;

  setUp(() {
    almacen = almacenSeguroEnMemoria();
    pedidos = [];
  });

  /// Un ClienteApi cuya "API" responde con [responder].
  ClienteApi clienteQue(
    Future<http.Response> Function(http.Request pedido) responder,
  ) {
    return ClienteApi(
      base: base,
      almacen: almacen,
      cliente: MockClient((pedido) {
        pedidos.add(pedido);
        return responder(pedido);
      }),
    );
  }

  group('ClienteApi', () {
    test('manda el token de la sesión en cada pedido', () async {
      await almacen.guardarToken('abc123');
      final api = clienteQue((_) async => json(200, []));

      await AlertasServiceHttp(api).obtenerAlertas();

      expect(pedidos.single.url.toString(), 'http://10.0.2.2:8080/alertas');
      expect(pedidos.single.headers['authorization'], 'Bearer abc123');
    });

    test('la barra final en la dirección de la API no molesta', () async {
      final api = ClienteApi(
        base: Uri.parse('http://10.0.2.2:8080/'),
        almacen: almacen,
        cliente: MockClient((pedido) async {
          pedidos.add(pedido);
          return json(200, []);
        }),
      );
      await AlertasServiceHttp(api).obtenerAlertas();
      expect(pedidos.single.url.path, '/alertas');
    });

    test('un error de la API llega con su mensaje', () async {
      final api = clienteQue(
        (_) async => json(409, {
          'error': 'Ya tenés 2 turnos este mes, que es el máximo permitido.',
        }),
      );

      await expectLater(
        TurnosServiceHttp(api)
            .anotarse(fecha: '2026-10-31', franja: 'noche', vecinoId: 'clara'),
        throwsA(
          isA<ErrorDelServidor>().having(
            (e) => e.mensaje,
            'mensaje',
            contains('máximo'),
          ),
        ),
      );
    });

    test('un error sin mensaje muestra uno genérico', () async {
      final api = clienteQue((_) async => http.Response('', 500));
      await expectLater(
        AlertasServiceHttp(api).obtenerAlertas(),
        throwsA(isA<ErrorDelServidor>()),
      );
    });

    test(
      'sin conexión deja pasar el error de red (no es del servidor)',
      () async {
        final api = clienteQue(
          (_) async => throw http.ClientException('Connection refused'),
        );
        await expectLater(
          AlertasServiceHttp(api).obtenerAlertas(),
          throwsA(isA<http.ClientException>()),
        );
      },
    );

    test('los acentos llegan bien aunque no se aclare el charset', () async {
      final api = clienteQue(
        (_) async => http.Response.bytes(
          utf8.encode(jsonEncode({'error': 'Ingresá tu nombre.'})),
          400,
        ),
      );
      await expectLater(
        VecinosServiceHttp(api).actualizar('clara', {'nombre': ''}),
        throwsA(
          isA<ErrorDelServidor>().having(
            (e) => e.mensaje,
            'mensaje',
            'Ingresá tu nombre.',
          ),
        ),
      );
    });
  });

  group('Rutas', () {
    test('turnos del mes con año y mes en la dirección', () async {
      final api = clienteQue((_) async => json(200, []));
      await TurnosServiceHttp(api).obtenerTurnos(anio: 2026, mes: 10);
      expect(pedidos.single.method, 'GET');
      expect(pedidos.single.url.path, '/turnos');
      expect(pedidos.single.url.queryParameters, {'anio': '2026', 'mes': '10'});
    });

    test('anotarse y salir de un turno', () async {
      final turno = {
        'fecha': '2026-10-30',
        'franja': 'noche',
        'patrulleros': [],
        'guardia_ventana': null,
      };
      final api = clienteQue((_) async => json(200, turno));
      final servicio = TurnosServiceHttp(api);

      await servicio.anotarse(
        fecha: '2026-10-30',
        franja: 'noche',
        vecinoId: 'clara',
      );
      await servicio.salir(
        fecha: '2026-10-30',
        franja: 'noche',
        vecinoId: 'clara',
      );

      expect(pedidos.map((p) => '${p.method} ${p.url.path}'), [
        'PUT /turnos/2026-10-30/noche/vecinos/clara',
        'DELETE /turnos/2026-10-30/noche/vecinos/clara',
      ]);
    });

    test('cambiar el estado de una alerta manda el estado en JSON', () async {
      final api = clienteQue((_) async => json(200, alertaDePrueba().toJson()));
      await AlertasServiceHttp(api).cambiarEstado('a1', 'resuelta');
      expect(pedidos.single.method, 'PATCH');
      expect(pedidos.single.url.path, '/alertas/a1');
      expect(jsonDecode(pedidos.single.body), {'estado': 'resuelta'});
    });
  });

  group('Sesión contra la API', () {
    SesionRepositoryRemoto sesionCon(ClienteApi api) => SesionRepositoryRemoto(
      service: VecinosServiceHttp(api),
      preferencias: preferenciasEnMemoria(),
      almacen: almacen,
    );

    test('ingresar guarda el token que manda la API', () async {
      final api = clienteQue(
        (_) async => json(200, {
          'token': 'token-nuevo',
          'vecino': vecinaDePrueba.toJson(),
        }),
      );

      final vecino = await sesionCon(api)
          .ingresar(usuario: '261 555-0142', clave: 'barrio1234');

      expect(vecino.nombre, 'Clara Medina');
      expect(await almacen.token(), 'token-nuevo');
      expect(jsonDecode(pedidos.single.body), {
        'usuario': '261 555-0142',
        'clave': 'barrio1234',
      });
    });

    test('cerrar sesión avisa a la API y borra el token', () async {
      await almacen.guardarToken('viejo');
      final api = clienteQue((_) async => http.Response('', 204));

      await sesionCon(api).cerrarSesion();

      expect(pedidos.single.method, 'DELETE');
      expect(pedidos.single.url.path, '/sesiones');
      expect(await almacen.token(), isNull);
    });

    test('sin conexión, cerrar sesión igual borra el token', () async {
      await almacen.guardarToken('viejo');
      final api = clienteQue(
        (_) async => throw http.ClientException('sin red'),
      );
      await sesionCon(api).cerrarSesion();
      expect(await almacen.token(), isNull);
    });
  });
}
