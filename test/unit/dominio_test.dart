// Pruebas de la capa de dominio: reglas y cálculos puros, sin Flutter.

import 'package:barrio_seguro/domain/avisos_tardios.dart';
import 'package:barrio_seguro/domain/fechas.dart';
import 'package:barrio_seguro/domain/informe_alertas.dart';
import 'package:barrio_seguro/domain/models/alerta.dart';
import 'package:barrio_seguro/domain/models/turno.dart';
import 'package:barrio_seguro/domain/models/vecino.dart';
import 'package:barrio_seguro/domain/reglas_alertas.dart';
import 'package:barrio_seguro/domain/reglas_turnos.dart';
import 'package:barrio_seguro/ui/core/formato.dart';
import 'package:barrio_seguro/ui/sos/view_models/sos_view_model.dart';
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

    final mayorConGuardiaNormal = Vecino.fromJson({
      ...vecinoMayor.toJson(),
      'guardia_normal': true,
    });
    final menorConGuardiaNormal = Vecino.fromJson({
      ...vecinaDePrueba.toJson(),
      'guardia_normal': true,
    });

    test('un mayor sin guardia normal es guardia de ventana', () {
      expect(vecinoMayor.guardiaNormal, isFalse);
      expect(vecinoMayor.esGuardiaVentanaEn(hoy), isTrue);
      expect(
        ReglasTurnos.haceGuardiaVentana(edad: 78, guardiaNormal: false),
        isTrue,
      );
    });

    test('un mayor con guardia normal es patrullero', () {
      expect(mayorConGuardiaNormal.esGuardiaVentanaEn(hoy), isFalse);
      expect(
        ReglasTurnos.haceGuardiaVentana(edad: 78, guardiaNormal: true),
        isFalse,
      );
    });

    test('un menor es patrullero con o sin guardia normal', () {
      expect(vecinaDePrueba.esGuardiaVentanaEn(hoy), isFalse);
      expect(menorConGuardiaNormal.esGuardiaVentanaEn(hoy), isFalse);
      for (final guardiaNormal in [true, false]) {
        expect(
          ReglasTurnos.haceGuardiaVentana(
            edad: 45,
            guardiaNormal: guardiaNormal,
          ),
          isFalse,
        );
      }
    });

    test('a los 70 años se puede elegir la guardia normal y a los 69 no', () {
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
      expect(cumple70.puedeElegirGuardiaNormalEn(hoy), isTrue);
      expect(cumple70Manana.puedeElegirGuardiaNormalEn(hoy), isFalse);
      expect(ReglasTurnos.puedeElegirGuardiaNormal(70), isTrue);
      expect(ReglasTurnos.puedeElegirGuardiaNormal(69), isFalse);
    });

    test('un mayor con guardia normal choca con la patrulla completa aunque '
        'la guardia esté libre', () {
      final lleno = Turno(
        fecha: DateTime(2026, 10, 9),
        franja: Franja.noche,
        patrulleros: [
          Vecino(id: 'a', nombre: 'A', fechaNacimiento: DateTime(1990)),
          Vecino(id: 'b', nombre: 'B', fechaNacimiento: DateTime(1990)),
        ],
      );
      final motivo = ReglasTurnos.motivoNoDisponible(
        vecino: mayorConGuardiaNormal,
        turno: lleno,
        turnosEnElMes: 0,
        hoy: hoy,
      );
      expect(motivo, 'La patrulla de este turno ya está completa.');
    });

    test('un mayor con guardia normal puede anotarse en un turno con guardia '
        'ocupada y lugar en la patrulla', () {
      final conGuardia = Turno(
        fecha: DateTime(2026, 10, 9),
        franja: Franja.noche,
        patrulleros: [
          Vecino(id: 'a', nombre: 'A', fechaNacimiento: DateTime(1990)),
        ],
        guardiaVentana: Vecino(
          id: 'g',
          nombre: 'G',
          fechaNacimiento: DateTime(1940),
        ),
      );
      final motivo = ReglasTurnos.motivoNoDisponible(
        vecino: mayorConGuardiaNormal,
        turno: conGuardia,
        turnosEnElMes: 0,
        hoy: hoy,
      );
      expect(motivo, isNull);
    });

    test('un mayor con guardia normal y 2 turnos en el mes choca con el '
        'máximo', () {
      final motivo = ReglasTurnos.motivoNoDisponible(
        vecino: mayorConGuardiaNormal,
        turno: turnoVacio,
        turnosEnElMes: 2,
        hoy: hoy,
      );
      expect(motivo, 'Ya tenés 2 turnos este mes, que es el máximo permitido.');
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

  group('Marca de alerta tardía', () {
    test(
      'marca de una alerta de hoy: "Llegó con demora. Alerta de las 15:10"',
      () {
        expect(
          marcaTardia(
            creadaEn: DateTime(2026, 11, 25, 15, 10),
            ahora: DateTime(2026, 11, 25, 18),
          ),
          'Llegó con demora. Alerta de las 15:10',
        );
        expect(
          marcaTardia(
            creadaEn: DateTime(2026, 11, 25, 9, 5),
            ahora: DateTime(2026, 11, 25, 9, 30),
          ),
          'Llegó con demora. Alerta de las 09:05',
        );
      },
    );

    test('marca de una alerta de otro día: "Llegó con demora. Alerta del 24/11 a las 23:50"', () {
      expect(
        marcaTardia(
          creadaEn: DateTime(2026, 11, 24, 23, 50),
          ahora: DateTime(2026, 11, 25, 0, 30),
        ),
        'Llegó con demora. Alerta del 24/11 a las 23:50',
      );
      // Mismo día y mes, pero de otro año: lleva fecha.
      expect(
        marcaTardia(
          creadaEn: DateTime(2025, 11, 25, 8),
          ahora: DateTime(2026, 11, 25, 9),
        ),
        'Llegó con demora. Alerta del 25/11 a las 08:00',
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

    test('reportada_por_nombre viaja en el JSON', () {
      final original = alertaDePrueba(
        reportadaPor: 'marta',
        reportadaPorNombre: 'Marta',
      );
      final json = original.toJson();
      expect(json['reportada_por_nombre'], 'Marta');
      expect(Alerta.fromJson(json).reportadaPorNombre, 'Marta');
    });

    test('una alerta sin reportada_por_nombre lo toma vacío', () {
      final json = alertaDePrueba().toJson()..remove('reportada_por_nombre');
      expect(Alerta.fromJson(json).reportadaPorNombre, '');
      expect(
        Alerta.fromJson({...json, 'reportada_por_nombre': null})
            .reportadaPorNombre,
        '',
      );
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

    test('guardia_normal true se lee como activada', () {
      final vecino = Vecino.fromJson({...jsonDeVecino, 'guardia_normal': true});
      expect(vecino.guardiaNormal, isTrue);
    });

    test('sin guardia_normal o con un valor que no es true queda '
        'desactivada', () {
      final sinCampo = Vecino.fromJson({...jsonDeVecino});
      final texto = Vecino.fromJson({...jsonDeVecino, 'guardia_normal': 'si'});
      final numero = Vecino.fromJson({...jsonDeVecino, 'guardia_normal': 1});
      final falso = Vecino.fromJson({...jsonDeVecino, 'guardia_normal': false});
      for (final v in [sinCampo, texto, numero, falso]) {
        expect(v.guardiaNormal, isFalse);
      }
    });

    test('guardia_normal viaja en el JSON, ida y vuelta', () {
      for (final valor in [true, false]) {
        final original = Vecino(
          id: 'v1',
          nombre: 'Rosa Ibáñez',
          fechaNacimiento: DateTime(1948, 7, 8),
          guardiaNormal: valor,
        );
        final json = original.toJson();
        expect(json['guardia_normal'], valor);
        expect(Vecino.fromJson(json).guardiaNormal, valor);
      }
    });

    test('copyWith conserva la guardia normal', () {
      for (final valor in [true, false]) {
        final original = Vecino(
          id: 'v1',
          nombre: 'Rosa Ibáñez',
          fechaNacimiento: DateTime(1948, 7, 8),
          guardiaNormal: valor,
        );
        final copia = original.copyWith(nombre: 'Rosa I.', calle: 'Otra');
        expect(copia.guardiaNormal, valor);
        expect(copia.toJson()['guardia_normal'], valor);
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

  group('Tipos para reportar', () {
    test('los tipos para reportar son actividad sospechosa, vehículo, robo y '
        'ruidos, en ese orden y sin arrebato', () {
      expect(CategoriaAlerta.paraReportar, [
        CategoriaAlerta.actividadSospechosa,
        CategoriaAlerta.vehiculo,
        CategoriaAlerta.robo,
        CategoriaAlerta.ruidos,
      ]);
      expect(
        CategoriaAlerta.paraReportar,
        isNot(contains(CategoriaAlerta.arrebato)),
      );
      expect(CategoriaAlerta.paraReportar.map((c) => c.nombreCorto), [
        'Actividad sospechosa',
        'Vehículo sospechoso',
        'Robo',
        'Ruidos',
      ]);
    });

    test('una alerta de arrebato de la API se lee como arrebato', () {
      final json = alertaDePrueba(
        categoria: CategoriaAlerta.arrebato,
        tipo: 'Arrebato',
      ).toJson();
      expect(json['categoria'], 'arrebato');

      final deLaApi = Alerta.fromJson(json);
      expect(deLaApi.categoria, CategoriaAlerta.arrebato);
      expect(deLaApi.tipo, 'Arrebato');

      final deLaCopiaLocal = Alerta.fromMap(deLaApi.toMap());
      expect(deLaCopiaLocal.categoria, CategoriaAlerta.arrebato);
      expect(deLaCopiaLocal.tipo, 'Arrebato');
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
      expect(
        ReglasAlertas.errorTitulo(''),
        'Escribí un título para la alerta.',
      );
      expect(
        ReglasAlertas.errorTitulo('   '),
        'Escribí un título para la alerta.',
      );
      expect(motivo(tipo: '  '), 'Escribí un título para la alerta.');
    });

    test('un título de 60 letras pasa y uno de 61 no', () {
      expect(ReglasAlertas.errorTitulo(letras(60)), isNull);
      expect(
        ReglasAlertas.errorTitulo(letras(61)),
        'Acortá el título: puede tener hasta 60 letras.',
      );
      expect(
        motivo(tipo: letras(61)),
        'Acortá el título: puede tener hasta 60 letras.',
      );
    });

    test('los espacios de los extremos no cuentan', () {
      expect(ReglasAlertas.largo('  Robo  '), 4);
      expect(ReglasAlertas.errorTitulo('   ${letras(60)}   '), isNull);
      expect(ReglasAlertas.errorDescripcion(' ${letras(500)} '), isNull);
      expect(ReglasAlertas.errorDireccion(' ${letras(120)} '), isNull);
    });

    test('una descripción de 500 letras pasa y una de 501 no', () {
      expect(ReglasAlertas.errorDescripcion(letras(500)), isNull);
      expect(
        ReglasAlertas.errorDescripcion(letras(501)),
        'Acortá la descripción: puede tener hasta 500 letras.',
      );
      expect(
        motivo(descripcion: letras(501)),
        'Acortá la descripción: puede tener hasta 500 letras.',
      );
    });

    test('una dirección de 120 letras pasa y una de 121 no', () {
      expect(ReglasAlertas.errorDireccion(letras(120)), isNull);
      expect(
        ReglasAlertas.errorDireccion(letras(121)),
        'Acortá la dirección: puede tener hasta 120 letras.',
      );
      expect(
        motivo(direccion: letras(121)),
        'Acortá la dirección: puede tener hasta 120 letras.',
      );
    });

    test('la descripción y la dirección vacías pasan', () {
      expect(ReglasAlertas.errorDescripcion(''), isNull);
      expect(ReglasAlertas.errorDireccion(''), isNull);
      expect(motivo(), isNull);
    });

    test(
      'motivoRechazo rechaza arrebato y una categoría inventada y acepta sos',
      () {
        expect(motivo(categoria: 'arrebato'), 'Elegí qué tipo de alerta es.');
        expect(motivo(categoria: 'inventada'), 'Elegí qué tipo de alerta es.');
        expect(motivo(categoria: ''), 'Elegí qué tipo de alerta es.');
        expect(motivo(categoria: 'sos'), isNull);
        for (final c in CategoriaAlerta.paraReportar) {
          expect(motivo(categoria: c.valorApi), isNull);
        }
      },
    );

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
          tipo: tipoAlertaSos,
          descripcion: descripcionAlertaSos,
          direccion: 'Barrio Soberanía (zona aproximada)',
        ),
        isNull,
      );
    });
  });

  test('tituloConCategoria antepone "SOS: " solo a las alertas sos', () {
    expect(
      alertaDePrueba(categoria: CategoriaAlerta.sos).tituloConCategoria,
      'SOS: Intento de robo',
    );
    expect(
      alertaDePrueba(categoria: CategoriaAlerta.robo).tituloConCategoria,
      'Intento de robo',
    );
  });

  group('Informe de alertas', () {
    Alerta crearAlerta({
      required String id,
      required DateTime fecha,
      String direccion = 'Calle Plantamura',
      String tipo = 'Intento de robo',
      CategoriaAlerta categoria = CategoriaAlerta.robo,
    }) {
      return Alerta(
        id: id,
        categoria: categoria,
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

    List<String> porTipo(InformeAlertas informe) =>
        informe.porTipo.map((f) => '${f.nombre}:${f.cantidad}').toList();

    test('cuenta todos los SOS en una sola fila "SOS"', () {
      final dia = DateTime(2026, 10, 3, 10);
      final informe = InformeAlertas.delMes(
        alertas: [
          crearAlerta(id: '1', fecha: dia, categoria: CategoriaAlerta.sos),
          crearAlerta(
            id: '2',
            fecha: dia,
            categoria: CategoriaAlerta.sos,
            tipo: 'Pedido de ayuda (SOS)',
          ),
          crearAlerta(id: '3', fecha: dia),
          crearAlerta(id: '4', fecha: dia),
        ],
        mes: octubre,
      );

      expect(porTipo(informe), ['Intento de robo:2', 'SOS:2']);
      expect(informe.total, 4);
    });

    test('un robo titulado "SOS" no se suma a la fila de los SOS', () {
      final dia = DateTime(2026, 10, 3, 10);
      final informe = InformeAlertas.delMes(
        alertas: [
          crearAlerta(id: '1', fecha: dia, categoria: CategoriaAlerta.sos),
          crearAlerta(id: '2', fecha: dia, tipo: 'SOS'),
          crearAlerta(id: '3', fecha: dia, tipo: ' sos '),
          crearAlerta(id: '4', fecha: dia, tipo: 'Pedido de ayuda (SOS)'),
        ],
        mes: octubre,
      );

      expect(porTipo(informe), [
        'Pedido de ayuda (SOS):1',
        'SOS:1',
        'SOS (Robo):1',
        'sos (Robo):1',
      ]);
    });

    test('el CSV trae una sola fila de los SOS', () {
      final dia = DateTime(2026, 10, 3, 10);
      final csv = InformeAlertas.delMes(
        alertas: [
          crearAlerta(id: '1', fecha: dia, categoria: CategoriaAlerta.sos),
          crearAlerta(
            id: '2',
            fecha: dia,
            categoria: CategoriaAlerta.sos,
            tipo: 'Pedido de ayuda (SOS)',
          ),
        ],
        mes: octubre,
      ).toCsv();

      expect(csv, contains('Por tipo,SOS,2'));
      expect(csv, isNot(contains('Por tipo,SOS: ')));
      expect(csv, isNot(contains('Por tipo,Intento de robo')));
    });
  });

  group('ReglasAlertas.puedeCambiarEstado', () {
    test('quien la reportó puede', () {
      expect(
        ReglasAlertas.puedeCambiarEstado(
          reportadaPor: 'clara',
          vecino: vecinaDePrueba,
        ),
        isTrue,
      );
    });

    test('la comisión puede aunque no la haya reportado', () {
      expect(
        ReglasAlertas.puedeCambiarEstado(
          reportadaPor: 'jorge',
          vecino: miembroDeLaComision,
        ),
        isTrue,
      );
    });

    test('un vecino común no puede si no la reportó', () {
      expect(vecinaDePrueba.rol, RolVecino.vecino);
      expect(
        ReglasAlertas.puedeCambiarEstado(
          reportadaPor: 'jorge',
          vecino: vecinaDePrueba,
        ),
        isFalse,
      );
    });

    test('sin sesión no puede', () {
      expect(
        ReglasAlertas.puedeCambiarEstado(reportadaPor: 'clara', vecino: null),
        isFalse,
      );
    });

    test('el mensaje es el mismo que el del servidor', () {
      expect(
        ReglasAlertas.mensajeSinPermisoEstado,
        'Solo quien reportó la alerta o la comisión vecinal pueden cambiar '
        'su estado.',
      );
    });
  });

  group('Textos del aviso de reapertura', () {
    test('el título dice "Se reabrió una alerta: Robo"', () {
      expect(
        tituloAvisoReapertura(alertaDePrueba(categoria: CategoriaAlerta.robo)),
        'Se reabrió una alerta: Robo',
      );
    });

    test('en un SOS dice "Se reabrió una alerta: SOS"', () {
      expect(
        tituloAvisoReapertura(alertaDePrueba(categoria: CategoriaAlerta.sos)),
        'Se reabrió una alerta: SOS',
      );
    });

    test('el título tardío agrega la hora de la reapertura '
        '("Se reabrió una alerta: Robo 15:10")', () {
      expect(
        tituloAvisoReaperturaTardia(
          alertaDePrueba(categoria: CategoriaAlerta.robo),
          DateTime(2026, 10, 1, 15, 10),
        ),
        'Se reabrió una alerta: Robo 15:10',
      );
    });

    test('el cuerpo dice "<dirección>. Tocá para ver dónde."', () {
      expect(
        cuerpoAvisoReapertura(alertaDePrueba(direccion: 'Calle Plantamura')),
        'Calle Plantamura. Tocá para ver dónde.',
      );
    });

    test('sin dirección el cuerpo dice "Tocá para ver dónde."', () {
      expect(
        cuerpoAvisoReapertura(alertaDePrueba(direccion: '  ')),
        'Tocá para ver dónde.',
      );
    });
  });
}
