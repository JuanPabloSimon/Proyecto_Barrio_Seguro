// Pruebas de la capa de datos: los repositorios convierten el JSON del
// servicio en modelos y guardan una caché.

import 'package:barrio_seguro/data/repositories/alertas_repository.dart';
import 'package:barrio_seguro/data/repositories/turnos_repository.dart';
import 'package:barrio_seguro/data/services/error_del_servidor.dart';
import 'package:barrio_seguro/data/services/reloj.dart';
import 'package:barrio_seguro/data/services/simulados/servidor_simulado.dart';
import 'package:barrio_seguro/data/services/simulados/turnos_service_simulado.dart';
import 'package:barrio_seguro/domain/models/turno.dart';
import 'package:barrio_seguro/domain/models/vecino.dart';
import 'package:flutter_test/flutter_test.dart';

import '../ayudas/falsos.dart';

void main() {
  test(
    'el repositorio de alertas pide una sola vez y después usa la caché',
    () async {
      final servicio = AlertasServiceContador();
      final repositorio = AlertasRepositoryRemoto(service: servicio);

      await repositorio.obtenerAlertas();
      await repositorio.obtenerAlertas();
      expect(servicio.pedidos, 1);

      await repositorio.obtenerAlertas(refrescar: true);
      expect(servicio.pedidos, 2);
    },
  );

  group('Turnos contra el servidor simulado', () {
    late TurnosRepositoryRemoto repositorio;
    final octubre = DateTime(2026, 10);

    setUp(() {
      final servidor = ServidorSimulado(
        reloj: RelojFijo(DateTime(2026, 10, 1, 12)),
        demora: Duration.zero,
      );
      repositorio = TurnosRepositoryRemoto(
        service: TurnosServiceSimulado(servidor),
      );
    });

    test('convierte el JSON en turnos con sus vecinos', () async {
      final turnos = await repositorio.obtenerTurnos(octubre);
      final delNueve = turnos.firstWhere((t) => t.fecha.day == 9);
      expect(
        delNueve.patrulleros.map((v) => v.nombre),
        contains('Clara Medina'),
      );
      expect(delNueve.guardiaVentana?.nombre, 'Ernesto Funes');
    });

    test('el servidor rechaza un tercer turno en el mes', () async {
      final clara = Vecino(
        id: 'clara',
        nombre: 'Clara Medina',
        fechaNacimiento: DateTime(1981),
      );
      // Clara ya tiene el del 9: este es el segundo.
      await repositorio.anotarse(clara, DateTime(2026, 10, 30), Franja.noche);

      await expectLater(
        () => repositorio.anotarse(clara, DateTime(2026, 10, 31), Franja.noche),
        throwsA(isA<ErrorDelServidor>()),
      );
    });

    test('anotarse actualiza la caché del mes', () async {
      final clara = Vecino(
        id: 'clara',
        nombre: 'Clara Medina',
        fechaNacimiento: DateTime(1981),
      );
      await repositorio.obtenerTurnos(octubre);
      await repositorio.anotarse(clara, DateTime(2026, 10, 30), Franja.noche);

      final turnos = await repositorio.obtenerTurnos(octubre);
      final del30 = turnos.firstWhere((t) => t.fecha.day == 30);
      expect(del30.incluye(clara), isTrue);
    });
  });

  group('Rol contra el servidor simulado', () {
    late ServidorSimulado servidor;

    setUp(() {
      servidor = ServidorSimulado(
        reloj: RelojFijo(DateTime(2026, 10, 1, 12)),
        demora: Duration.zero,
      );
    });

    test('la vecina de ejemplo es de la comisión y el resto no', () {
      final clara = servidor.ingresar('261 555-0142', 'x')['vecino'];
      expect(clara['id'], 'clara');
      expect(clara['rol'], 'comision');
      expect(Vecino.fromJson(clara as Map<String, dynamic>).esComision, isTrue);

      // Los 11 vecinos de ejemplo restantes, todos comunes.
      for (final id in [
        'jorge',
        'ana',
        'martin',
        'pedro',
        'laura',
        'sofia',
        'raul',
        'ines',
        'rosa',
        'ernesto',
        'elena',
      ]) {
        final vecino = servidor.actualizarVecino(id, {});
        expect(vecino['rol'], 'vecino', reason: id);
      }
    });

    test('quien se registra queda como vecino aunque mande rol comision', () {
      final sesion = servidor.registrar({
        'nombre': 'Nuevo Vecino',
        'fecha_nacimiento': '1990-01-01',
        'rol': 'comision',
      });
      final vecino = sesion['vecino'] as Map<String, dynamic>;
      expect(vecino['rol'], 'vecino');
      expect(Vecino.fromJson(vecino).rol, RolVecino.vecino);

      // Y queda guardado así: una actualización posterior lo confirma.
      final guardado = servidor.actualizarVecino(vecino['id'] as String, {});
      expect(guardado['rol'], 'vecino');
    });

    test('cambiar el rol en la actualización falla con el mensaje del '
        'servidor', () {
      for (final (id, otroRol) in [('rosa', 'comision'), ('clara', 'vecino')]) {
        expect(
          () => servidor.actualizarVecino(id, {
            'rol': otroRol,
            'nombre': 'Otro Nombre',
          }),
          throwsA(
            isA<ErrorDelServidor>().having(
              (e) => e.mensaje,
              'mensaje',
              'El rol no se puede cambiar desde la app.',
            ),
          ),
          reason: id,
        );
        // Nada cambió.
        final igual = servidor.actualizarVecino(id, {});
        expect(igual['rol'], otroRol == 'comision' ? 'vecino' : 'comision');
        expect(igual['nombre'], isNot('Otro Nombre'));
      }
    });

    test('actualizar con el mismo rol no falla', () {
      final rosa = servidor.actualizarVecino('rosa', {
        'rol': 'vecino',
        'telefono': '261 555-0001',
      });
      expect(rosa['rol'], 'vecino');
      expect(rosa['telefono'], '261 555-0001');

      final clara = servidor.actualizarVecino('clara', {'rol': 'comision'});
      expect(clara['rol'], 'comision');
    });

    /// Todos los vecinos de [turno]: patrulleros y guardia de ventana.
    List<Map<String, dynamic>> vecinosDe(Map<String, dynamic> turno) => [
      ...(turno['patrulleros'] as List).cast<Map<String, dynamic>>(),
      if (turno['guardia_ventana'] != null)
        turno['guardia_ventana'] as Map<String, dynamic>,
    ];

    test('los vecinos de los turnos no traen el rol', () {
      final turnos = servidor.turnosDelMes(2026, 10);
      final delNueve = turnos.firstWhere(
        (t) => t['fecha'] == '2026-10-09' && t['franja'] == 'noche',
      );
      expect(vecinosDe(delNueve).map((v) => v['id']), [
        'clara',
        'sofia',
        'ernesto',
      ]);
      for (final turno in turnos) {
        for (final vecino in vecinosDe(turno)) {
          expect(vecino.containsKey('rol'), isFalse, reason: '${vecino['id']}');
        }
      }

      final anotado = servidor.anotarse('2026-10-30', 'noche', 'clara');
      expect(vecinosDe(anotado).map((v) => v['id']), contains('clara'));
      for (final vecino in vecinosDe(anotado)) {
        expect(vecino.containsKey('rol'), isFalse, reason: '${vecino['id']}');
      }

      final sinClara = servidor.salir('2026-10-09', 'noche', 'clara');
      expect(vecinosDe(sinClara), isNotEmpty);
      for (final vecino in vecinosDe(sinClara)) {
        expect(vecino.containsKey('rol'), isFalse, reason: '${vecino['id']}');
      }
    });

    test('sacar el rol de los turnos no le quita el rol a la vecina', () {
      servidor.turnosDelMes(2026, 10);
      servidor.anotarse('2026-10-30', 'noche', 'clara');

      final clara = servidor.ingresar('261 555-0142', 'x')['vecino'];
      expect(clara['rol'], 'comision');
    });
  });

  test('crear una alerta la agrega al principio de la caché', () async {
    final falsas = AlertasFalsas([alertaDePrueba()]);
    await falsas.crearAlerta(
      categoria: alertaDePrueba().categoria,
      tipo: 'SOS',
      descripcion: '',
      direccion: '',
      ubicacion: alertaDePrueba().ubicacion,
      reportadaPor: 'clara',
    );
    final alertas = await falsas.obtenerAlertas();
    expect(alertas.first.id, startsWith('nueva'));
  });
}
