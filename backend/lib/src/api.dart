import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'almacen.dart';
import 'error_de_api.dart';
import 'push_service.dart';
import 'reglas.dart';
import 'reloj.dart';

/// La API REST de Barrio Seguro. Recibe y devuelve JSON con los mismos
/// nombres de campo que usa la app (snake_case).
///
/// Todas las rutas, salvo `/salud`, `/sesiones` (ingresar) y `/vecinos`
/// (registrarse), piden el encabezado `Authorization: Bearer <token>`. Las
/// rutas bajo `/comision/` son solo para los miembros de la comisión.
class Api {
  Api({
    required this._almacen,
    required this._reloj,
    required this._codigoComision,
    this._push = const PushServiceNinguno(),
  });

  final Almacen _almacen;
  final Reloj _reloj;

  /// Código que la comisión vecinal les da a los vecinos para registrarse.
  final String _codigoComision;
  final PushService _push;

  static const _estados = {'activa', 'en_atencion', 'resuelta'};

  static const mensajeRolFijo = 'El rol no se puede cambiar desde la app.';
  static const mensajeSoloComision =
      'Esta opción es solo para la comisión vecinal.';

  /// El handler completo: rutas más el manejo de errores.
  Handler get handler =>
      const Pipeline().addMiddleware(_manejarErrores).addHandler(_rutas.call);

  Router get _rutas => Router()
    // La hora del servidor sirve para que la app mida el desfase de su
    // reloj (avisos tardíos).
    ..get(
      '/salud',
      (Request _) => _json(200, {
        'estado': 'ok',
        'ahora': _reloj.ahora().millisecondsSinceEpoch,
      }),
    )
    ..post('/sesiones', _ingresar)
    ..delete('/sesiones', _cerrarSesion)
    ..post('/vecinos', _registrar)
    ..get('/vecinos/yo', _yo)
    ..put('/vecinos/<id>', _actualizarVecino)
    ..get('/alertas', _alertas)
    ..post('/alertas', _crearAlerta)
    ..patch('/alertas/<id>', _cambiarEstado)
    ..get('/turnos', _turnos)
    ..put('/turnos/<fecha>/<franja>/vecinos/<vecinoId>', _anotarse)
    ..delete('/turnos/<fecha>/<franja>/vecinos/<vecinoId>', _salir)
    // Antes del comodín: todo lo que empieza con /comision/ pasa por el
    // filtro, exista o no la ruta.
    ..mount(
      '/comision/',
      const Pipeline()
          .addMiddleware(soloComision)
          .addHandler(_rutasDeLaComision.call),
    )
    ..all('/<_|.*>', (Request _) {
      throw const ErrorDeApi.noExiste('Esa dirección no existe.');
    });

  // -------------------------------------------------------------------------
  // Sesiones y vecinos
  // -------------------------------------------------------------------------

  Future<Response> _ingresar(Request pedido) async {
    final datos = await _cuerpo(pedido);
    final id = _almacen.verificar(
      _texto(datos, 'usuario'),
      _texto(datos, 'clave'),
    );
    if (id == null) {
      throw const ErrorDeApi(
        401,
        'El teléfono o la contraseña no son correctos.',
      );
    }
    return _json(200, _sesion(id));
  }

  Response _cerrarSesion(Request pedido) {
    _vecinoDe(pedido);
    _almacen.cerrarSesion(_token(pedido)!);
    return Response(204);
  }

