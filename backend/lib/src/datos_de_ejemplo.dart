/// Datos con los que arranca el servidor la primera vez: los mismos vecinos,
/// turnos y alertas que muestra la app con el servidor simulado.
///
/// Cuentas para probar (teléfono / contraseña):
/// - Clara Medina, 45 años, patrulla: 261 555-0142 / barrio1234
/// - Rosa Ibáñez, 78 años, guardia de ventana: 261 555-0177 / barrio1234
const claveDeEjemplo = 'barrio1234';

const vecinosDeEjemplo = <Map<String, dynamic>>[
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
  {
    'id': 'rosa',
    'nombre': 'Rosa Ibáñez',
    'fecha_nacimiento': '1948-07-08',
    'telefono': '261 555-0177',
    'calle': 'Democracia',
    'cuadra': 'Cuadra 3',
    'vecino_desde': '2019-08-01',
  },
  {
    'id': 'ernesto',
    'nombre': 'Ernesto Funes',
    'fecha_nacimiento': '1952-03-19',
  },
  {'id': 'elena', 'nombre': 'Elena Quiroga', 'fecha_nacimiento': '1954-10-27'},
];

/// Los vecinos que pueden ingresar con [claveDeEjemplo].
const cuentasDeEjemplo = ['clara', 'rosa'];

/// Octubre 2026. Nadie supera los 2 turnos del mes.
const turnosDeEjemplo = <Map<String, dynamic>>[
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
/// creación se calcula al crear los datos, relativa a la hora actual.
const alertasDeEjemplo = <Map<String, dynamic>>[
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

/// Cuánto antes de "ahora" se creó cada alerta de ejemplo, en minutos.
const minutosAtrasDeEjemplo = [5, 18, 60, 60 * 15, 60 * 24 * 3];
