// Pruebas de la capa de datos: los repositorios convierten el JSON del
// servicio en modelos y guardan una caché.

import 'package:BarrioSeguro/data/repositories/alertas_repository.dart';
import 'package:BarrioSeguro/data/repositories/turnos_repository.dart';
import 'package:BarrioSeguro/data/services/error_del_servidor.dart';
import 'package:BarrioSeguro/data/services/reloj.dart';
import 'package:BarrioSeguro/data/services/simulados/servidor_simulado.dart';
import 'package:BarrioSeguro/data/services/simulados/turnos_service_simulado.dart';
import 'package:BarrioSeguro/domain/models/turno.dart';
import 'package:BarrioSeguro/domain/models/vecino.dart';
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