  Future<Response> _registrar(Request pedido) async {
    final datos = await _cuerpo(pedido);
    final nombre = _texto(datos, 'nombre').trim();
    final telefono = _texto(datos, 'telefono').trim();
    final clave = _texto(datos, 'clave');
    final nacimiento = DateTime.tryParse(_texto(datos, 'fecha_nacimiento'));
    final hoy = _reloj.ahora();

    if (_texto(datos, 'codigo_comision').trim().toUpperCase() !=
        _codigoComision.toUpperCase()) {
      throw const ErrorDeApi.noPermitido(
        'El código de la comisión vecinal no es correcto. Pediselo a la comisión.',
      );
    }
    if (nombre.isEmpty) {
      throw const ErrorDeApi.datosInvalidos('Ingresá tu nombre.');
    }
    if (nacimiento == null ||
        nacimiento.isAfter(hoy) ||
        nacimiento.year < 1900) {
      throw const ErrorDeApi.datosInvalidos(
        'La fecha de nacimiento no es válida.',
      );
    }
    if (Almacen.normalizarTelefono(telefono).length < 8) {
      throw const ErrorDeApi.datosInvalidos('Ingresá un teléfono válido.');
    }
    if (clave.length < 6) {
      throw const ErrorDeApi.datosInvalidos(
        'La contraseña tiene que tener al menos 6 caracteres.',
      );
    }
    if (_almacen.telefonoRegistrado(telefono)) {
      throw const ErrorDeApi.conflicto('Ya hay una cuenta con ese teléfono.');
    }

    final id = _almacen.nuevoId('vecino');
    _almacen.vecinos[id] = {
      'id': id,
      'nombre': nombre,
      'fecha_nacimiento': _soloFecha(nacimiento),
      'telefono': telefono,
      'calle': _texto(datos, 'calle', opcional: true).trim(),
      'cuadra': _texto(datos, 'cuadra', opcional: true).trim(),
      'vecino_desde': _soloFecha(hoy),
      // Quien se registra es siempre vecino común, mande lo que mande.
      'rol': Roles.vecino,
    };
    _almacen.guardarCredenciales(id, telefono, clave);
    return _json(201, _sesion(id));
  }

  Response _yo(Request pedido) =>
      _json(200, _almacen.vecinos[_vecinoDe(pedido)]!);

  Future<Response> _actualizarVecino(Request pedido, String id) async {
    if (_vecinoDe(pedido) != id) {
      throw const ErrorDeApi.noPermitido(
        'Solo podés cambiar tus propios datos.',
      );
    }
    final datos = await _cuerpo(pedido);
    // El rol no se cambia desde la app: se rechaza antes de tocar nada.
    if (datos.containsKey('rol') &&
        datos['rol'] != _almacen.vecinos[id]!['rol']) {
      throw const ErrorDeApi.noPermitido(mensajeRolFijo);
    }
    // El id, la fecha de nacimiento, la antigüedad y el rol no se cambian.
    final vecino = {
      ..._almacen.vecinos[id]!,
      for (final campo in ['nombre', 'telefono', 'calle', 'cuadra'])
        if (datos[campo] is String) campo: (datos[campo] as String).trim(),
    };
    if ((vecino['nombre'] as String).isEmpty) {
      throw const ErrorDeApi.datosInvalidos('Ingresá tu nombre.');
    }
    final telefono = vecino['telefono'] as String? ?? '';
    if (telefono != _almacen.vecinos[id]!['telefono']) {
      if (Almacen.normalizarTelefono(telefono).length < 8) {
        throw const ErrorDeApi.datosInvalidos('Ingresá un teléfono válido.');
      }
      if (_almacen.telefonoRegistrado(telefono, salvo: id)) {
        throw const ErrorDeApi.conflicto('Ya hay una cuenta con ese teléfono.');
      }
      // Con el teléfono nuevo se ingresa a partir de ahora.
      _almacen.cambiarTelefono(id, telefono);
    }
    _almacen.vecinos[id] = vecino;
    _almacen.guardar();
    return _json(200, vecino);
  }

  /// Lo que devuelve ingresar o registrarse: `{token, vecino}`.
  Map<String, dynamic> _sesion(String vecinoId) => {
    'token': _almacen.abrirSesion(vecinoId),
    'vecino': _almacen.vecinos[vecinoId],
  };

  // -------------------------------------------------------------------------
  // Comisión
  // -------------------------------------------------------------------------

