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

  group('ReglasAlertas', () {
    String letras(int n) => 'a' * n;

    String? motivo({
      String categoria = 'robo',
      String tipo = 'Robo',
      String descripcion = '',
      String direccion = '',
    }) => ReglasAlertas.motivoRechazo(
      categoria: categoria,
      tipo: tipo,
      descripcion: descripcion,
      direccion: direccion,
    );

    test('un título vacío o solo con espacios no pasa', () {
      expect(motivo(tipo: ''), 'Escribí un título para la alerta.');
      expect(motivo(tipo: '   '), 'Escribí un título para la alerta.');
    });

    test('un título de 60 letras pasa y uno de 61 no', () {
      expect(motivo(tipo: letras(60)), isNull);
      expect(
        motivo(tipo: letras(61)),
        'Acortá el título: puede tener hasta 60 letras.',
      );
    });

    test('los espacios de los extremos no cuentan', () {
      expect(ReglasAlertas.largo('  Robo  '), 4);
      expect(motivo(tipo: '   ${letras(60)}   '), isNull);
      expect(motivo(descripcion: ' ${letras(500)} '), isNull);
      expect(motivo(direccion: ' ${letras(120)} '), isNull);
    });

    test('una descripción de 500 letras pasa y una de 501 no', () {
      expect(motivo(descripcion: letras(500)), isNull);
      expect(
        motivo(descripcion: letras(501)),
        'Acortá la descripción: puede tener hasta 500 letras.',
      );
    });

    test('una dirección de 120 letras pasa y una de 121 no', () {
      expect(motivo(direccion: letras(120)), isNull);
      expect(
        motivo(direccion: letras(121)),
        'Acortá la dirección: puede tener hasta 120 letras.',
      );
    });

    test('la descripción y la dirección vacías pasan', () {
      expect(motivo(), isNull);
    });

    test('rechaza arrebato y una categoría inventada y acepta sos', () {
      expect(motivo(categoria: 'arrebato'), 'Elegí qué tipo de alerta es.');
      expect(motivo(categoria: 'inventada'), 'Elegí qué tipo de alerta es.');
      expect(motivo(categoria: ''), 'Elegí qué tipo de alerta es.');
      expect(motivo(categoria: 'sos'), isNull);
      for (final c in ['actividad_sospechosa', 'vehiculo', 'robo', 'ruidos']) {
        expect(motivo(categoria: c), isNull);
      }
      expect(ReglasAlertas.categorias, isNot(contains('arrebato')));
    });

    test('la categoría se revisa antes que el título', () {
      expect(
        motivo(categoria: 'arrebato', tipo: ''),
        'Elegí qué tipo de alerta es.',
      );
    });

    test('los valores del SOS pasan', () {
      expect(
        motivo(
          categoria: 'sos',
          tipo: 'Intento de robo',
          descripcion: 'Un vecino pidió ayuda con el botón SOS.',
          direccion: 'Barrio Soberanía (zona aproximada)',
        ),
        isNull,
      );
    });
  });
}
