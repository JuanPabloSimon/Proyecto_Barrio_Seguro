import 'package:flutter/material.dart';

import '../models/alerta.dart';
import '../models/turno.dart';
import '../models/vecino.dart';

// Datos de ejemplo para el prototipo. Cuando haya backend, se reemplazan
// por lo que devuelva la API, sin tocar las pantallas.

/// Mes que muestra el calendario de turnos.
final mesDeTurnos = DateTime(2026, 10);

// ---------------------------------------------------------------------------
// Vecinos
// ---------------------------------------------------------------------------

final vecinoClara = Vecino(
  id: 'clara',
  nombre: 'Clara Medina',
  fechaNacimiento: DateTime(1981, 5, 14),
  telefono: '261 555-0142',
  calle: 'Los Álamos 1240',
  cuadra: 'Cuadra 12',
  antiguedad: 'Vecina desde marzo de 2021',
);

final _jorge = Vecino(id: 'jorge', nombre: 'Jorge Ruiz', fechaNacimiento: DateTime(1975, 8, 2));
final _ana = Vecino(id: 'ana', nombre: 'Ana López', fechaNacimiento: DateTime(1990, 1, 21));
final _martin = Vecino(id: 'martin', nombre: 'Martín Sosa', fechaNacimiento: DateTime(1986, 11, 9));
final _pedro = Vecino(id: 'pedro', nombre: 'Pedro Gil', fechaNacimiento: DateTime(1979, 4, 30));
final _laura = Vecino(id: 'laura', nombre: 'Laura Vega', fechaNacimiento: DateTime(1993, 6, 17));
final _sofia = Vecino(id: 'sofia', nombre: 'Sofía Díaz', fechaNacimiento: DateTime(1988, 2, 25));
final _raul = Vecino(id: 'raul', nombre: 'Raúl Paz', fechaNacimiento: DateTime(1969, 9, 12));
final _ines = Vecino(id: 'ines', nombre: 'Inés Molina', fechaNacimiento: DateTime(1984, 12, 3));

// Guardias de ventana (70 años o más)
final _rosa = Vecino(id: 'rosa', nombre: 'Rosa Ibáñez', fechaNacimiento: DateTime(1948, 7, 8));
final _ernesto = Vecino(id: 'ernesto', nombre: 'Ernesto Funes', fechaNacimiento: DateTime(1952, 3, 19));
final _elena = Vecino(id: 'elena', nombre: 'Elena Quiroga', fechaNacimiento: DateTime(1954, 10, 27));

// ---------------------------------------------------------------------------
// Turnos de octubre 2026 (nadie supera los 2 turnos del mes)
// ---------------------------------------------------------------------------

List<Turno> turnosDemo() => [
      Turno(
        fecha: DateTime(2026, 10, 2),
        franja: Franja.noche,
        patrulleros: [_jorge, _ana],
        guardiaVentana: _rosa,
      ),
      Turno(
        fecha: DateTime(2026, 10, 3),
        franja: Franja.madrugada,
        patrulleros: [_martin, _pedro],
      ),
      Turno(
        fecha: DateTime(2026, 10, 9),
        franja: Franja.noche,
        patrulleros: [vecinoClara, _sofia],
        guardiaVentana: _ernesto,
      ),
      Turno(
        fecha: DateTime(2026, 10, 10),
        franja: Franja.temprano,
        patrulleros: [_laura, _raul],
      ),
      Turno(
        fecha: DateTime(2026, 10, 16),
        franja: Franja.noche,
        patrulleros: [_ines, _jorge],
        guardiaVentana: _elena,
      ),
      Turno(
        fecha: DateTime(2026, 10, 17),
        franja: Franja.noche,
        patrulleros: [_ana, _martin],
        guardiaVentana: _rosa,
      ),
      Turno(
        fecha: DateTime(2026, 10, 23),
        franja: Franja.madrugada,
        patrulleros: [_pedro, _laura],
      ),
      Turno(
        fecha: DateTime(2026, 10, 24),
        franja: Franja.noche,
        patrulleros: [_raul, _ines],
        guardiaVentana: _ernesto,
      ),
      Turno(
        fecha: DateTime(2026, 10, 30),
        franja: Franja.noche,
        patrulleros: [_sofia],
        guardiaVentana: _elena,
      ),
    ];

// ---------------------------------------------------------------------------
// Alertas
// ---------------------------------------------------------------------------

const alertasDemo = <Alerta>[
  Alerta(
    id: 'a1',
    tipo: 'Actividad sospechosa',
    descripcion: 'Dos personas revisando autos estacionados sobre la vereda.',
    direccion: 'Los Álamos al 1200',
    hace: 'Hace 5 min',
    estado: EstadoAlerta.activa,
    posicion: Offset(0.60, 0.40),
    icono: Icons.visibility_outlined,
    reportadaPor: 'clara',
  ),
  Alerta(
    id: 'a2',
    tipo: 'Moto a alta velocidad',
    descripcion: 'Moto sin patente dando vueltas alrededor de la plaza.',
    direccion: 'Plaza San Martín',
    hace: 'Hace 18 min',
    estado: EstadoAlerta.enAtencion,
    posicion: Offset(0.25, 0.52),
    icono: Icons.two_wheeler,
    reportadaPor: 'martin',
  ),
  Alerta(
    id: 'a3',
    tipo: 'Intento de robo',
    descripcion: 'Forzaron el portón de un garage. No hubo heridos.',
    direccion: 'Las Acacias 850',
    hace: 'Hace 1 h',
    estado: EstadoAlerta.activa,
    posicion: Offset(0.78, 0.70),
    icono: Icons.lock_open,
    reportadaPor: 'pedro',
  ),
  Alerta(
    id: 'a4',
    tipo: 'Arrebato',
    descripcion: 'Le sacaron el celular a una vecina en la parada del colectivo.',
    direccion: 'Av. Principal y Los Olmos',
    hace: 'Ayer, 21:40',
    estado: EstadoAlerta.resuelta,
    posicion: Offset(0.18, 0.22),
    icono: Icons.phone_android,
    reportadaPor: 'clara',
  ),
  Alerta(
    id: 'a5',
    tipo: 'Ruidos en terreno baldío',
    descripcion: 'Ruidos y linternas de noche en el terreno de la esquina.',
    direccion: 'Los Olmos 300',
    hace: 'Hace 3 días',
    estado: EstadoAlerta.resuelta,
    posicion: Offset(0.48, 0.85),
    icono: Icons.hearing,
    reportadaPor: 'rosa',
  ),
];