  /// Deja pasar el pedido solo si el vecino de la sesión es de la comisión.
  /// Sin sesión válida lanza 401; con rol `vecino`, 403. Los errores los
  /// convierte en JSON `_manejarErrores`, que envuelve todo el handler.
  Middleware get soloComision =>
      (interno) => (pedido) {
        // El rol se lee del almacén, nunca del pedido.
        final id = _vecinoDe(pedido);
        if (_almacen.vecinos[id]!['rol'] != Roles.comision) {
          throw const ErrorDeApi.noPermitido(mensajeSoloComision);
        }
        return interno(pedido);
      };

  /// Rutas solo para la comisión, relativas a `/comision/`. La feature
  /// informe_alertas agrega acá su ruta.
  Router get _rutasDeLaComision => Router()
    ..all('/<_|.*>', (Request _) {
      throw const ErrorDeApi.noExiste('Esa dirección no existe.');
    });

  // -------------------------------------------------------------------------
  // Alertas
  // -------------------------------------------------------------------------

  Response _alertas(Request pedido) {
    _vecinoDe(pedido);
    final ordenadas = [
      ..._almacen.alertas,
    ]..sort((a, b) => (b['creada_en'] as int).compareTo(a['creada_en'] as int));
    return _json(200, ordenadas.map(_conNombre).toList());
  }

  Future<Response> _crearAlerta(Request pedido) async {
    final vecinoId = _vecinoDe(pedido);
    final datos = await _cuerpo(pedido);
    final categoria = _texto(datos, 'categoria');
    final tipo = _texto(datos, 'tipo');
    final descripcion = _texto(datos, 'descripcion', opcional: true);
    final direccion = _texto(datos, 'direccion', opcional: true);
    final latitud = datos['latitud'];
    final longitud = datos['longitud'];

    // Las mismas reglas y mensajes que la app (ReglasAlertas).
    final motivo = ReglasAlertas.motivoRechazo(
      categoria: categoria,
      tipo: tipo,
      descripcion: descripcion,
      direccion: direccion,
    );
    if (motivo != null) throw ErrorDeApi.datosInvalidos(motivo);
    if (latitud is! num ||
        longitud is! num ||
        latitud.abs() > 90 ||
        longitud.abs() > 180) {
      throw const ErrorDeApi.datosInvalidos('La ubicación no es válida.');
    }

    final alerta = {
      'id': _almacen.nuevoId('alerta'),
      'categoria': categoria,
      'tipo': tipo.trim(),
      'descripcion': descripcion.trim(),
      'direccion': direccion.trim(),
      'creada_en': _reloj.ahora().millisecondsSinceEpoch,
      'estado': 'activa',
      'latitud': latitud.toDouble(),
      'longitud': longitud.toDouble(),
      // Quién la reporta sale de la sesión, no de lo que manda la app.
      'reportada_por': vecinoId,
    };
    _almacen.alertas.insert(0, alerta);
    _almacen.guardar();
    // El nombre se agrega a una copia: no se guarda en el almacén.
    final respuesta = _conNombre(alerta);
    await notificarAlerta(respuesta);
    return _json(201, respuesta);
  }

  /// Una copia de [alerta] con `reportada_por_nombre`: el primer nombre de
  /// quien la reportó, o "" si el vecino no existe o no tiene nombre. Se
  /// calcula al responder y no se guarda, así un cambio de nombre se ve en
  /// la próxima lectura. Ningún otro dato del vecino viaja (R10).
  Map<String, dynamic> _conNombre(Map<String, dynamic> alerta) {
    final nombre = _almacen.vecinos[alerta['reportada_por']]?['nombre'];
    final partes = nombre is String
        ? nombre.trim().split(RegExp(r'\s+'))
        : const <String>[];
    return {
      ...alerta,
      'reportada_por_nombre': partes.isEmpty ? '' : partes.first,
    };
  }

  /// Envía el aviso push de [alerta] si todavía no está resuelta. Si el
  /// servicio de push falla, la alerta igual queda guardada.
  Future<void> notificarAlerta(Map<String, dynamic> alerta) async {
    if (alerta['estado'] == 'resuelta') return;
    try {
      await _push.enviarAlerta(alerta);
    } catch (_) {}
  }

