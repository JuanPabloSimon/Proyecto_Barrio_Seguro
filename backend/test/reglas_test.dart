import 'package:barrio_seguro_backend/barrio_seguro_backend.dart';
import 'package:test/test.dart';

void main() {
  final hoy = DateTime(2026, 10, 1);

  test('a los 70 años se pasa a guardia de ventana', () {
    expect(ReglasTurnos.esGuardiaVentana(DateTime(1956, 10, 1), hoy), isTrue);
    expect(ReglasTurnos.esGuardiaVentana(DateTime(1956, 10, 2), hoy), isFalse);
  });

  test('ya anotado en el turno, no hay motivo para rechazarlo', () {
    expect(
      ReglasTurnos.motivoNoDisponible(
        vecinoId: 'clara',
        nacimiento: DateTime(1981),
        patrulleros: ['clara', 'sofia'],
        guardiaVentana: null,
        turnosEnElMes: 2,
        hoy: hoy,
      ),
      isNull,
    );
  });

  test('un guardia no puede tomar un turno que ya tiene guardia', () {
    expect(
      ReglasTurnos.motivoNoDisponible(
        vecinoId: 'rosa',
        nacimiento: DateTime(1948),
        patrulleros: const [],
        guardiaVentana: 'elena',
        turnosEnElMes: 0,
        hoy: hoy,
      ),
      'Este turno ya tiene guardia de ventana.',
    );
  });
}
