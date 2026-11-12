import 'dart:math' as math;

import '../../../domain/models/turno.dart';
import '../../../domain/models/vecino.dart';
import '../../../domain/reglas_turnos.dart';
import '../error_del_servidor.dart';
import '../reloj.dart';

/// Hace de servidor mientras no exista la API: guarda los datos en memoria,
/// en el mismo formato JSON que va a usar la API, y aplica sus reglas.
///
/// Los servicios simulados (`*ServiceSimulado`) le hablan a esta clase como
/// le hablarían a la API por HTTP. Cuando la API esté lista, se reemplazan
/// por los servicios reales en `Dependencias` y nada más cambia.
class ServidorSimulado {
  ServidorSimulado({
    required this._reloj,
    this.demora = const Duration(milliseconds: 400),
    this.probabilidadDeFallo = 0,
    math.Random? azar,
  }) : _azar = azar ?? math.Random() {
    _cargarDatosIniciales();
  }

  final Reloj _reloj;
  final math.Random _azar;

  /// Cuánto tarda en "responder", como si fuera la red.
  final Duration demora;

  /// Entre 0 y 1: qué tan seguido falla la conexión. Sirve para probar los
  /// estados de error de las pantallas.
  final double probabilidadDeFallo;

  final Map<String, Map<String, dynamic>> _vecinos = {};
  final Map<String, Map<String, dynamic>> _turnos = {};
  final List<Map<String, dynamic>> _alertas = [];
  int _ultimoId = 0;

  /// Espera la demora y, a veces, falla como fallaría la red.
  Future<void> responder() async {
    await Future<void>.delayed(demora);
    if (_azar.nextDouble() < probabilidadDeFallo) {
      throw Exception('No se pudo conectar con el servidor');
    }
  }

  String _nuevoId(String prefijo) => '$prefijo-${++_ultimoId}';

  // -------------------------------------------------------------------------
  // Vecinos
  // -------------------------------------------------------------------------

  Map<String, dynamic> ingresar(String usuario, String clave) {
    // Prototipo: cualquier usuario entra como la vecina de ejemplo.
    return _sesion(idVecinaDeEjemplo);
  }

  /// Lo que devuelve la API al ingresar o registrarse.
  Map<String, dynamic> _sesion(String vecinoId) => {
    'token': 'token-simulado-$vecinoId',
    'vecino': Map.of(_vecinos[vecinoId]!),
  };

  Map<String, dynamic> registrar(Map<String, dynamic> datos) {
    final hoy = _reloj.ahora();
    final vecino = {
      ...datos,
      'id': _nuevoId('vecino'),
      'vecino_desde': hoy.toIso8601String().substring(0, 10),
    };
    _vecinos[vecino['id'] as String] = vecino;
    return _sesion(vecino['id'] as String);
  }

  Map<String, dynamic> actualizarVecino(String id, Map<String, dynamic> datos) {
    final actual = _vecinos[id];
    if (actual == null) {
      throw const ErrorDelServidor('No encontramos tu cuenta.');
    }
    // El id, la fecha de nacimiento y la antigüedad no se cambian desde la app.
    final actualizado = {
      ...actual,
      ...datos,
      'id': id,
      'fecha_nacimiento': actual['fecha_nacimiento'],
      'vecino_desde': actual['vecino_desde'],
    };
    _vecinos[id] = actualizado;
    return Map.of(actualizado);
  }

  // -------------------------------------------------------------------------
  // Turnos
  // -------------------------------------------------------------------------

  String _claveTurno(String fecha, String franja) => '$fecha|$franja';

  List<Map<String, dynamic>> turnosDelMes(int anio, int mes) {
    final prefijo = '$anio-${mes.toString().padLeft(2, '0')}';
    return [
      for (final turno in _turnos.values)
        if ((turno['fecha'] as String).startsWith(prefijo))
          _turnoCompleto(turno),
    ];
  }

  /// El turno con los datos de cada vecino adentro, como lo manda la API.
  Map<String, dynamic> _turnoCompleto(Map<String, dynamic> turno) {
    final guardia = turno['guardia_ventana'] as String?;
    return {
      'fecha': turno['fecha'],
      'franja': turno['franja'],
      'patrulleros': [
        for (final id in turno['patrulleros'] as List<String>)
          Map.of(_vecinos[id]!),
      ],
      'guardia_ventana': guardia == null ? null : Map.of(_vecinos[guardia]!),
    };
  }

