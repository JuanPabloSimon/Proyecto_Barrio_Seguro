import 'package:flutter/material.dart';

import '../models/alerta.dart';
import '../models/turno.dart';
import '../models/vecino.dart';

// Datos de ejemplo para mostrar las vistas. Cuando haya backend,
// estas listas se reemplazan por lo que devuelva la API.

const usuarioDemo = Vecino(
  nombre: 'Clara Medina',
  iniciales: 'CM',
  telefono: '261 555-0142',
  calle: 'Los Álamos 1240',
  cuadra: 'Cuadra 12',
  antiguedad: 'Vecina desde marzo de 2021',
);

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
    reportadaPorMi: true,
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
    reportadaPorMi: true,
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
  ),
];

const turnosDemo = <Turno>[
  Turno(
    dia: 'Viernes',
    diaCorto: 'Vie',
    diaNumero: 25,
    mes: 'sep',
    horario: '22:00 - 00:00',
    vecinos: ['Clara Medina', 'Jorge Ruiz'],
    esMio: true,
  ),
  Turno(
    dia: 'Sábado',
    diaCorto: 'Sáb',
    diaNumero: 26,
    mes: 'sep',
    horario: '00:00 - 02:00',
    vecinos: ['Ana López', 'Martín Sosa'],
  ),
  Turno(
    dia: 'Sábado',
    diaCorto: 'Sáb',
    diaNumero: 26,
    mes: 'sep',
    horario: '22:00 - 00:00',
    vecinos: ['Pedro Gil', 'Laura Vega'],
  ),
  Turno(
    dia: 'Domingo',
    diaCorto: 'Dom',
    diaNumero: 27,
    mes: 'sep',
    horario: '20:00 - 22:00',
    vecinos: ['Clara Medina', 'Sofía Díaz'],
    esMio: true,
  ),
  Turno(
    dia: 'Lunes',
    diaCorto: 'Lun',
    diaNumero: 28,
    mes: 'sep',
    horario: '22:00 - 00:00',
    vecinos: ['Raúl Paz', 'Inés Molina'],
  ),
];