  Future<Response> _cambiarEstado(Request pedido, String id) async {
    final vecinoId = _vecinoDe(pedido);
    final estado = _texto(await _cuerpo(pedido), 'estado');
    if (!_estados.contains(estado)) {
      throw const ErrorDeApi.datosInvalidos('Ese estado no existe.');
    }
    final alerta = _almacen.alertas.where((a) => a['id'] == id).firstOrNull;
    if (alerta == null) {
      throw const ErrorDeApi.noExiste('No encontramos esa alerta.');
    }
    // RF-05: solo quien la reportó puede cerrarla.
    if (alerta['reportada_por'] != vecinoId) {
      throw const ErrorDeApi.noPermitido(
        'Solo quien reportó la alerta puede cambiar su estado.',
      );
    }
    alerta['estado'] = estado;
    _almacen.guardar();
    return _json(200, _conNombre(alerta));
  }

  // -------------------------------------------------------------------------
  // Turnos
  // -------------------------------------------------------------------------

  Response _turnos(Request pedido) {
    _vecinoDe(pedido);
    final anio = int.tryParse(pedido.url.queryParameters['anio'] ?? '');
    final mes = int.tryParse(pedido.url.queryParameters['mes'] ?? '');
    if (anio == null || mes == null || mes < 1 || mes > 12) {
      throw const ErrorDeApi.datosInvalidos('Indicá el año y el mes.');
    }
    return _json(200, _turnosDelMes(anio, mes).map(_turnoCompleto).toList());
  }

  Response _anotarse(
    Request pedido,
    String fecha,
    String franja,
    String vecinoId,
  ) {
    _soloElMismoVecino(pedido, vecinoId);
    final dia = _validarTurno(fecha, franja);
    final vecino = _almacen.vecinos[vecinoId]!;
    final nacimiento = DateTime.parse(vecino['fecha_nacimiento'] as String);
    final hoy = _reloj.ahora();

    final clave = Almacen.claveTurno(fecha, franja);
    final turno =
        _almacen.turnos[clave] ??
        {
          'fecha': fecha,
          'franja': franja,
          'patrulleros': <String>[],
          'guardia_ventana': null,
        };
    final patrulleros = (turno['patrulleros'] as List).cast<String>();
    final guardia = turno['guardia_ventana'] as String?;

    final motivo = ReglasTurnos.motivoNoDisponible(
      vecinoId: vecinoId,
      nacimiento: nacimiento,
      patrulleros: patrulleros,
      guardiaVentana: guardia,
      turnosEnElMes: _cantidadEnElMes(vecinoId, dia),
      hoy: hoy,
    );
    if (motivo != null) throw ErrorDeApi.conflicto(motivo);

    final yaEstaba = patrulleros.contains(vecinoId) || guardia == vecinoId;
    if (!yaEstaba) {
      if (ReglasTurnos.esGuardiaVentana(nacimiento, hoy)) {
        turno['guardia_ventana'] = vecinoId;
      } else {
        turno['patrulleros'] = [...patrulleros, vecinoId];
      }
      _almacen.turnos[clave] = turno;
      _almacen.guardar();
    }
    return _json(200, _turnoCompleto(turno));
  }

  Response _salir(
    Request pedido,
    String fecha,
    String franja,
    String vecinoId,
  ) {
    _soloElMismoVecino(pedido, vecinoId);
    _validarTurno(fecha, franja);
    final turno = _almacen.turnos[Almacen.claveTurno(fecha, franja)];
    if (turno == null) {
      throw const ErrorDeApi.noExiste('Ese turno no existe.');
    }
    turno['patrulleros'] = [
      for (final id in (turno['patrulleros'] as List).cast<String>())
        if (id != vecinoId) id,
    ];
    if (turno['guardia_ventana'] == vecinoId) turno['guardia_ventana'] = null;
    _almacen.guardar();
    return _json(200, _turnoCompleto(turno));
  }

