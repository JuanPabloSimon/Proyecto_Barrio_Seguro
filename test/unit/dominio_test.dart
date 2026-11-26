// Pruebas de la capa de dominio: reglas y cálculos puros, sin Flutter.

import 'package:barrio_seguro/domain/fechas.dart';
import 'package:barrio_seguro/domain/informe_alertas.dart';
import 'package:barrio_seguro/domain/models/alerta.dart';
import 'package:barrio_seguro/domain/models/turno.dart';
import 'package:barrio_seguro/domain/models/vecino.dart';
import 'package:barrio_seguro/domain/reglas_turnos.dart';
import 'package:barrio_seguro/ui/core/formato.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import '../ayudas/falsos.dart';

void main() {
  final hoy = DateTime(2026, 10, 1);

  group('Reglas de turnos', () {
    final turnoVacio = Turno(
      fecha: DateTime(2026, 10, 9),
      franja: Franja.noche,
    );

    test('con 2 turnos en el mes no se puede tomar otro', () {
      final motivo = ReglasTurnos.motivoNoDisponible(
        vecino: vecinaDePrueba,
        turno: turnoVacio,
        turnosEnElMes: 2,
        hoy: hoy,
      );
      expect(motivo, contains('máximo'));
    });

    test('con 1 turno en el mes se puede tomar otro', () {
      final motivo = ReglasTurnos.motivoNoDisponible(
        vecino: vecinaDePrueba,
        turno: turnoVacio,
        turnosEnElMes: 1,
        hoy: hoy,
      );
      expect(motivo, isNull);
    });

    test('la patrulla admite dos vecinos', () {
      final lleno = Turno(
        fecha: DateTime(2026, 10, 9),
        franja: Franja.noche,
        patrulleros: [
          Vecino(id: 'a', nombre: 'A', fechaNacimiento: DateTime(1990)),
          Vecino(id: 'b', nombre: 'B', fechaNacimiento: DateTime(1990)),
        ],
      );
      final motivo = ReglasTurnos.motivoNoDisponible(
        vecino: vecinaDePrueba,
        turno: lleno,
        turnosEnElMes: 0,
        hoy: hoy,
      );
      expect(motivo, contains('completa'));
    });

    test(
      'un mayor de 70 puede ser guardia aunque la patrulla esté completa',
      () {
        final lleno = Turno(
          fecha: DateTime(2026, 10, 9),
          franja: Franja.noche,
          patrulleros: [vecinaDePrueba, vecinaDePrueba],
        );
        final motivo = ReglasTurnos.motivoNoDisponible(
          vecino: vecinoMayor,
          turno: lleno,
          turnosEnElMes: 0,
          hoy: hoy,
        );
        expect(motivo, isNull);
      },
    );

    test('a los 70 años se pasa a guardia de ventana', () {
      final cumple70 = Vecino(
        id: 'x',
        nombre: 'X',
        fechaNacimiento: DateTime(1956, 10, 1),
      );
      final cumple70Manana = Vecino(
        id: 'y',
        nombre: 'Y',
        fechaNacimiento: DateTime(1956, 10, 2),
      );
      expect(cumple70.esGuardiaVentanaEn(hoy), isTrue);
      expect(cumple70Manana.esGuardiaVentanaEn(hoy), isFalse);
    });
  });

  group('Fechas', () {
    test('parsearFecha rechaza fechas imposibles y futuras', () {
      expect(parsearFecha('14/05/1950', hoy: hoy), DateTime(1950, 5, 14));
      expect(parsearFecha('31/02/1950', hoy: hoy), isNull);
      expect(parsearFecha('01/01/2030', hoy: hoy), isNull);
      expect(parsearFecha('1/1/1950', hoy: hoy), isNull);
    });

    test('tiempoTranscurrido usa palabras completas', () {
      final ahora = DateTime(2026, 10, 1, 12);
      expect(
        tiempoTranscurrido(DateTime(2026, 10, 1, 11, 55), ahora),
        'Hace 5 minutos',
      );
      expect(
        tiempoTranscurrido(DateTime(2026, 10, 1, 11), ahora),
        'Hace 1 hora',
      );
      expect(
        tiempoTranscurrido(DateTime(2026, 9, 30, 21, 40), ahora),
        'Ayer a las 21:40',
      );
      expect(
        tiempoTranscurrido(DateTime(2026, 9, 28, 12), ahora),
        'Hace 3 días',
      );
    });
  });

  group('JSON', () {
    test('una alerta vuelve igual después de ir y volver a JSON', () {
      final original = alertaDePrueba(estado: EstadoAlerta.enAtencion);
      final copia = Alerta.fromJson(original.toJson());
      expect(copia.id, original.id);
      expect(copia.estado, EstadoAlerta.enAtencion);
      expect(copia.ubicacion, original.ubicacion);
      expect(copia.creadaEn, original.creadaEn);
    });

    test('un estado desconocido de la API se toma como activa', () {
      expect(EstadoAlerta.desdeApi('cualquier_cosa'), EstadoAlerta.activa);
    });

    const jsonDeVecino = {
      'id': 'v1',
      'nombre': 'Clara Medina',
      'fecha_nacimiento': '1980-05-02',
    };

    test('el rol tiene solo dos valores: vecino y comision', () {
      expect(RolVecino.values, [RolVecino.vecino, RolVecino.comision]);
      expect(RolVecino.values.map((r) => r.json), ['vecino', 'comision']);
    });

    test('un vecino con rol comision es de la comisión', () {
      final vecino = Vecino.fromJson({...jsonDeVecino, 'rol': 'comision'});
      expect(vecino.rol, RolVecino.comision);
      expect(vecino.esComision, isTrue);
    });

    test('sin rol o con un rol desconocido es vecino común', () {
      final sinRol = Vecino.fromJson({...jsonDeVecino});
      final desconocido = Vecino.fromJson({...jsonDeVecino, 'rol': 'admin'});
      final vecino = Vecino.fromJson({...jsonDeVecino, 'rol': 'vecino'});
      for (final v in [sinRol, desconocido, vecino]) {
        expect(v.rol, RolVecino.vecino);
        expect(v.esComision, isFalse);
      }
    });

    test('el rol viaja en el JSON, ida y vuelta, para cada rol', () {
      for (final rol in RolVecino.values) {
        final original = Vecino(
          id: 'v1',
          nombre: 'Clara Medina',
          fechaNacimiento: DateTime(1980, 5, 2),
          rol: rol,
        );
        final json = original.toJson();
        expect(json['rol'], rol.json);
        expect(Vecino.fromJson(json).rol, rol);
      }
    });

    test('copyWith conserva el rol', () {
      for (final rol in RolVecino.values) {
        final original = Vecino(
          id: 'v1',
          nombre: 'Clara Medina',
          fechaNacimiento: DateTime(1980, 5, 2),
          rol: rol,
        );
        final copia = original.copyWith(nombre: 'Clara M.', telefono: '1');
        expect(copia.rol, rol);
        expect(copia.toJson()['rol'], rol.json);
      }
    });
  });

  group('Informe de alertas', () {
    Alerta crearAlerta({
      required String id,
      required DateTime fecha,
      String direccion = 'Calle Plantamura',
      String tipo = 'Intento de robo',
    }) {
      return Alerta(
        id: id,
        categoria: CategoriaAlerta.robo,
        tipo: tipo,
        descripcion: 'Prueba',
        direccion: direccion,
        creadaEn: fecha,
        estado: EstadoAlerta.activa,
        ubicacion: const LatLng(-32.8765, -68.8706),
        reportadaPor: 'clara',
      );
    }

    final octubre = DateTime(2026, 10);

    test('incluye solo las alertas del mes y año elegidos', () {
      final alertas = [
        crearAlerta(id: 'oct-1', fecha: DateTime(2026, 10, 5, 10)),
        crearAlerta(id: 'sep-1', fecha: DateTime(2026, 9, 30, 23)),
        crearAlerta(id: 'nov-1', fecha: DateTime(2026, 11, 1, 0)),
        crearAlerta(id: 'otro-anio', fecha: DateTime(2025, 10, 5, 10)),
      ];

      final informe = InformeAlertas.delMes(alertas: alertas, mes: octubre);

      expect(informe.total, 1);
      expect(informe.sinAlertas, isFalse);
    });

    test(
      'agrupa y ordena por calle y por tipo de mayor a menor y alfabéticamente',
      () {
        final alertas = [
          crearAlerta(
            id: '1',
            fecha: DateTime(2026, 10, 1, 9),
            direccion: 'Plantamura',
            tipo: 'Arrebato',
          ),
          crearAlerta(
            id: '2',
            fecha: DateTime(2026, 10, 2, 14),
            direccion: 'Democracia',
            tipo: 'Robo',
          ),
          crearAlerta(
            id: '3',
            fecha: DateTime(2026, 10, 3, 21),
            direccion: 'Plantamura',
            tipo: 'Robo',
          ),
          crearAlerta(
            id: '4',
            fecha: DateTime(2026, 10, 4, 2),
            direccion: 'Cabildo',
            tipo: 'Moto a alta velocidad',
          ),
        ];

        final informe = InformeAlertas.delMes(alertas: alertas, mes: octubre);

        expect(informe.porCalle.map((f) => '${f.nombre}:${f.cantidad}'), [
          'Plantamura:2',
          'Cabildo:1',
          'Democracia:1',
        ]);
        expect(informe.porTipo.map((f) => '${f.nombre}:${f.cantidad}'), [
          'Robo:2',
          'Arrebato:1',
          'Moto a alta velocidad:1',
        ]);
      },
    );

    test('agrupa por franja horaria según la hora de creación', () {
      final alertas = [
        crearAlerta(id: 'mad1', fecha: DateTime(2026, 10, 1, 1, 30)),
        crearAlerta(id: 'mad2', fecha: DateTime(2026, 10, 2, 5, 59)),
        crearAlerta(id: 'man1', fecha: DateTime(2026, 10, 3, 8, 0)),
        crearAlerta(id: 'tar1', fecha: DateTime(2026, 10, 4, 15, 20)),
        crearAlerta(id: 'noc1', fecha: DateTime(2026, 10, 5, 22, 10)),
        crearAlerta(id: 'noc2', fecha: DateTime(2026, 10, 6, 20, 0)),
        crearAlerta(id: 'noc3', fecha: DateTime(2026, 10, 7, 23, 45)),
      ];

      final informe = InformeAlertas.delMes(alertas: alertas, mes: octubre);

      expect(informe.porFranja.map((f) => '${f.nombre}:${f.cantidad}'), [
        'Noche (20:00 - 00:00):3',
        'Madrugada (00:00 - 06:00):2',
        'Mañana (06:00 - 12:00):1',
        'Tarde (12:00 - 20:00):1',
      ]);
    });

    test(
      'sin alertas en el mes devuelve sinAlertas en true y tablas vacías',
      () {
        final informe = InformeAlertas.delMes(
          alertas: [crearAlerta(id: 'sep', fecha: DateTime(2026, 9, 10, 12))],
          mes: octubre,
        );

        expect(informe.total, 0);
        expect(informe.sinAlertas, isTrue);
        expect(informe.porCalle, isEmpty);
        expect(informe.porTipo, isEmpty);
        expect(informe.porFranja, isEmpty);
      },
    );

    test('toCsv y nombreArchivoCsv exportan el informe y escapan comas', () {
      final informe = InformeAlertas.delMes(
        alertas: [
          crearAlerta(
            id: '1',
            fecha: DateTime(2026, 10, 10, 21),
            direccion: 'Cabildo, Cuadra 12',
            tipo: 'Pedido de ayuda (SOS)',
          ),
        ],
        mes: octubre,
      );

      expect(informe.nombreArchivoCsv, 'informe_alertas_2026_10.csv');
      final csv = informe.toCsv();
      expect(csv, contains('Sección,Detalle,Cantidad'));
      expect(csv, contains('Resumen,Total del mes,1'));
      expect(csv, contains('Por calle,"Cabildo, Cuadra 12",1'));
      expect(csv, contains('Por tipo,Pedido de ayuda (SOS),1'));
      expect(csv, contains('Por franja horaria,Noche (20:00 - 00:00),1'));
    });
  });
}
