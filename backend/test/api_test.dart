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

  /// Cada aviso de reapertura: la alerta y la hora de la reapertura.
  final List<(Map<String, dynamic>, DateTime)> reaperturas = [];

  @override
  Future<void> enviarAlerta(Map<String, dynamic> alerta) async {
    if (falla) throw Exception('fallo de FCM');
    if (alerta['estado'] == 'resuelta') return;
    enviadas.add(Map<String, dynamic>.of(alerta));
  }

  @override
  Future<void> enviarReapertura(
    Map<String, dynamic> alerta, {
    required DateTime reabiertaEn,
  }) async {
    if (falla) throw Exception('fallo de FCM');
    if (alerta['estado'] == 'resuelta') return;
    reaperturas.add((Map<String, dynamic>.of(alerta), reabiertaEn));
  }
}

/// Las claves de una alerta en las respuestas de la API y en los avisos
/// push.
const clavesDeUnaAlerta = {
  'id',
  'categoria',
  'tipo',
  'descripcion',
  'direccion',
  'creada_en',
  'estado',
  'latitud',
  'longitud',
  'reportada_por',
  'reportada_por_nombre',
};

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

  group('Guardia normal', () {
    const mensajeSoloMayores =
        'Solo los vecinos de 70 años o más pueden elegir la guardia normal.';
    const mensajeInvalida = 'La opción de guardia normal no es válida.';

    test('ingresar, GET /vecinos/yo y PUT /vecinos/<id> traen '
        'guardia_normal', () async {
      for (final (telefono, id) in [
        (telefonoClara, 'clara'),
        (telefonoRosa, 'rosa'),
      ]) {
        final (codigo, sesion) = await pedir(
          'POST',
          '/sesiones',
          cuerpo: {'usuario': telefono, 'clave': clave},
        );
        expect(codigo, 200);
        expect(sesion['vecino']['guardia_normal'], isFalse, reason: id);
        final token = sesion['token'] as String;

        final (_, yo) = await pedir('GET', '/vecinos/yo', token: token);
        expect(yo['guardia_normal'], isFalse, reason: id);

        final (codigoPut, actualizado) = await pedir(
          'PUT',
          '/vecinos/$id',
          token: token,
          cuerpo: {'cuadra': 'Cuadra 1'},
        );
        expect(codigoPut, 200);
        expect(actualizado['guardia_normal'], isFalse, reason: id);
      }
      // Todos los vecinos de ejemplo arrancan con la opción desactivada.
      for (final vecino in almacen.vecinos.values) {
        expect(vecino['guardia_normal'], isFalse, reason: '${vecino['id']}');
      }
    });

    test('registrarse arranca sin guardia normal aunque el pedido la '
        'mande', () async {
      final (codigo, cuerpo) = await pedir(
        'POST',
        '/vecinos',
        cuerpo: {
          'nombre': 'Nuevo Mayor',
          'fecha_nacimiento': '1940-01-01',
          'telefono': '261 555-0888',
          'codigo_comision': 'SOBERANIA',
          'clave': 'segura123',
          'guardia_normal': true,
        },
      );
      expect(codigo, 201);
      expect(cuerpo['vecino']['guardia_normal'], isFalse);
      final (_, yo) = await pedir(
        'GET',
        '/vecinos/yo',
        token: cuerpo['token'] as String,
      );
      expect(yo['guardia_normal'], isFalse);
    });

    test('Rosa activa la guardia normal y queda guardada', () async {
      final token = await ingresar(telefonoRosa);
      final (codigo, cuerpo) = await pedir(
        'PUT',
        '/vecinos/rosa',
        token: token,
        cuerpo: {'guardia_normal': true},
      );
      expect(codigo, 200);
      expect(cuerpo['guardia_normal'], isTrue);

      final (_, yo) = await pedir('GET', '/vecinos/yo', token: token);
      expect(yo['guardia_normal'], isTrue);

      final (codigoCalle, conCalle) = await pedir(
        'PUT',
        '/vecinos/rosa',
        token: token,
        cuerpo: {'calle': 'Democracia'},
      );
      expect(codigoCalle, 200);
      expect(conCalle['calle'], 'Democracia');
      expect(conCalle['guardia_normal'], isTrue);

      final (_, desactivada) = await pedir(
        'PUT',
        '/vecinos/rosa',
        token: token,
        cuerpo: {'guardia_normal': false},
      );
      expect(desactivada['guardia_normal'], isFalse);
    });

    test('un menor no puede activarla: 409', () async {
      final token = await ingresar(telefonoClara);
      final (codigo, cuerpo) = await pedir(
        'PUT',
        '/vecinos/clara',
        token: token,
        cuerpo: {'guardia_normal': true},
      );
      expect(codigo, 409);
      expect(cuerpo, {'error': mensajeSoloMayores});
    });

    test('un menor puede mandar false', () async {
      final token = await ingresar(telefonoClara);
      final (codigo, cuerpo) = await pedir(
        'PUT',
        '/vecinos/clara',
        token: token,
        cuerpo: {'guardia_normal': false},
      );
      expect(codigo, 200);
      expect(cuerpo['guardia_normal'], isFalse);
    });

    test('un valor que no es booleano: 400', () async {
      final token = await ingresar(telefonoRosa);
      for (final valor in <Object?>['si', 1, null]) {
        final (codigo, cuerpo) = await pedir(
          'PUT',
          '/vecinos/rosa',
          token: token,
          cuerpo: {'guardia_normal': valor},
        );
        expect(codigo, 400, reason: '$valor');
        expect(cuerpo, {'error': mensajeInvalida}, reason: '$valor');
      }
    });

    test('la guardia normal rechazada no cambia ningún dato', () async {
      final tokenClara = await ingresar(telefonoClara);
      final (_, claraAntes) = await pedir(
        'GET',
        '/vecinos/yo',
        token: tokenClara,
      );
      final (codigoClara, _) = await pedir(
        'PUT',
        '/vecinos/clara',
        token: tokenClara,
        cuerpo: {
          'nombre': 'Otro Nombre',
          'telefono': '261 555-0777',
          'guardia_normal': true,
        },
      );
      expect(codigoClara, 409);
      final (_, claraDespues) = await pedir(
        'GET',
        '/vecinos/yo',
        token: tokenClara,
      );
      expect(claraDespues, claraAntes);
      // Tampoco cambió el teléfono con el que ingresa.
      await ingresar(telefonoClara);

      final tokenRosa = await ingresar(telefonoRosa);
      final (_, rosaAntes) = await pedir(
        'GET',
        '/vecinos/yo',
        token: tokenRosa,
      );
      final (codigoRosa, _) = await pedir(
        'PUT',
        '/vecinos/rosa',
        token: tokenRosa,
        cuerpo: {'calle': 'Otra calle', 'guardia_normal': 'si'},
      );
      expect(codigoRosa, 400);
      final (_, rosaDespues) = await pedir(
        'GET',
        '/vecinos/yo',
        token: tokenRosa,
      );
      expect(rosaDespues, rosaAntes);
    });

    test('un archivo de datos viejo sin guardia_normal se lee con false', () {
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
                'fecha_nacimiento': '1950-01-01',
                'rol': 'vecino',
              },
              'raro': {
                'id': 'raro',
                'nombre': 'Valor Raro',
                'fecha_nacimiento': '1950-01-01',
                'rol': 'vecino',
                'guardia_normal': 'si',
              },
              'activa': {
                'id': 'activa',
                'nombre': 'Con la Opción',
                'fecha_nacimiento': '1950-01-01',
                'rol': 'vecino',
                'guardia_normal': true,
              },
            },
            'credenciales': <String, dynamic>{},
            'sesiones': <String, dynamic>{},
            'turnos': <String, dynamic>{},
            'alertas': <dynamic>[],
          }),
        );

      final leido = Almacen.abrir(archivo: archivo, reloj: reloj);

      expect(leido.vecinos['viejo']!['guardia_normal'], isFalse);
      expect(leido.vecinos['raro']!['guardia_normal'], isFalse);
      expect(leido.vecinos['activa']!['guardia_normal'], isTrue);
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
          // El título que manda el botón SOS desde la feature 17.
          'tipo': 'Intento de robo',
          'latitud': -32.876568,
          'longitud': -68.870672,
          // Aunque la app mande otro, cuenta el de la sesión.
          'reportada_por': 'clara',
        },
      );
      expect(codigo, 201);
      expect(alerta['reportada_por'], 'rosa');
      expect(alerta['estado'], 'activa');
      expect(alerta['categoria'], 'sos');
      expect(alerta['tipo'], 'Intento de robo');
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

    test(
      'rechaza una alerta nueva de arrebato con "Elegí qué tipo de alerta es."',
      () async {
        final token = await ingresar(telefonoClara);
        final antes = almacen.alertas.length;
        final (codigo, cuerpo) = await pedir(
          'POST',
          '/alertas',
          token: token,
          cuerpo: {
            'categoria': 'arrebato',
            'tipo': 'Arrebato',
            'descripcion': '',
            'direccion': '',
            'latitud': -32.876568,
            'longitud': -68.870672,
          },
        );
        expect(codigo, 400);
        expect(cuerpo, {'error': 'Elegí qué tipo de alerta es.'});
        expect(almacen.alertas, hasLength(antes));
        expect(push.enviadas, isEmpty);
      },
    );

    test(
      'rechaza un título vacío, un título de 61 letras, una descripción de 501 '
      'y una dirección de 121 con los mensajes de la app',
      () async {
        final token = await ingresar(telefonoClara);
        final antes = almacen.alertas.length;
        Future<(int, dynamic)> crear(Map<String, Object> cambios) => pedir(
          'POST',
          '/alertas',
          token: token,
          cuerpo: {
            'categoria': 'robo',
            'tipo': 'Robo',
            'descripcion': '',
            'direccion': '',
            'latitud': -32.876568,
            'longitud': -68.870672,
            ...cambios,
          },
        );

        for (final (cambios, mensaje) in [
          ({'tipo': '   '}, 'Escribí un título para la alerta.'),
          (
            {'tipo': 'a' * 61},
            'Acortá el título: puede tener hasta 60 letras.',
          ),
          (
            {'descripcion': 'a' * 501},
            'Acortá la descripción: puede tener hasta 500 letras.',
          ),
          (
            {'direccion': 'a' * 121},
            'Acortá la dirección: puede tener hasta 120 letras.',
          ),
        ]) {
          final (codigo, cuerpo) = await crear(cambios);
          expect(codigo, 400, reason: '$cambios');
          expect(cuerpo, {'error': mensaje});
        }
        expect(almacen.alertas, hasLength(antes));

        // En el límite sí pasa.
        final (codigo, _) = await crear({
          'tipo': 'a' * 60,
          'descripcion': 'a' * 500,
          'direccion': 'a' * 120,
        });
        expect(codigo, 201);
      },
    );

    test('una alerta nueva de actividad sospechosa queda activa', () async {
      final token = await ingresar(telefonoClara);
      final (codigo, alerta) = await pedir(
        'POST',
        '/alertas',
        token: token,
        cuerpo: {
          'categoria': 'actividad_sospechosa',
          'tipo': '  Actividad sospechosa  ',
          'descripcion': '',
          'direccion': 'Cabildo de Mendoza y Ascasubi',
          'latitud': -32.876568,
          'longitud': -68.870672,
        },
      );
      expect(codigo, 201);
      expect(alerta['estado'], 'activa');
      expect(alerta['categoria'], 'actividad_sospechosa');
      expect(alerta['tipo'], 'Actividad sospechosa');
      expect(almacen.alertas.first['id'], alerta['id']);
      expect(almacen.alertas.first['estado'], 'activa');
    });

    test(
      'una alerta de arrebato guardada se sigue leyendo en GET /alertas',
      () async {
        almacen.alertas.insert(0, {
          'id': 'vieja',
          'categoria': 'arrebato',
          'tipo': 'Arrebato',
          'descripcion': 'Le sacaron el celular.',
          'direccion': 'Parada de colectivo',
          'creada_en': DateTime(2026, 9, 30, 10).millisecondsSinceEpoch,
          'estado': 'activa',
          'latitud': -32.879792,
          'longitud': -68.868027,
          'reportada_por': 'clara',
        });
        final token = await ingresar(telefonoClara);

        final (codigo, alertas) = await pedir('GET', '/alertas', token: token);

        expect(codigo, 200);
        final vieja = (alertas as List).firstWhere((a) => a['id'] == 'vieja');
        expect(vieja['categoria'], 'arrebato');
        expect(vieja['tipo'], 'Arrebato');

        // También cambia de estado como cualquier otra.
        final (cambio, resuelta) = await pedir(
          'PATCH',
          '/alertas/vieja',
          token: token,
          cuerpo: {'estado': 'resuelta'},
        );
        expect(cambio, 200);
        expect(resuelta['categoria'], 'arrebato');
      },
    );

    test('los datos de ejemplo no tienen alertas de arrebato y a4 es "Robo de '
        'celular"', () {
      expect(
        almacen.alertas.where((a) => a['categoria'] == 'arrebato'),
        isEmpty,
      );
      final a4 = almacen.alertas.firstWhere((a) => a['id'] == 'a4');
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
    });

    String estadoEnElAlmacen(String id) =>
        almacen.alertas.firstWhere((a) => a['id'] == id)['estado'] as String;

    test('quien la reportó cambia el estado', () async {
      final rosa = await ingresar(telefonoRosa);
      final (creada, alerta) = await pedir(
        'POST',
        '/alertas',
        token: rosa,
        cuerpo: {
          'categoria': 'robo',
          'tipo': 'Robo',
          'latitud': -32.876568,
          'longitud': -68.870672,
        },
      );
      expect(creada, 201);
      final id = alerta['id'] as String;

      final (codigo, cambiada) = await pedir(
        'PATCH',
        '/alertas/$id',
        token: rosa,
        cuerpo: {'estado': 'en_atencion'},
      );

      expect(codigo, 200);
      expect(cambiada['id'], id);
      expect(cambiada['estado'], 'en_atencion');
      expect(cambiada['reportada_por_nombre'], 'Rosa');
      expect(estadoEnElAlmacen(id), 'en_atencion');
    });

    test('la comisión cambia el estado de una alerta ajena', () async {
      final clara = await ingresar(telefonoClara);

      // a2 la reportó Martín; Clara es de la comisión.
      final (codigo, alerta) = await pedir(
        'PATCH',
        '/alertas/a2',
        token: clara,
        cuerpo: {'estado': 'en_atencion'},
      );
      expect(codigo, 200);
      expect(alerta['estado'], 'en_atencion');
      expect(alerta['reportada_por'], 'martin');
      expect(estadoEnElAlmacen('a2'), 'en_atencion');

      final (otro, resuelta) = await pedir(
        'PATCH',
        '/alertas/a3',
        token: clara,
        cuerpo: {'estado': 'resuelta'},
      );
      expect(otro, 200);
      expect(resuelta['estado'], 'resuelta');
      expect(estadoEnElAlmacen('a3'), 'resuelta');
    });

    test(
      'un vecino común no puede cambiar el estado de una alerta ajena',
      () async {
        final rosa = await ingresar(telefonoRosa);

        // a1 la reportó Clara; Rosa es vecina común.
        for (final estado in ['resuelta', 'en_atencion']) {
          final (codigo, cuerpo) = await pedir(
            'PATCH',
            '/alertas/a1',
            token: rosa,
            cuerpo: {'estado': estado},
          );
          expect(codigo, 403);
          expect(
            cuerpo['error'],
            'Solo quien reportó la alerta o la comisión vecinal pueden cambiar '
            'su estado.',
          );
          expect(cuerpo['error'], ReglasAlertas.mensajeSinPermisoEstado);
        }
        expect(estadoEnElAlmacen('a1'), 'activa');
      },
    );

    test('se puede reabrir una alerta resuelta', () async {
      final clara = await ingresar(telefonoClara);

      // a4 es de Clara (autora); a5 es de Rosa (Clara entra por comisión).
      final (codigo, alerta) = await pedir(
        'PATCH',
        '/alertas/a4',
        token: clara,
        cuerpo: {'estado': 'activa'},
      );
      expect(codigo, 200);
      expect(alerta['estado'], 'activa');
      expect(estadoEnElAlmacen('a4'), 'activa');

      final (otro, otra) = await pedir(
        'PATCH',
        '/alertas/a5',
        token: clara,
        cuerpo: {'estado': 'en_atencion'},
      );
      expect(otro, 200);
      expect(otra['estado'], 'en_atencion');
      expect(estadoEnElAlmacen('a5'), 'en_atencion');
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

    /// Rosa cambia su guardia normal a [activa] y devuelve su token.
    Future<String> rosaConGuardiaNormal({
      required bool activa,
      String? token,
    }) async {
      final propio = token ?? await ingresar(telefonoRosa);
      final (codigo, cuerpo) = await pedir(
        'PUT',
        '/vecinos/rosa',
        token: propio,
        cuerpo: {'guardia_normal': activa},
      );
      expect(codigo, 200);
      expect(cuerpo['guardia_normal'], activa);
      return propio;
    }

    List<Object?> idsDe(dynamic vecinos) => [
      for (final v in vecinos as List) v['id'],
    ];

    test('un mayor con guardia normal se anota en la patrulla', () async {
      final token = await rosaConGuardiaNormal(activa: true);
      final (codigo, turno) = await pedir(
        'PUT',
        '/turnos/2026-11-06/noche/vecinos/rosa',
        token: token,
      );
      expect(codigo, 200);
      expect(idsDe(turno['patrulleros']), ['rosa']);
      expect(turno['guardia_ventana'], isNull);
    });

    test('un mayor que desactiva la guardia normal vuelve a ser guardia de '
        'ventana', () async {
      final token = await rosaConGuardiaNormal(activa: true);
      await rosaConGuardiaNormal(activa: false, token: token);
      final (codigo, turno) = await pedir(
        'PUT',
        '/turnos/2026-11-20/noche/vecinos/rosa',
        token: token,
      );
      expect(codigo, 200);
      expect(turno['guardia_ventana']['id'], 'rosa');
      expect(turno['patrulleros'], isEmpty);
    });

    test('con guardia normal, la patrulla completa responde 409 aunque la '
        'guardia esté libre', () async {
      for (final (i, telefono) in ['261 555-0811', '261 555-0822'].indexed) {
        final (codigo, sesion) = await pedir(
          'POST',
          '/vecinos',
          cuerpo: {
            'nombre': 'Patrullero $i',
            'fecha_nacimiento': '1990-01-01',
            'telefono': telefono,
            'codigo_comision': 'SOBERANIA',
            'clave': 'segura123',
          },
        );
        expect(codigo, 201);
        final id = sesion['vecino']['id'];
        final (codigoTurno, _) = await pedir(
          'PUT',
          '/turnos/2026-11-13/noche/vecinos/$id',
          token: sesion['token'] as String,
        );
        expect(codigoTurno, 200);
      }

      final token = await rosaConGuardiaNormal(activa: true);
      final (codigo, cuerpo) = await pedir(
        'PUT',
        '/turnos/2026-11-13/noche/vecinos/rosa',
        token: token,
      );
      expect(codigo, 409);
      expect(cuerpo, {'error': 'La patrulla de este turno ya está completa.'});
    });

    test('con guardia normal sigue el máximo de 2 por mes', () async {
      // Rosa ya tiene el 2/10 y el 17/10. El 30/10 tiene lugar en la
      // patrulla.
      final token = await rosaConGuardiaNormal(activa: true);
      final (codigo, cuerpo) = await pedir(
        'PUT',
        '/turnos/2026-10-30/noche/vecinos/rosa',
        token: token,
      );
      expect(codigo, 409);
      expect(cuerpo, {
        'error': 'Ya tenés 2 turnos este mes, que es el máximo permitido.',
      });
    });

    test('cambiar la guardia normal no mueve los turnos ya tomados', () async {
      Future<Map<String, dynamic>> turnoDe(
        String token,
        int mes,
        String fecha,
      ) async {
        final (codigo, turnos) = await pedir(
          'GET',
          '/turnos?anio=2026&mes=$mes',
          token: token,
        );
        expect(codigo, 200);
        return (turnos as List).cast<Map<String, dynamic>>().firstWhere(
          (t) => t['fecha'] == fecha && t['franja'] == 'noche',
        );
      }

      final token = await rosaConGuardiaNormal(activa: true);
      final octubre = await turnoDe(token, 10, '2026-10-02');
      expect(octubre['guardia_ventana']['id'], 'rosa');
      expect(idsDe(octubre['patrulleros']), ['jorge', 'ana']);

      final (codigo, _) = await pedir(
        'PUT',
        '/turnos/2026-11-06/noche/vecinos/rosa',
        token: token,
      );
      expect(codigo, 200);
      await rosaConGuardiaNormal(activa: false, token: token);

      final noviembre = await turnoDe(token, 11, '2026-11-06');
      expect(idsDe(noviembre['patrulleros']), ['rosa']);
      expect(noviembre['guardia_ventana'], isNull);
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

  group('Avisos push: reapertura', () {
    Future<int> cambiar(String token, String id, String estado) async =>
        (await pedir(
          'PATCH',
          '/alertas/$id',
          token: token,
          cuerpo: {'estado': estado},
        )).$1;

    test(
      'reabrir una alerta resuelta a activa envía el aviso de reapertura',
      () async {
        final clara = await ingresar(telefonoClara);

        expect(await cambiar(clara, 'a4', 'activa'), 200);

        final (alerta, reabiertaEn) = push.reaperturas.single;
        expect(alerta['id'], 'a4');
        expect(alerta['estado'], 'activa');
        expect(alerta['reportada_por_nombre'], 'Clara');
        expect(reabiertaEn, DateTime(2026, 10, 1, 12));
        // No es el aviso de una alerta nueva.
        expect(push.enviadas, isEmpty);
      },
    );

    test('reabrir a en_atencion también lo envía', () async {
      final clara = await ingresar(telefonoClara);

      // a5 es de Rosa: Clara la reabre por ser de la comisión.
      expect(await cambiar(clara, 'a5', 'en_atencion'), 200);

      final (alerta, _) = push.reaperturas.single;
      expect(alerta['id'], 'a5');
      expect(alerta['estado'], 'en_atencion');
      expect(alerta['reportada_por_nombre'], 'Rosa');
    });

    test('pasar entre activa y en_atencion no envía nada', () async {
      final clara = await ingresar(telefonoClara);

      expect(await cambiar(clara, 'a1', 'en_atencion'), 200);
      expect(await cambiar(clara, 'a1', 'activa'), 200);

      expect(push.reaperturas, isEmpty);
      expect(push.enviadas, isEmpty);
    });

    test('pasar a resuelta no envía nada', () async {
      final clara = await ingresar(telefonoClara);

      expect(await cambiar(clara, 'a1', 'resuelta'), 200);
      expect(await cambiar(clara, 'a2', 'resuelta'), 200);

      expect(push.reaperturas, isEmpty);
      expect(push.enviadas, isEmpty);
    });

    test('elegir el mismo estado no envía nada', () async {
      final clara = await ingresar(telefonoClara);

      expect(await cambiar(clara, 'a4', 'resuelta'), 200);
      expect(await cambiar(clara, 'a1', 'activa'), 200);

      expect(push.reaperturas, isEmpty);
      expect(push.enviadas, isEmpty);
    });

    test('un pedido rechazado no envía nada', () async {
      final rosa = await ingresar(telefonoRosa);
      final clara = await ingresar(telefonoClara);

      // 401 sin token.
      final (sinToken, _) = await pedir(
        'PATCH',
        '/alertas/a4',
        cuerpo: {'estado': 'activa'},
      );
      expect(sinToken, 401);
      // 403: a4 es de Clara y Rosa es vecina común.
      expect(await cambiar(rosa, 'a4', 'activa'), 403);
      // 400: un estado que no existe.
      expect(await cambiar(clara, 'a4', 'reabierta'), 400);
      // 404: una alerta que no existe.
      expect(await cambiar(clara, 'no-existe', 'activa'), 404);

      expect(push.reaperturas, isEmpty);
      expect(push.enviadas, isEmpty);
      expect(
        almacen.alertas.firstWhere((a) => a['id'] == 'a4')['estado'],
        'resuelta',
      );
    });

    test(
      'si el push falla al reabrir, el estado se guarda y responde 200',
      () async {
        push.falla = true;
        final clara = await ingresar(telefonoClara);

        final (codigo, alerta) = await pedir(
          'PATCH',
          '/alertas/a4',
          token: clara,
          cuerpo: {'estado': 'activa'},
        );

        expect(codigo, 200);
        expect(alerta['estado'], 'activa');
        expect(
          almacen.alertas.firstWhere((a) => a['id'] == 'a4')['estado'],
          'activa',
        );
      },
    );

    test('el aviso de reapertura solo trae las claves de la alerta', () async {
      final clara = await ingresar(telefonoClara);

      expect(await cambiar(clara, 'a5', 'activa'), 200);

      expect(push.reaperturas.single.$1.keys.toSet(), clavesDeUnaAlerta);
    });

    test('PushServiceFcm.enviarReapertura manda al tópico alertas con aviso '
        '"reabierta" y reabierta_en, y descarta las resueltas', () async {
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
      final alerta = {
        'id': 'a4',
        'categoria': 'robo',
        'tipo': 'Robo de celular',
        'descripcion': 'En la parada',
        'direccion': 'Parada de colectivo',
        'creada_en': 1759320000000,
        'estado': 'activa',
        'latitud': -32.879792,
        'longitud': -68.868027,
        'reportada_por': 'clara',
        'reportada_por_nombre': 'Clara',
      };
      final reabiertaEn = DateTime(2026, 10, 1, 12);

      await servicio.enviarReapertura({
        ...alerta,
        'estado': 'resuelta',
      }, reabiertaEn: reabiertaEn);
      expect(pedidos, isEmpty);

      await servicio.enviarReapertura(alerta, reabiertaEn: reabiertaEn);

      expect(pedidos, hasLength(1));
      expect(
        pedidos.single.url.toString(),
        'https://fcm.googleapis.com/v1/projects/barrioseguro-462d3/messages:send',
      );
      final mensaje =
          (jsonDecode(pedidos.single.body) as Map<String, dynamic>)['message']
              as Map<String, dynamic>;
      expect(mensaje['topic'], 'alertas');
      expect(mensaje['android'], {'priority': 'HIGH'});
      final datos = mensaje['data'] as Map<String, dynamic>;
      expect(datos.keys.toSet(), {
        ...clavesDeUnaAlerta,
        'aviso',
        'reabierta_en',
      });
      expect(datos.values, everyElement(isA<String>()));
      expect(datos['aviso'], 'reabierta');
      expect(datos['aviso'], PushServiceFcm.avisoReabierta);
      expect(datos['reabierta_en'], '${reabiertaEn.millisecondsSinceEpoch}');
      expect(datos['estado'], 'activa');
      expect(datos['creada_en'], '1759320000000');

      // El aviso de una alerta nueva sigue sin "aviso".
      await servicio.enviarAlerta(alerta);
      final nueva =
          ((jsonDecode(pedidos.last.body) as Map<String, dynamic>)['message']
                  as Map<String, dynamic>)['data']
              as Map<String, dynamic>;
      expect(nueva.keys.toSet(), clavesDeUnaAlerta);
      expect(nueva, isNot(contains('aviso')));
    });
  });

  group('Salud', () {
    test('GET /salud devuelve estado ok y la hora del servidor', () async {
      // Sin token, como siempre.
      final (codigo, cuerpo) = await pedir('GET', '/salud');
      expect(codigo, 200);
      expect(cuerpo, {
        'estado': 'ok',
        'ahora': DateTime(2026, 10, 1, 12).millisecondsSinceEpoch,
      });
    });
  });

  group('Nombre de quien reportó', () {
    Future<Map<String, dynamic>> crear(String token) async {
      final (codigo, alerta) = await pedir(
        'POST',
        '/alertas',
        token: token,
        cuerpo: {
          'categoria': 'robo',
          'tipo': 'Robo',
          'descripcion': 'Prueba',
          'direccion': 'Calle Plantamura',
          'latitud': -32.876568,
          'longitud': -68.870672,
        },
      );
      expect(codigo, 201);
      return alerta as Map<String, dynamic>;
    }

    test('las alertas traen el primer nombre de quien las reportó', () async {
      final clara = await ingresar(telefonoClara);
      final rosa = await ingresar(telefonoRosa);

      // GET /alertas
      final (codigo, alertas) = await pedir('GET', '/alertas', token: clara);
      expect(codigo, 200);
      final porId = {for (final a in alertas as List) a['id']: a};
      expect(porId['a1']['reportada_por_nombre'], 'Clara');
      expect(porId['a2']['reportada_por_nombre'], 'Martín');
      expect(porId['a3']['reportada_por_nombre'], 'Pedro');

      // POST /alertas
      final nueva = await crear(rosa);
      expect(nueva['reportada_por_nombre'], 'Rosa');

      // PATCH /alertas/<id>
      final (cambio, cerrada) = await pedir(
        'PATCH',
        '/alertas/a1',
        token: clara,
        cuerpo: {'estado': 'resuelta'},
      );
      expect(cambio, 200);
      expect(cerrada['reportada_por_nombre'], 'Clara');
    });

    test('si el vecino ya no existe, el nombre viene vacío', () async {
      final clara = await ingresar(telefonoClara);
      almacen.alertas.first['reportada_por'] = 'nadie';
      final (_, alertas) = await pedir('GET', '/alertas', token: clara);
      final huerfana = (alertas as List).firstWhere(
        (a) => a['reportada_por'] == 'nadie',
      );
      expect(huerfana['reportada_por_nombre'], '');
    });

    test('el push de una alerta nueva trae reportada_por_nombre', () async {
      await crear(await ingresar(telefonoRosa));
      expect(push.enviadas.single['reportada_por_nombre'], 'Rosa');
    });

    test(
      'ni la alerta ni el push traen otros datos de quien reportó',
      () async {
        final clara = await ingresar(telefonoClara);
        final nueva = await crear(clara);
        expect(nueva.keys.toSet(), clavesDeUnaAlerta);
        expect(push.enviadas.single.keys.toSet(), clavesDeUnaAlerta);

        final (_, alertas) = await pedir('GET', '/alertas', token: clara);
        for (final alerta in alertas as List) {
          expect(
            (alerta as Map<String, dynamic>).keys.toSet(),
            clavesDeUnaAlerta,
            reason: alerta['id'] as String,
          );
        }
        final (_, cerrada) = await pedir(
          'PATCH',
          '/alertas/${nueva['id']}',
          token: clara,
          cuerpo: {'estado': 'resuelta'},
        );
        expect(
          (cerrada as Map<String, dynamic>).keys.toSet(),
          clavesDeUnaAlerta,
        );
      },
    );

    test('reportada_por_nombre no se guarda en el almacén', () async {
      final clara = await ingresar(telefonoClara);
      await crear(clara);
      await pedir('GET', '/alertas', token: clara);
      await pedir(
        'PATCH',
        '/alertas/a1',
        token: clara,
        cuerpo: {'estado': 'resuelta'},
      );

      for (final alerta in almacen.alertas) {
        expect(alerta.containsKey('reportada_por_nombre'), isFalse);
      }

      // Un cambio de nombre se ve en la próxima lectura.
      almacen.vecinos['clara']!['nombre'] = 'Clarita Medina';
      final (_, alertas) = await pedir('GET', '/alertas', token: clara);
      final a1 = (alertas as List).firstWhere((a) => a['id'] == 'a1');
      expect(a1['reportada_por_nombre'], 'Clarita');
    });
  });
}