  DateTime _validarTurno(String fecha, String franja) {
    final dia = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(fecha)
        ? DateTime.tryParse(fecha)
        : null;
    if (dia == null || !ReglasTurnos.franjas.contains(franja)) {
      throw const ErrorDeApi.datosInvalidos('Ese turno no existe.');
    }
    return dia;
  }

  Iterable<Map<String, dynamic>> _turnosDelMes(int anio, int mes) {
    final prefijo = '$anio-${mes.toString().padLeft(2, '0')}-';
    return _almacen.turnos.values.where(
      (t) => (t['fecha'] as String).startsWith(prefijo),
    );
  }

  int _cantidadEnElMes(String vecinoId, DateTime dia) =>
      _turnosDelMes(dia.year, dia.month).where((t) {
        return (t['patrulleros'] as List).contains(vecinoId) ||
            t['guardia_ventana'] == vecinoId;
      }).length;

  /// El turno con los datos de cada vecino adentro, como lo espera la app.
  Map<String, dynamic> _turnoCompleto(Map<String, dynamic> turno) {
    final guardia = turno['guardia_ventana'] as String?;
    return {
      'fecha': turno['fecha'],
      'franja': turno['franja'],
      'patrulleros': [
        for (final id in (turno['patrulleros'] as List).cast<String>())
          _vecinoDelTurno(id),
      ],
      'guardia_ventana': guardia == null ? null : _vecinoDelTurno(guardia),
    };
  }

  /// Los datos de un vecino como aparecen dentro de un turno: una copia, sin
  /// `rol`. Copia para no borrar el rol del vecino guardado en `Almacen`.
  Map<String, dynamic> _vecinoDelTurno(String id) =>
      Map<String, dynamic>.of(_almacen.vecinos[id]!)..remove('rol');

  // -------------------------------------------------------------------------
  // Ayudas
  // -------------------------------------------------------------------------

  String? _token(Request pedido) {
    final encabezado = pedido.headers['authorization'] ?? '';
    return encabezado.startsWith('Bearer ') ? encabezado.substring(7) : null;
  }

  /// El id del vecino de la sesión, o 401 si no hay sesión válida.
  String _vecinoDe(Request pedido) {
    final token = _token(pedido);
    final id = token == null ? null : _almacen.vecinoDeLaSesion(token);
    if (id == null || !_almacen.vecinos.containsKey(id)) {
      throw const ErrorDeApi.sinSesion();
    }
    return id;
  }

  void _soloElMismoVecino(Request pedido, String vecinoId) {
    if (_vecinoDe(pedido) != vecinoId) {
      throw const ErrorDeApi.noPermitido(
        'Solo podés anotarte o salir de un turno vos.',
      );
    }
  }

  Future<Map<String, dynamic>> _cuerpo(Request pedido) async {
    final texto = await pedido.readAsString();
    final datos = texto.isEmpty ? null : jsonDecode(texto);
    if (datos is! Map<String, dynamic>) {
      throw const ErrorDeApi.datosInvalidos('Faltan los datos del pedido.');
    }
    return datos;
  }

  String _texto(
    Map<String, dynamic> datos,
    String campo, {
    bool opcional = false,
  }) {
    final valor = datos[campo];
    if (valor is String) return valor;
    if (valor == null && opcional) return '';
    throw ErrorDeApi.datosInvalidos('Falta el dato "$campo".');
  }

  static String _soloFecha(DateTime fecha) =>
      fecha.toIso8601String().substring(0, 10);

  static Response _json(int codigo, Object? cuerpo) => Response(
    codigo,
    body: jsonEncode(cuerpo),
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  /// Convierte los errores en respuestas JSON con un mensaje para el vecino.
  static Handler _manejarErrores(Handler siguiente) {
    return (pedido) async {
      try {
        return await siguiente(pedido);
      } on ErrorDeApi catch (e) {
        return _json(e.codigo, {'error': e.mensaje});
      } on FormatException {
        return _json(400, {
          'error': 'Los datos del pedido no son JSON válido.',
        });
      }
    };
  }
}