  Map<String, dynamic> anotarse(String fecha, String franja, String vecinoId) {
    final json = _vecinos[vecinoId];
    if (json == null) throw const ErrorDelServidor('No encontramos tu cuenta.');
    final vecino = Vecino.fromJson(json);

    final clave = _claveTurno(fecha, franja);
    final guardado =
        _turnos[clave] ??
        {
          'fecha': fecha,
          'franja': franja,
          'patrulleros': <String>[],
          'guardia_ventana': null,
        };

    // El servidor vuelve a aplicar las reglas: no confía solo en la app.
    final turno = Turno.fromJson(_turnoCompleto(guardado));
    final dia = DateTime.parse(fecha);
    final motivo = ReglasTurnos.motivoNoDisponible(
      vecino: vecino,
      turno: turno,
      turnosEnElMes: _cantidadEnElMes(vecinoId, dia),
      hoy: _reloj.ahora(),
    );
    if (motivo != null) throw ErrorDelServidor(motivo);
    if (turno.incluye(vecino)) return _turnoCompleto(guardado);

    if (vecino.esGuardiaVentanaEn(_reloj.ahora())) {
      guardado['guardia_ventana'] = vecinoId;
    } else {
      guardado['patrulleros'] = [
        ...guardado['patrulleros'] as List<String>,
        vecinoId,
      ];
    }
    _turnos[clave] = guardado;
    return _turnoCompleto(guardado);
  }

  Map<String, dynamic> salir(String fecha, String franja, String vecinoId) {
    final clave = _claveTurno(fecha, franja);
    final guardado = _turnos[clave];
    if (guardado == null) throw const ErrorDelServidor('Ese turno no existe.');

    guardado['patrulleros'] = [
      for (final id in guardado['patrulleros'] as List<String>)
        if (id != vecinoId) id,
    ];
    if (guardado['guardia_ventana'] == vecinoId) {
      guardado['guardia_ventana'] = null;
    }
    return _turnoCompleto(guardado);
  }

  int _cantidadEnElMes(String vecinoId, DateTime dia) {
    return turnosDelMes(dia.year, dia.month)
        .map(Turno.fromJson)
        .where(
          (t) =>
              t.patrulleros.any((p) => p.id == vecinoId) ||
              t.guardiaVentana?.id == vecinoId,
        )
        .length;
  }

  // -------------------------------------------------------------------------
  // Alertas
  // -------------------------------------------------------------------------

  List<Map<String, dynamic>> alertas() => [for (final a in _alertas) Map.of(a)];

  Map<String, dynamic> crearAlerta(Map<String, dynamic> datos) {
    final alerta = {
      ...datos,
      'id': _nuevoId('alerta'),
      'creada_en': _reloj.ahora().millisecondsSinceEpoch,
      'estado': 'activa',
    };
    _alertas.insert(0, alerta);
    return Map.of(alerta);
  }

  Map<String, dynamic> cambiarEstadoDeAlerta(String id, String estado) {
    final alerta = _alertas.where((a) => a['id'] == id).firstOrNull;
    if (alerta == null) {
      throw const ErrorDelServidor('No encontramos esa alerta.');
    }
    alerta['estado'] = estado;
    return Map.of(alerta);
  }

  // -------------------------------------------------------------------------
  // Datos de ejemplo
  // -------------------------------------------------------------------------

  static const idVecinaDeEjemplo = 'clara';

  void _cargarDatosIniciales() {
    for (final vecino in _vecinosDeEjemplo) {
      _vecinos[vecino['id'] as String] = Map.of(vecino);
    }
    for (final turno in _turnosDeEjemplo) {
      final copia = {
        ...turno,
        'patrulleros': [...turno['patrulleros'] as List<String>],
      };
      _turnos[_claveTurno(
            turno['fecha'] as String,
            turno['franja'] as String,
          )] =
          copia;
    }

    final ahora = _reloj.ahora();
    final ayer = DateTime(ahora.year, ahora.month, ahora.day - 1, 21, 40);
    final creadas = [
      ahora.subtract(const Duration(minutes: 5)),
      ahora.subtract(const Duration(minutes: 18)),
      ahora.subtract(const Duration(hours: 1)),
      ayer,
      ahora.subtract(const Duration(days: 3)),
    ];
    for (var i = 0; i < _alertasDeEjemplo.length; i++) {
      _alertas.add({
        ..._alertasDeEjemplo[i],
        'creada_en': creadas[i].millisecondsSinceEpoch,
      });
    }
  }
}

