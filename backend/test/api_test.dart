// Pruebas de la API sin abrir un puerto: se le pasan pedidos (Request) al
// handler directamente y se miran las respuestas.

import 'dart:convert';
import 'dart:io';

import 'package:barrio_seguro_backend/barrio_seguro_backend.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

const telefonoClara = '261 555-0142';
const telefonoRosa = '2615550177';
const clave = 'barrio1234';

void main() {
  late Handler api;
  late Almacen almacen;
  final reloj = RelojFijo(DateTime(2026, 10, 1, 12));

  setUp(() {
    almacen = Almacen.abrir(reloj: reloj);
    api = Api(
      almacen: almacen,
      reloj: reloj,
      codigoComision: 'SOBERANIA',
    ).handler;
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
}
