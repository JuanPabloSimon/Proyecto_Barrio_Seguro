// Pruebas de la API sin abrir un puerto: se le pasan pedidos (Request) al
// handler directamente y se miran las respuestas.

import 'dart:convert';
import 'dart:io';

import 'package:barrio_seguro_backend/barrio_seguro_backend.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

class PushServiceFalso implements PushService {
  PushServiceFalso({this.falla = false});

  bool falla;
  final List<Map<String, dynamic>> enviadas = [];

  @override
  Future<void> enviarAlerta(Map<String, dynamic> alerta) async {
    if (falla) throw Exception('fallo de FCM');
    if (alerta['estado'] == 'resuelta') return;
    enviadas.add(Map<String, dynamic>.of(alerta));
  }
}

const telefonoClara = '261 555-0142';
const telefonoRosa = '2615550177';
const clave = 'barrio1234';

void main() {
  late Handler api;
  late Api instanciaApi;
  late Almacen almacen;
  late PushServiceFalso push;
  final reloj = RelojFijo(DateTime(2026, 10, 1, 12));

  setUp(() {
    almacen = Almacen.abrir(reloj: reloj);
    push = PushServiceFalso();
    instanciaApi = Api(
      almacen: almacen,
      reloj: reloj,
      codigoComision: 'SOBERANIA',
      push: push,
    );
    api = instanciaApi.handler;
  });

  /// Hace un pedido y devuelve el código y el JSON de la respuesta.
  Future<(int, dynamic)> pedir(
    String metodo,
    String ruta, {
    Object? cuerpo,
    String? token,
  }) async {
    final respuesta = await api(
      Request(
        metodo,
        Uri.parse('http://localhost$ruta'),
        body: cuerpo == null ? null : jsonEncode(cuerpo),
        headers: {if (token != null) 'authorization': 'Bearer $token'},
      ),
    );
    final texto = await respuesta.readAsString();
    return (respuesta.statusCode, texto.isEmpty ? null : jsonDecode(texto));
  }

  Future<String> ingresar(String telefono) async {
    final (codigo, cuerpo) = await pedir(
      'POST',
      '/sesiones',
      cuerpo: {'usuario': telefono, 'clave': clave},
    );
    expect(codigo, 200);
    return cuerpo['token'] as String;
  }

  group('Sesiones', () {
    test('ingresar devuelve el token y los datos del vecino', () async {
      final (codigo, cuerpo) = await pedir(
        'POST',
        '/sesiones',
        // Sin espacios ni guiones también vale.
        cuerpo: {'usuario': '2615550142', 'clave': clave},
      );
      expect(codigo, 200);
      expect(cuerpo['token'], isNotEmpty);
      expect(cuerpo['vecino']['nombre'], 'Clara Medina');
      expect(cuerpo['vecino'], isNot(contains('hash')));
    });

    test('con la contraseña equivocada no entra', () async {
      final (codigo, cuerpo) = await pedir(
        'POST',
        '/sesiones',
        cuerpo: {'usuario': telefonoClara, 'clave': 'otra'},
      );
      expect(codigo, 401);
      expect(cuerpo['error'], contains('no son correctos'));
    });

    test('sin token, las rutas piden ingresar', () async {
      final (codigo, cuerpo) = await pedir('GET', '/alertas');
      expect(codigo, 401);
      expect(cuerpo['error'], contains('Ingresá de nuevo'));
    });

    test('al cerrar sesión el token deja de servir', () async {
      final token = await ingresar(telefonoClara);
      expect((await pedir('DELETE', '/sesiones', token: token)).$1, 204);
      expect((await pedir('GET', '/alertas', token: token)).$1, 401);
    });

    test('un JSON roto responde 400 con un mensaje', () async {
      final respuesta = await api(
        Request('POST', Uri.parse('http://localhost/sesiones'), body: '{'),
      );
      expect(respuesta.statusCode, 400);
    });
  });

  group('Registro', () {
    Map<String, dynamic> datos({
      String codigo = 'soberania',
      String telefono = '261 555-0999',
      String fecha = '1990-04-02',
    }) => {
      'nombre': 'Lucía Pérez',
      'fecha_nacimiento': fecha,
      'telefono': telefono,
      'calle': 'Plantamura',
      'cuadra': 'Cuadra 4',
      'codigo_comision': codigo,
      'clave': 'segura123',
    };

    test('crea la cuenta, abre la sesión y después puede ingresar', () async {
      final (codigo, cuerpo) = await pedir('POST', '/vecinos', cuerpo: datos());
      expect(codigo, 201);
      expect(cuerpo['vecino']['vecino_desde'], '2026-10-01');

      final (codigoLogin, _) = await pedir(
        'POST',
        '/sesiones',
        cuerpo: {'usuario': '2615550999', 'clave': 'segura123'},
      );
      expect(codigoLogin, 200);
    });

    test('sin el código de la comisión no se puede registrar', () async {
      final (codigo, _) = await pedir(
        'POST',
        '/vecinos',
        cuerpo: datos(codigo: 'otro'),
      );
      expect(codigo, 403);
    });

    test('no deja dos cuentas con el mismo teléfono', () async {
      final (codigo, cuerpo) = await pedir(
        'POST',
        '/vecinos',
        cuerpo: datos(telefono: '261-555-0142'),
      );
      expect(codigo, 409);
      expect(cuerpo['error'], 'Ya hay una cuenta con ese teléfono.');
    });

    test('rechaza una fecha de nacimiento futura', () async {
      final (codigo, _) = await pedir(
        'POST',
        '/vecinos',
        cuerpo: datos(fecha: '2030-01-01'),
      );
      expect(codigo, 400);
    });
  });

  group('Vecinos', () {
    test('cada uno cambia solo sus datos', () async {
      final token = await ingresar(telefonoClara);
      final (propio, cuerpo) = await pedir(
        'PUT',
        '/vecinos/clara',
        token: token,
        cuerpo: {'calle': 'Democracia', 'fecha_nacimiento': '2000-01-01'},
      );
      expect(propio, 200);
      expect(cuerpo['calle'], 'Democracia');
      // La fecha de nacimiento no se cambia desde la app.
      expect(cuerpo['fecha_nacimiento'], '1981-05-14');

      final (ajeno, _) = await pedir(
        'PUT',
        '/vecinos/rosa',
        token: token,
        cuerpo: {'calle': 'Otra'},
      );
      expect(ajeno, 403);
    });
  });

  group('Rol', () {
    Future<Map<String, dynamic>> vecinoAlIngresar(String telefono) async {
      final (codigo, cuerpo) = await pedir(
        'POST',
        '/sesiones',
        cuerpo: {'usuario': telefono, 'clave': clave},
      );
      expect(codigo, 200);
      return cuerpo['vecino'] as Map<String, dynamic>;
    }

    test('ingresar devuelve el rol de cada cuenta', () async {
      expect((await vecinoAlIngresar(telefonoClara))['rol'], 'comision');
      expect((await vecinoAlIngresar(telefonoRosa))['rol'], 'vecino');
    });

    test('de los vecinos de ejemplo, solo clara es de la comisión', () {
      // Se recorren todos: si otro quedara como comision, esto falla.
      expect(almacen.vecinos, hasLength(12));
      expect(almacen.vecinos, contains('clara'));
      for (final MapEntry(key: id, value: vecino) in almacen.vecinos.entries) {
        expect(
          vecino['rol'],
          id == 'clara' ? 'comision' : 'vecino',
          reason: id,
        );
      }
    });

    test('GET /vecinos/yo y PUT /vecinos/<id> devuelven el rol', () async {
      for (final (telefono, id, rol) in [
        (telefonoClara, 'clara', 'comision'),
        (telefonoRosa, 'rosa', 'vecino'),
      ]) {
        final token = await ingresar(telefono);
        final (codigoYo, yo) = await pedir('GET', '/vecinos/yo', token: token);
        expect(codigoYo, 200);
        expect(yo['rol'], rol);

        final (codigoPut, actualizado) = await pedir(
          'PUT',
          '/vecinos/$id',
          token: token,
          cuerpo: {'calle': 'Democracia'},
        );
        expect(codigoPut, 200);
        expect(actualizado['rol'], rol);
      }
    });

    test('registrarse da rol vecino aunque el pedido mande comision', () async {
      final (codigo, cuerpo) = await pedir(
        'POST',
        '/vecinos',
        cuerpo: {
          'nombre': 'Lucía Pérez',
          'fecha_nacimiento': '1990-04-02',
          'telefono': '261 555-0999',
          'codigo_comision': 'SOBERANIA',
          'clave': 'segura123',
          'rol': 'comision',
        },
      );
      expect(codigo, 201);
      expect(cuerpo['vecino']['rol'], 'vecino');

      final (_, yo) = await pedir(
        'GET',
        '/vecinos/yo',
        token: cuerpo['token'] as String,
      );
      expect(yo['rol'], 'vecino');
    });

    test('un vecino común no puede darse el rol comision: 403', () async {
      final token = await ingresar(telefonoRosa);
      final (codigo, cuerpo) = await pedir(
        'PUT',
        '/vecinos/rosa',
        token: token,
        cuerpo: {'rol': 'comision'},
      );
      expect(codigo, 403);
      expect(cuerpo, {'error': 'El rol no se puede cambiar desde la app.'});
    });

    test('el rol rechazado no cambia ningún dato', () async {
      final token = await ingresar(telefonoRosa);
      final (_, antes) = await pedir('GET', '/vecinos/yo', token: token);

      final (codigo, _) = await pedir(
        'PUT',
        '/vecinos/rosa',
        token: token,
        cuerpo: {'rol': 'comision', 'nombre': 'Rosa Cambiada'},
      );
      expect(codigo, 403);

      final (_, despues) = await pedir('GET', '/vecinos/yo', token: token);
      expect(despues, antes);
      expect(despues['rol'], 'vecino');
      expect(despues['nombre'], 'Rosa Ibáñez');
    });

    test('un miembro de la comisión tampoco cambia su rol por PUT', () async {
      final token = await ingresar(telefonoClara);
      final (codigo, cuerpo) = await pedir(
        'PUT',
        '/vecinos/clara',
        token: token,
        cuerpo: {'rol': 'vecino', 'calle': 'Otra'},
      );
      expect(codigo, 403);
      expect(cuerpo['error'], 'El rol no se puede cambiar desde la app.');

      final (_, yo) = await pedir('GET', '/vecinos/yo', token: token);
      expect(yo['rol'], 'comision');
      expect(yo['calle'], 'Cabildo de Mendoza');
    });

    test('mandar el mismo rol no falla', () async {
      final token = await ingresar(telefonoRosa);
      final (codigo, cuerpo) = await pedir(
        'PUT',
        '/vecinos/rosa',
        token: token,
        cuerpo: {'rol': 'vecino', 'calle': 'Plantamura'},
      );
      expect(codigo, 200);
      expect(cuerpo['rol'], 'vecino');
      expect(cuerpo['calle'], 'Plantamura');
    });

    test('un archivo de datos viejo sin rol se lee con rol vecino', () {
      final carpeta = Directory.systemTemp.createTempSync('barrio_seguro');
      addTearDown(() => carpeta.deleteSync(recursive: true));
      final archivo = File('${carpeta.path}/barrio.json')
        ..writeAsStringSync(
          jsonEncode({
            'ultimo_id': 0,
            'vecinos': {
              'viejo': {
                'id': 'viejo',
                'nombre': 'Vecino Viejo',
                'fecha_nacimiento': '1970-01-01',
              },
              'raro': {
                'id': 'raro',
                'nombre': 'Rol Raro',
                'fecha_nacimiento': '1970-01-01',
                'rol': 'admin',
              },
              'jefa': {
                'id': 'jefa',
                'nombre': 'De la Comisión',
                'fecha_nacimiento': '1970-01-01',
                'rol': 'comision',
              },
            },
            'credenciales': <String, dynamic>{},
            'sesiones': <String, dynamic>{},
            'turnos': <String, dynamic>{},
            'alertas': <dynamic>[],
          }),
        );

      final leido = Almacen.abrir(archivo: archivo, reloj: reloj);

      expect(leido.vecinos['viejo']!['rol'], 'vecino');
      expect(leido.vecinos['raro']!['rol'], 'vecino');
      expect(leido.vecinos['jefa']!['rol'], 'comision');
    });
  });

  group('Rutas de la comisión', () {
    test(
      'un vecino común recibe 403 en cualquier ruta de la comisión',
      () async {
        final token = await ingresar(telefonoRosa);
        for (final metodo in ['GET', 'POST']) {
          final (codigo, cuerpo) = await pedir(
            metodo,
            '/comision/informes/alertas',
            token: token,
            cuerpo: metodo == 'POST' ? <String, dynamic>{} : null,
          );
          expect(codigo, 403, reason: metodo);
          expect(cuerpo, {
            'error': 'Esta opción es solo para la comisión vecinal.',
          });
        }
      },
    );

    test('sin sesión, las rutas de la comisión responden 401', () async {
      final (sinToken, _) = await pedir('GET', '/comision/informes/alertas');
      final (tokenFalso, cuerpo) = await pedir(
        'GET',
        '/comision/informes/alertas',
        token: 'inventado',
      );
      expect(sinToken, 401);
      expect(tokenFalso, 401);
      expect(cuerpo['error'], contains('Ingresá de nuevo'));
    });

    test('un miembro de la comisión pasa el filtro', () async {
      final token = await ingresar(telefonoClara);
      final (codigo, cuerpo) = await pedir(
        'GET',
        '/comision/lo-que-sea',
        token: token,
      );
      expect(codigo, 404);
      expect(cuerpo, {'error': 'Esa dirección no existe.'});
    });

    test(
      'soloComision deja pasar a la comisión y frena al vecino común',
      () async {
        final filtrado = instanciaApi.soloComision(
          (Request _) => Response.ok('pasó'),
        );
        Request pedidoCon(String token) => Request(
          'GET',
          Uri.parse('http://localhost/comision/algo'),
          headers: {'authorization': 'Bearer $token'},
        );

        final respuesta = await filtrado(
          pedidoCon(await ingresar(telefonoClara)),
        );
        expect(respuesta.statusCode, 200);
        expect(await respuesta.readAsString(), 'pasó');

        final tokenRosa = await ingresar(telefonoRosa);
        expect(
          () => filtrado(pedidoCon(tokenRosa)),
          throwsA(
            isA<ErrorDeApi>()
                .having((e) => e.codigo, 'codigo', 403)
                .having(
                  (e) => e.mensaje,
                  'mensaje',
                  'Esta opción es solo para la comisión vecinal.',
                ),
          ),
        );
      },
    );
  });

  group('Alertas', () {
    test('vienen de la más nueva a la más vieja', () async {
      final token = await ingresar(telefonoClara);
      final (codigo, alertas) = await pedir('GET', '/alertas', token: token);
      expect(codigo, 200);
      final fechas = [for (final a in alertas as List) a['creada_en'] as int];
      expect(fechas, [...fechas]..sort((a, b) => b.compareTo(a)));
    });

    test('la alerta nueva queda a nombre de quien tiene la sesión', () async {
      final token = await ingresar(telefonoRosa);
      final (codigo, alerta) = await pedir(
        'POST',
        '/alertas',
        token: token,
        cuerpo: {
          'categoria': 'sos',
          'tipo': 'Pedido de ayuda (SOS)',
          'latitud': -32.876568,
          'longitud': -68.870672,
          // Aunque la app mande otro, cuenta el de la sesión.
          'reportada_por': 'clara',
        },
      );
      expect(codigo, 201);
      expect(alerta['reportada_por'], 'rosa');
      expect(alerta['estado'], 'activa');
      expect(
        alerta['creada_en'],
        DateTime(2026, 10, 1, 12).millisecondsSinceEpoch,
      );
    });

    test('rechaza una categoría o una ubicación inválidas', () async {
      final token = await ingresar(telefonoClara);
      final (sinCategoria, _) = await pedir(
        'POST',
        '/alertas',
        token: token,
        cuerpo: {'categoria': 'ovni', 'tipo': 'x', 'latitud': 0, 'longitud': 0},
      );
      final (sinUbicacion, _) = await pedir(
        'POST',
        '/alertas',
        token: token,
        cuerpo: {'categoria': 'robo', 'tipo': 'x', 'latitud': 'acá'},
      );
      expect(sinCategoria, 400);
      expect(sinUbicacion, 400);
    });

    test('solo quien la reportó puede cerrarla (RF-05)', () async {
      final clara = await ingresar(telefonoClara);
      final rosa = await ingresar(telefonoRosa);

      // a1 la reportó Clara.
      final (ajena, _) = await pedir(
        'PATCH',
        '/alertas/a1',
        token: rosa,
        cuerpo: {'estado': 'resuelta'},
      );
      final (propia, alerta) = await pedir(
        'PATCH',
        '/alertas/a1',
        token: clara,
        cuerpo: {'estado': 'resuelta'},
      );
      expect(ajena, 403);
      expect(propia, 200);
      expect(alerta['estado'], 'resuelta');
    });
  });

  group('Turnos', () {
    test('los vecinos de los turnos no traen el rol', () async {
      final token = await ingresar(telefonoClara);

      List<Map<String, dynamic>> vecinosDe(dynamic turno) => [
        ...(turno['patrulleros'] as List).cast<Map<String, dynamic>>(),
        if (turno['guardia_ventana'] != null)
          turno['guardia_ventana'] as Map<String, dynamic>,
      ];
      void sinRol(dynamic turno) {
        for (final vecino in vecinosDe(turno)) {
          expect(vecino, isNot(contains('rol')), reason: '${vecino['id']}');
        }
      }

      final (codigo, turnos) = await pedir(
        'GET',
        '/turnos?anio=2026&mes=10',
        token: token,
      );
      expect(codigo, 200);
      final delNueve = (turnos as List).firstWhere(
        (t) => t['fecha'] == '2026-10-09',
      );
      expect(delNueve['patrulleros'][0]['id'], 'clara');
      expect(delNueve['guardia_ventana']['id'], 'ernesto');
      turnos.forEach(sinRol);

      final (codigoPut, anotado) = await pedir(
        'PUT',
        '/turnos/2026-10-30/noche/vecinos/clara',
        token: token,
      );
      expect(codigoPut, 200);
      expect(vecinosDe(anotado).map((v) => v['id']), contains('clara'));
      sinRol(anotado);

      final (codigoDelete, sinClara) = await pedir(
        'DELETE',
        '/turnos/2026-10-30/noche/vecinos/clara',
        token: token,
      );
      expect(codigoDelete, 200);
      expect(vecinosDe(sinClara), isNotEmpty);
      sinRol(sinClara);

      // Se sacó de la respuesta, no del vecino guardado.
      final (_, yo) = await pedir('GET', '/vecinos/yo', token: token);
      expect(yo['rol'], 'comision');
    });

    test('devuelve los turnos del mes con los vecinos adentro', () async {
      final token = await ingresar(telefonoClara);
      final (codigo, turnos) = await pedir(
        'GET',
        '/turnos?anio=2026&mes=10',
        token: token,
      );
      expect(codigo, 200);
      final delNueve = (turnos as List).firstWhere(
        (t) => t['fecha'] == '2026-10-09',
      );
      expect(delNueve['patrulleros'][0]['nombre'], 'Clara Medina');
      expect(delNueve['guardia_ventana']['nombre'], 'Ernesto Funes');
    });

    test('no deja tomar un tercer turno en el mes', () async {
      final token = await ingresar(telefonoClara);
      // Clara ya tiene el del 9: este es el segundo.
      final (segundo, _) = await pedir(
        'PUT',
        '/turnos/2026-10-30/noche/vecinos/clara',
        token: token,
      );
      final (tercero, cuerpo) = await pedir(
        'PUT',
        '/turnos/2026-10-31/noche/vecinos/clara',
        token: token,
      );
      expect(segundo, 200);
      expect(tercero, 409);
      expect(cuerpo['error'], contains('máximo'));
    });

    test('un mayor de 70 queda como guardia de ventana', () async {
      // Rosa ya tiene dos turnos en octubre: se anota en noviembre.
      final token = await ingresar(telefonoRosa);
      final (codigo, turno) = await pedir(
        'PUT',
        '/turnos/2026-11-06/noche/vecinos/rosa',
        token: token,
      );
      expect(codigo, 200);
      expect(turno['guardia_ventana']['id'], 'rosa');
      expect(turno['patrulleros'], isEmpty);
    });

    test('la patrulla completa rechaza a un patrullero más', () async {
      final token = await ingresar(telefonoClara);
      final (codigo, cuerpo) = await pedir(
        'PUT',
        '/turnos/2026-10-03/madrugada/vecinos/clara',
        token: token,
      );
      expect(codigo, 409);
      expect(cuerpo['error'], 'La patrulla de este turno ya está completa.');
    });

    test('no se puede anotar a otro vecino', () async {
      final token = await ingresar(telefonoClara);
      final (codigo, _) = await pedir(
        'PUT',
        '/turnos/2026-10-30/noche/vecinos/rosa',
        token: token,
      );
      expect(codigo, 403);
    });

    test('salir libera el lugar', () async {
      final token = await ingresar(telefonoClara);
      final (codigo, turno) = await pedir(
        'DELETE',
        '/turnos/2026-10-09/noche/vecinos/clara',
        token: token,
      );
      expect(codigo, 200);
      expect(
        [for (final p in turno['patrulleros'] as List) p['id']],
        ['sofia'],
      );
    });
  });

  test('los datos sobreviven a reiniciar el servidor', () async {
    final carpeta = Directory.systemTemp.createTempSync('barrio_seguro');
    addTearDown(() => carpeta.deleteSync(recursive: true));
    final archivo = File('${carpeta.path}/barrio.json');

    final primero = Api(
      almacen: Almacen.abrir(archivo: archivo, reloj: reloj),
      reloj: reloj,
      codigoComision: 'SOBERANIA',
    );
    api = primero.handler;
    final token = await ingresar(telefonoClara);
    await pedir(
      'PATCH',
      '/alertas/a1',
      token: token,
      cuerpo: {'estado': 'resuelta'},
    );

    // "Reiniciar": un almacén nuevo que lee el mismo archivo.
    api = Api(
      almacen: Almacen.abrir(archivo: archivo, reloj: reloj),
      reloj: reloj,
      codigoComision: 'SOBERANIA',
    ).handler;
    final (codigo, alertas) = await pedir('GET', '/alertas', token: token);
    expect(codigo, 200, reason: 'la sesión también se guarda');
    final a1 = (alertas as List).firstWhere((a) => a['id'] == 'a1');
    expect(a1['estado'], 'resuelta');
  });

  group('Avisos push', () {
    test('crear una alerta activa envía el aviso push con sus datos', () async {
      final token = await ingresar(telefonoRosa);
      final (codigo, alerta) = await pedir(
        'POST',
        '/alertas',
        token: token,
        cuerpo: {
          'categoria': 'sos',
          'tipo': 'Pedido de ayuda (SOS)',
          'direccion': 'Calle Plantamura',
          'latitud': -32.876568,
          'longitud': -68.870672,
        },
      );

      expect(codigo, 201);
      expect(push.enviadas, hasLength(1));
      expect(push.enviadas.single['id'], alerta['id']);
      expect(push.enviadas.single['reportada_por'], 'rosa');
      expect(push.enviadas.single['estado'], 'activa');
    });

    test(
      'si la alerta ya está resuelta cuando se va a enviar el aviso, no se avisa',
      () async {
        await instanciaApi.notificarAlerta({
          'id': 'a-resuelta',
          'categoria': 'robo',
          'tipo': 'Intento de robo',
          'estado': 'resuelta',
          'reportada_por': 'clara',
        });

        expect(push.enviadas, isEmpty);
      },
    );

    test('si el servicio de push falla, la alerta se crea igual', () async {
      push.falla = true;
      final token = await ingresar(telefonoClara);
      final (codigo, alerta) = await pedir(
        'POST',
        '/alertas',
        token: token,
        cuerpo: {
          'categoria': 'sos',
          'tipo': 'Pedido de ayuda (SOS)',
          'latitud': -32.876568,
          'longitud': -68.870672,
        },
      );

      expect(codigo, 201);
      expect(alerta['estado'], 'activa');
    });

    test(
      'PushServiceFcm envía el mensaje de datos al tópico alertas y descarta las resueltas',
      () async {
        final pedidos = <http.Request>[];
        final servicio = PushServiceFcm.conCliente(
          projectId: 'barrioseguro-462d3',
          cliente: MockClient((pedido) async {
            pedidos.add(pedido);
            return http.Response(
              '{"name": "projects/barrioseguro-462d3/messages/1"}',
              200,
            );
          }),
        );

        await servicio.enviarAlerta({'id': 'a-cerrada', 'estado': 'resuelta'});
        expect(pedidos, isEmpty);

        await servicio.enviarAlerta({
          'id': 'a-activa',
          'categoria': 'sos',
          'tipo': 'Pedido de ayuda (SOS)',
          'direccion': 'Calle Plantamura',
          'creada_en': 1759320000000,
          'estado': 'activa',
          'latitud': -32.876568,
          'longitud': -68.870672,
          'reportada_por': 'rosa',
        });

        expect(pedidos, hasLength(1));
        expect(
          pedidos.single.url.toString(),
          'https://fcm.googleapis.com/v1/projects/barrioseguro-462d3/messages:send',
        );
        final cuerpo = jsonDecode(pedidos.single.body) as Map<String, dynamic>;
        final mensaje = cuerpo['message'] as Map<String, dynamic>;
        expect(mensaje['topic'], 'alertas');
        expect((mensaje['data'] as Map<String, dynamic>)['id'], 'a-activa');
        expect(
          (mensaje['data'] as Map<String, dynamic>)['reportada_por'],
          'rosa',
        );
      },
    );
  });
}
