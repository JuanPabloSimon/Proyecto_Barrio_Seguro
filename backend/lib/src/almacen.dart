import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'datos_de_ejemplo.dart';
import 'reloj.dart';

/// Los datos del barrio, en memoria y guardados en un archivo JSON.
///
/// Para un prototipo alcanza: el archivo se reescribe después de cada
/// cambio y, al reiniciar el servidor, se vuelve a leer. Si algún día hace
/// falta una base de datos, se reemplaza esta clase y la API no cambia.
class Almacen {
  Almacen._(this._archivo);

  /// Lee [archivo] si existe; si no, arranca con los datos de ejemplo. Sin
  /// [archivo] (en las pruebas) todo queda en memoria.
  factory Almacen.abrir({File? archivo, required Reloj reloj}) {
    final almacen = Almacen._(archivo);
    if (archivo != null && archivo.existsSync()) {
      almacen._leer(
        jsonDecode(archivo.readAsStringSync()) as Map<String, dynamic>,
      );
    } else {
      almacen._cargarEjemplos(reloj.ahora());
      almacen.guardar();
    }
    return almacen;
  }

  final File? _archivo;
  final _azar = Random.secure();

  /// Datos públicos de cada vecino, por id (el mismo JSON que usa la app).
  final Map<String, Map<String, dynamic>> vecinos = {};

  /// Teléfono y contraseña de cada vecino, por id. Separado de [vecinos]
  /// para que el hash nunca salga en una respuesta.
  final Map<String, Map<String, dynamic>> _credenciales = {};

  /// Sesiones abiertas: token -> id del vecino.
  final Map<String, String> _sesiones = {};

  /// Turnos por "fecha|franja". Los vecinos van por id.
  final Map<String, Map<String, dynamic>> turnos = {};

  /// De la más nueva a la más vieja.
  final List<Map<String, dynamic>> alertas = [];

  int _ultimoId = 0;

  String nuevoId(String prefijo) => '$prefijo-${++_ultimoId}';

  static String claveTurno(String fecha, String franja) => '$fecha|$franja';

  // -------------------------------------------------------------------------
  // Cuentas y sesiones
  // -------------------------------------------------------------------------

  /// Solo los dígitos: "261 555-0142" y "2615550142" son el mismo teléfono.
  static String normalizarTelefono(String telefono) =>
      telefono.replaceAll(RegExp(r'\D'), '');

  String _hash(String sal, String clave) =>
      sha256.convert(utf8.encode('$sal:$clave')).toString();

  String _aleatorio() =>
      base64Url.encode(List.generate(24, (_) => _azar.nextInt(256)));

  /// Si otro vecino (distinto de [salvo]) ya usa ese teléfono.
  bool telefonoRegistrado(String telefono, {String? salvo}) {
    final buscado = normalizarTelefono(telefono);
    return _credenciales.entries.any(
      (e) => e.key != salvo && e.value['telefono'] == buscado,
    );
  }

  void cambiarTelefono(String vecinoId, String telefono) {
    _credenciales[vecinoId]?['telefono'] = normalizarTelefono(telefono);
  }

  void guardarCredenciales(String vecinoId, String telefono, String clave) {
    final sal = _aleatorio();
    _credenciales[vecinoId] = {
      'telefono': normalizarTelefono(telefono),
      'sal': sal,
      'hash': _hash(sal, clave),
    };
  }

  /// El id del vecino si el teléfono y la contraseña coinciden.
  String? verificar(String telefono, String clave) {
    final buscado = normalizarTelefono(telefono);
    for (final MapEntry(key: id, value: c) in _credenciales.entries) {
      if (c['telefono'] == buscado &&
          c['hash'] == _hash(c['sal'] as String, clave)) {
        return id;
      }
    }
    return null;
  }

  String abrirSesion(String vecinoId) {
    final token = _aleatorio();
    _sesiones[token] = vecinoId;
    guardar();
    return token;
  }

  String? vecinoDeLaSesion(String token) => _sesiones[token];

  void cerrarSesion(String token) {
    _sesiones.remove(token);
    guardar();
  }

  // -------------------------------------------------------------------------
  // Archivo
  // -------------------------------------------------------------------------

  /// Reescribe el archivo con todos los datos. Primero en un archivo
  /// temporal y después se renombra: si el servidor se corta a la mitad,
  /// queda el archivo anterior entero.
  void guardar() {
    final archivo = _archivo;
    if (archivo == null) return;
    archivo.parent.createSync(recursive: true);
    final temporal = File('${archivo.path}.tmp');
    temporal.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'ultimo_id': _ultimoId,
        'vecinos': vecinos,
        'credenciales': _credenciales,
        'sesiones': _sesiones,
        'turnos': turnos,
        'alertas': alertas,
      }),
    );
    temporal.renameSync(archivo.path);
  }

  void _leer(Map<String, dynamic> json) {
    _ultimoId = json['ultimo_id'] as int;
    Map<String, Map<String, dynamic>> mapas(String clave) => {
      for (final MapEntry(:key, :value)
          in (json[clave] as Map<String, dynamic>).entries)
        key: Map<String, dynamic>.of(value as Map<String, dynamic>),
    };
    vecinos.addAll(mapas('vecinos'));
    _credenciales.addAll(mapas('credenciales'));
    turnos.addAll(mapas('turnos'));
    _sesiones.addAll((json['sesiones'] as Map<String, dynamic>).cast());
    alertas.addAll([
      for (final a in json['alertas'] as List<dynamic>)
        Map<String, dynamic>.of(a as Map<String, dynamic>),
    ]);
  }

  void _cargarEjemplos(DateTime ahora) {
    for (final vecino in vecinosDeEjemplo) {
      vecinos[vecino['id'] as String] = Map.of(vecino);
    }
    for (final id in cuentasDeEjemplo) {
      guardarCredenciales(
        id,
        vecinos[id]!['telefono'] as String,
        claveDeEjemplo,
      );
    }
    for (final turno in turnosDeEjemplo) {
      turnos[claveTurno(
        turno['fecha'] as String,
        turno['franja'] as String,
      )] = {
        ...turno,
        'patrulleros': [...turno['patrulleros'] as List<String>],
      };
    }
    for (var i = 0; i < alertasDeEjemplo.length; i++) {
      final creada = ahora.subtract(
        Duration(minutes: minutosAtrasDeEjemplo[i]),
      );
      alertas.add({
        ...alertasDeEjemplo[i],
        'creada_en': creada.millisecondsSinceEpoch,
      });
    }
  }
}