const _vecinosDeEjemplo = <Map<String, dynamic>>[
  {
    'id': 'clara',
    'nombre': 'Clara Medina',
    'fecha_nacimiento': '1981-05-14',
    'telefono': '261 555-0142',
    'calle': 'Cabildo de Mendoza',
    'cuadra': 'Cuadra 12',
    'vecino_desde': '2021-03-01',
  },
  {'id': 'jorge', 'nombre': 'Jorge Ruiz', 'fecha_nacimiento': '1975-08-02'},
  {'id': 'ana', 'nombre': 'Ana López', 'fecha_nacimiento': '1990-01-21'},
  {'id': 'martin', 'nombre': 'Martín Sosa', 'fecha_nacimiento': '1986-11-09'},
  {'id': 'pedro', 'nombre': 'Pedro Gil', 'fecha_nacimiento': '1979-04-30'},
  {'id': 'laura', 'nombre': 'Laura Vega', 'fecha_nacimiento': '1993-06-17'},
  {'id': 'sofia', 'nombre': 'Sofía Díaz', 'fecha_nacimiento': '1988-02-25'},
  {'id': 'raul', 'nombre': 'Raúl Paz', 'fecha_nacimiento': '1969-09-12'},
  {'id': 'ines', 'nombre': 'Inés Molina', 'fecha_nacimiento': '1984-12-03'},
  // Guardias de ventana (70 años o más)
  {'id': 'rosa', 'nombre': 'Rosa Ibáñez', 'fecha_nacimiento': '1948-07-08'},
  {
    'id': 'ernesto',
    'nombre': 'Ernesto Funes',
    'fecha_nacimiento': '1952-03-19',
  },
  {'id': 'elena', 'nombre': 'Elena Quiroga', 'fecha_nacimiento': '1954-10-27'},
];

/// Octubre 2026. Nadie supera los 2 turnos del mes.
const _turnosDeEjemplo = <Map<String, dynamic>>[
  {
    'fecha': '2026-10-02',
    'franja': 'noche',
    'patrulleros': ['jorge', 'ana'],
    'guardia_ventana': 'rosa',
  },
  {
    'fecha': '2026-10-03',
    'franja': 'madrugada',
    'patrulleros': ['martin', 'pedro'],
    'guardia_ventana': null,
  },
  {
    'fecha': '2026-10-09',
    'franja': 'noche',
    'patrulleros': ['clara', 'sofia'],
    'guardia_ventana': 'ernesto',
  },
  {
    'fecha': '2026-10-10',
    'franja': 'temprano',
    'patrulleros': ['laura', 'raul'],
    'guardia_ventana': null,
  },
  {
    'fecha': '2026-10-16',
    'franja': 'noche',
    'patrulleros': ['ines', 'jorge'],
    'guardia_ventana': 'elena',
  },
  {
    'fecha': '2026-10-17',
    'franja': 'noche',
    'patrulleros': ['ana', 'martin'],
    'guardia_ventana': 'rosa',
  },
  {
    'fecha': '2026-10-23',
    'franja': 'madrugada',
    'patrulleros': ['pedro', 'laura'],
    'guardia_ventana': null,
  },
  {
    'fecha': '2026-10-24',
    'franja': 'noche',
    'patrulleros': ['raul', 'ines'],
    'guardia_ventana': 'ernesto',
  },
  {
    'fecha': '2026-10-30',
    'franja': 'noche',
    'patrulleros': ['sofia'],
    'guardia_ventana': 'elena',
  },
];

/// Todas dentro del radio de 1000 m del Barrio Soberanía. La fecha de
/// creación se calcula al arrancar, relativa a la hora actual.
const _alertasDeEjemplo = <Map<String, dynamic>>[
  {
    'id': 'a1',
    'categoria': 'actividad_sospechosa',
    'tipo': 'Actividad sospechosa',
    'descripcion': 'Dos personas revisando autos estacionados sobre la vereda.',
    'direccion': 'Calle Plantamura',
    'estado': 'activa',
    'latitud': -32.877264,
    'longitud': -68.868785,
    'reportada_por': 'clara',
  },
  {
    'id': 'a2',
    'categoria': 'vehiculo',
    'tipo': 'Moto a alta velocidad',
    'descripcion': 'Moto sin patente pasando varias veces a toda velocidad.',
    'direccion': 'Santiago Felipe Llaver',
    'estado': 'en_atencion',
    'latitud': -32.874338,
    'longitud': -68.868583,
    'reportada_por': 'martin',
  },
  {
    'id': 'a3',
    'categoria': 'robo',
    'tipo': 'Intento de robo',
    'descripcion': 'Forzaron el portón de un garage. No hubo heridos.',
    'direccion': 'Calle Gran Cap. Sur',
    'estado': 'activa',
    'latitud': -32.875574,
    'longitud': -68.872913,
    'reportada_por': 'pedro',
  },
  {
    'id': 'a4',
    'categoria': 'arrebato',
    'tipo': 'Arrebato',
    'descripcion':
        'Le sacaron el celular a una vecina en la parada del colectivo.',
    'direccion': 'Parada de colectivo de Carlos W. Lencinas',
    'estado': 'resuelta',
    'latitud': -32.879792,
    'longitud': -68.868027,
    'reportada_por': 'clara',
  },
  {
    'id': 'a5',
    'categoria': 'ruidos',
    'tipo': 'Ruidos en terreno baldío',
    'descripcion': 'Ruidos y linternas de noche en el terreno de la esquina.',
    'direccion': 'Democracia y Cabildo de Mendoza',
    'estado': 'resuelta',
    'latitud': -32.878272,
    'longitud': -68.871144,
    'reportada_por': 'rosa',
  },
];
