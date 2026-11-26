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
        guardiaNormal: false,
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
        guardiaNormal: false,
        patrulleros: const [],
        guardiaVentana: 'elena',
        turnosEnElMes: 0,
        hoy: hoy,
      ),
      'Este turno ya tiene guardia de ventana.',
    );
  });

  group('Guardia normal', () {
    final rosa = DateTime(1948, 7, 8);
    final clara = DateTime(1981, 5, 14);

    String? motivo({
      required DateTime nacimiento,
      required bool guardiaNormal,
      List<String> patrulleros = const [],
      String? guardiaVentana,
      int turnosEnElMes = 0,
    }) => ReglasTurnos.motivoNoDisponible(
      vecinoId: 'rosa',
      nacimiento: nacimiento,
      guardiaNormal: guardiaNormal,
      patrulleros: patrulleros,
      guardiaVentana: guardiaVentana,
      turnosEnElMes: turnosEnElMes,
      hoy: hoy,
    );

    test('un mayor sin guardia normal es guardia de ventana', () {
      expect(
        ReglasTurnos.haceGuardiaVentana(rosa, hoy, guardiaNormal: false),
        isTrue,
      );
      // Por eso choca con la guardia ocupada y no con la patrulla completa.
      expect(
        motivo(nacimiento: rosa, guardiaNormal: false, guardiaVentana: 'elena'),
        'Este turno ya tiene guardia de ventana.',
      );
      expect(
        motivo(
          nacimiento: rosa,
          guardiaNormal: false,
          patrulleros: ['jorge', 'ana'],
        ),
        isNull,
      );
    });

    test('un mayor con guardia normal es patrullero', () {
      expect(
        ReglasTurnos.haceGuardiaVentana(rosa, hoy, guardiaNormal: true),
        isFalse,
      );
      expect(
        motivo(nacimiento: rosa, guardiaNormal: true, guardiaVentana: 'elena'),
        isNull,
      );
    });

    test('un menor es patrullero con o sin guardia normal', () {
      for (final guardiaNormal in [true, false]) {
        expect(
          ReglasTurnos.haceGuardiaVentana(
            clara,
            hoy,
            guardiaNormal: guardiaNormal,
          ),
          isFalse,
        );
        expect(
          motivo(
            nacimiento: clara,
            guardiaNormal: guardiaNormal,
            patrulleros: ['jorge', 'ana'],
          ),
          'La patrulla de este turno ya está completa.',
        );
      }
    });

    test('a los 70 se puede elegir la guardia normal y a los 69 no', () {
      expect(
        ReglasTurnos.puedeElegirGuardiaNormal(DateTime(1956, 10, 1), hoy),
        isTrue,
      );
      expect(
        ReglasTurnos.puedeElegirGuardiaNormal(DateTime(1956, 10, 2), hoy),
        isFalse,
      );
    });

    test('un mayor con guardia normal choca con la patrulla completa aunque '
        'la guardia esté libre', () {
      expect(
        motivo(
          nacimiento: rosa,
          guardiaNormal: true,
          patrulleros: ['jorge', 'ana'],
        ),
        'La patrulla de este turno ya está completa.',
      );
    });

    test('un mayor con guardia normal y 2 turnos en el mes choca con el '
        'máximo', () {
      expect(
        motivo(nacimiento: rosa, guardiaNormal: true, turnosEnElMes: 2),
        'Ya tenés 2 turnos este mes, que es el máximo permitido.',
      );
    });

    test('los mensajes son los mismos que en la app', () {
      // Mismos textos que ReglasTurnos de lib/domain/reglas_turnos.dart.
      expect(
        ReglasTurnos.mensajeGuardiaNormalSoloMayores,
        'Solo los vecinos de 70 años o más pueden elegir la guardia normal.',
      );
      expect(
        ReglasTurnos.mensajeGuardiaNormalInvalida,
        'La opción de guardia normal no es válida.',
      );
    });
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

  group('ReglasAlertas.puedeCambiarEstado', () {
    test('quien la reportó puede', () {
      expect(
        ReglasAlertas.puedeCambiarEstado(
          reportadaPor: 'rosa',
          vecinoId: 'rosa',
          rol: 'vecino',
        ),
        isTrue,
      );
    });

    test('la comisión puede aunque no la haya reportado', () {
      expect(
        ReglasAlertas.puedeCambiarEstado(
          reportadaPor: 'martin',
          vecinoId: 'clara',
          rol: 'comision',
        ),
        isTrue,
      );
    });

    test('un vecino común no puede si no la reportó', () {
      expect(
        ReglasAlertas.puedeCambiarEstado(
          reportadaPor: 'clara',
          vecinoId: 'rosa',
          rol: 'vecino',
        ),
        isFalse,
      );
    });

    test('sin rol conocido no puede si no la reportó', () {
      expect(
        ReglasAlertas.puedeCambiarEstado(
          reportadaPor: 'clara',
          vecinoId: 'nadie',
          rol: null,
        ),
        isFalse,
      );
    });

    test('el mensaje es el mismo que el de la app', () {
      expect(
        ReglasAlertas.mensajeSinPermisoEstado,
        'Solo quien reportó la alerta o la comisión vecinal pueden cambiar '
        'su estado.',
      );
    });
  });
}
