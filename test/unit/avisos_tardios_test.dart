// Pruebas de las reglas puras de los avisos que llegan con demora.

import 'package:barrio_seguro/domain/avisos_tardios.dart';
import 'package:barrio_seguro/domain/models/alerta.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

Alerta _alerta({
  CategoriaAlerta categoria = CategoriaAlerta.sos,
  String tipo = 'Pedido de ayuda (SOS)',
  String nombre = 'Marta',
  DateTime? creadaEn,
}) => Alerta(
  id: 'a1',
  categoria: categoria,
  tipo: tipo,
  descripcion: '',
  direccion: 'Calle de prueba',
  creadaEn: creadaEn ?? DateTime(2026, 10, 1, 15, 10),
  estado: EstadoAlerta.activa,
  ubicacion: const LatLng(-32.8765, -68.8706),
  reportadaPor: 'marta',
  reportadaPorNombre: nombre,
);

void main() {
  group('Clasificación de la demora (R1)', () {
    final creada = DateTime(2026, 10, 1, 15, 10);

    PuntualidadAviso conDemora(Duration demora) =>
        clasificarAviso(creadaEn: creada, llegada: creada.add(demora));

    test('4:59 y 5:00 de demora llegan a tiempo', () {
      expect(
        conDemora(const Duration(minutes: 4, seconds: 59)),
        PuntualidadAviso.aTiempo,
      );
      expect(conDemora(const Duration(minutes: 5)), PuntualidadAviso.aTiempo);
    });

    test('5:01 de demora es tardío', () {
      expect(
        conDemora(const Duration(minutes: 5, seconds: 1)),
        PuntualidadAviso.tardio,
      );
    });

    test('2 horas exactas es tardío', () {
      expect(conDemora(const Duration(hours: 2)), PuntualidadAviso.tardio);
    });

    test('2 horas y 1 segundo es demasiado tardío', () {
      expect(
        conDemora(const Duration(hours: 2, seconds: 1)),
        PuntualidadAviso.demasiadoTardio,
      );
    });

    test('una demora negativa llega a tiempo', () {
      expect(conDemora(const Duration(minutes: -3)), PuntualidadAviso.aTiempo);
    });

    test('esTardia es verdadero para tardío y demasiado tardío', () {
      expect(esTardia(PuntualidadAviso.aTiempo), isFalse);
      expect(esTardia(PuntualidadAviso.tardio), isTrue);
      expect(esTardia(PuntualidadAviso.demasiadoTardio), isTrue);
    });
  });

  group('Texto del aviso tardío', () {
    test(
      'nombre corto de sos, robo, actividad sospechosa, vehículo y ruidos',
      () {
        expect(CategoriaAlerta.sos.nombreCorto, 'SOS');
        expect(CategoriaAlerta.robo.nombreCorto, 'Robo');
        expect(
          CategoriaAlerta.actividadSospechosa.nombreCorto,
          'Actividad sospechosa',
        );
        expect(CategoriaAlerta.vehiculo.nombreCorto, 'Vehículo sospechoso');
        expect(CategoriaAlerta.ruidos.nombreCorto, 'Ruidos');
      },
    );

    test('arrebato no tiene nombre corto y el título usa el tipo de la alerta ("Arrebato de Marta 15:10")', () {
      expect(CategoriaAlerta.arrebato.nombreCorto, isNull);
      final alerta = _alerta(
        categoria: CategoriaAlerta.arrebato,
        tipo: 'Arrebato',
      );
      expect(tipoParaAviso(alerta), 'Arrebato');
      expect(tituloAvisoTardio(alerta), 'Arrebato de Marta 15:10');
    });

    test('título "SOS de Marta 15:10"', () {
      expect(tituloAvisoTardio(_alerta()), 'SOS de Marta 15:10');
    });

    test(
      'el aviso tardío de un SOS "Intento de robo" dice "SOS de Marta 15:10"',
      () {
        expect(
          tituloAvisoTardio(_alerta(tipo: 'Intento de robo')),
          'SOS de Marta 15:10',
        );
      },
    );

    test('título "Robo de Marta 15:10"', () {
      expect(
        tituloAvisoTardio(
          _alerta(categoria: CategoriaAlerta.robo, tipo: 'Intento de robo'),
        ),
        'Robo de Marta 15:10',
      );
    });

    test('la hora va con dos dígitos en 24 horas ("09:05", "23:50")', () {
      expect(horaYMinutos(DateTime(2026, 10, 1, 9, 5)), '09:05');
      expect(horaYMinutos(DateTime(2026, 10, 1, 23, 50)), '23:50');
      expect(horaYMinutos(DateTime(2026, 10, 1, 0, 0)), '00:00');
    });

    test('una alerta de las 23:50 recibida a las 00:30 dice solo "23:50"', () {
      final creada = DateTime(2026, 10, 1, 23, 50);
      final alerta = _alerta(creadaEn: creada);
      final llegada = DateTime(2026, 10, 2, 0, 30);
      expect(
        clasificarAviso(creadaEn: creada, llegada: llegada),
        PuntualidadAviso.tardio,
      );
      expect(tituloAvisoTardio(alerta), 'SOS de Marta 23:50');
    });

    test('sin nombre dice "de un vecino"', () {
      expect(tituloAvisoTardio(_alerta(nombre: '')), 'SOS de un vecino 15:10');
    });

    test('el cuerpo es el texto acordado', () {
      expect(
        cuerpoAvisoTardio,
        'Llegó con demora por falta de señal. Puede que ya no esté pasando.',
      );
    });
  });

  // estado_alerta R60 a R62: el vigilante mide desde su revisión anterior.
  group('Reapertura vista por el vigilante', () {
    final anterior = DateTime.utc(2026, 10, 1, 12);

    test('2 horas justas desde la revisión anterior no es tardía', () {
      expect(
        reaperturaDelVigilanteTardia(
          revisionAnterior: anterior,
          ahora: anterior.add(const Duration(hours: 2)),
        ),
        isFalse,
      );
    });

    test('2 horas y 1 segundo es tardía', () {
      expect(
        reaperturaDelVigilanteTardia(
          revisionAnterior: anterior,
          ahora: anterior.add(const Duration(hours: 2, seconds: 1)),
        ),
        isTrue,
      );
    });

    test('unos segundos no es tardía', () {
      expect(
        reaperturaDelVigilanteTardia(
          revisionAnterior: anterior,
          ahora: anterior.add(const Duration(seconds: 45)),
        ),
        isFalse,
      );
    });

    test('una diferencia negativa no es tardía', () {
      expect(
        reaperturaDelVigilanteTardia(
          revisionAnterior: anterior,
          ahora: anterior.subtract(const Duration(hours: 3)),
        ),
        isFalse,
      );
    });
  });
}
