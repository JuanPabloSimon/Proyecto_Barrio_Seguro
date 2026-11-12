// Pruebas de la capa de dominio: reglas y cálculos puros, sin Flutter.

import 'package:barrio_seguro/domain/fechas.dart';
import 'package:barrio_seguro/domain/models/alerta.dart';
import 'package:barrio_seguro/domain/models/turno.dart';
import 'package:barrio_seguro/domain/models/vecino.dart';
import 'package:barrio_seguro/domain/reglas_turnos.dart';
import 'package:barrio_seguro/ui/core/formato.dart';
import 'package:flutter_test/flutter_test.dart';

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
  });
}
