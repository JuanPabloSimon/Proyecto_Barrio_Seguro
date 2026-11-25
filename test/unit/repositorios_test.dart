// Pruebas de la capa de datos: los repositorios convierten el JSON del
// servicio en modelos, mantienen un Future con estado y guardan una caché.

import 'dart:async';

import 'package:barrio_seguro/data/repositories/alertas_repository.dart';
import 'package:barrio_seguro/data/repositories/futuro_con_estado.dart';
import 'package:barrio_seguro/data/repositories/turnos_repository.dart';
import 'package:barrio_seguro/data/services/alertas_service.dart';
import 'package:barrio_seguro/data/services/error_del_servidor.dart';
import 'package:barrio_seguro/data/services/reloj.dart';
import 'package:barrio_seguro/data/services/simulados/servidor_simulado.dart';
import 'package:barrio_seguro/data/services/simulados/turnos_service_simulado.dart';
import 'package:barrio_seguro/domain/models/turno.dart';
import 'package:barrio_seguro/domain/models/vecino.dart';
import 'package:flutter_test/flutter_test.dart';

import '../ayudas/falsos.dart';

/// Servicio controlado por un [Completer] para observar el estado `cargando`
/// mientras el [Future] sigue en vuelo.
class _AlertasServiceControlado implements AlertasService {
  int pedidos = 0;
  Completer<List<Map<String, dynamic>>> proximo =
      Completer<List<Map<String, dynamic>>>();

  @override
  Future<List<Map<String, dynamic>>> obtenerAlertas() {
    pedidos++;
    return proximo.future;
  }

  @override
  Future<Map<String, dynamic>> crearAlerta(Map<String, dynamic> datos) async =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> cambiarEstado(String id, String estado) async =>
      throw UnimplementedError();
}

void main() {
  test(
    'el repositorio de alertas pide una sola vez y después usa la caché',
    () async {
      final servicio = AlertasServiceContador();
      final repositorio = AlertasRepositoryRemoto(service: servicio);

      expect(repositorio.estado, EstadoFuturo.inicial);
      await repositorio.obtenerAlertas();
      expect(repositorio.estado, EstadoFuturo.exito);
      await repositorio.obtenerAlertas();
      expect(servicio.pedidos, 1);

      await repositorio.obtenerAlertas(refrescar: true);
      expect(servicio.pedidos, 2);
    },
  );

  group('Future con estado en repositorios', () {
    test(
      'transiciona inicial -> cargando -> exito y comparte el Future en vuelo',
      () async {
        final servicio = _AlertasServiceControlado();
        final repositorio = AlertasRepositoryRemoto(service: servicio);

        expect(repositorio.estado, EstadoFuturo.inicial);
        expect(repositorio.pedido.enCurso, isNull);

        // Dos pantallas piden las alertas al mismo tiempo mientras sigue
        // cargando.
        final primero = repositorio.obtenerAlertas();
        final segundo = repositorio.obtenerAlertas();

        expect(repositorio.estado, EstadoFuturo.cargando);
        expect(repositorio.pedido.cargando, isTrue);
        expect(repositorio.pedido.enCurso, isNotNull);
        expect(identical(primero, segundo), isTrue);
        expect(servicio.pedidos, 1);

        servicio.proximo.complete([alertaDePrueba().toJson()]);
        final resultados = await Future.wait([primero, segundo]);

        expect(repositorio.estado, EstadoFuturo.exito);
        expect(repositorio.pedido.enCurso, isNull);
        expect(resultados[0].single.id, 'a1');
        expect(resultados[1].single.id, 'a1');
      },
    );

    test('si el pedido falla sin copia local, pasa a estado error y permite reintentar', () async {
      final servicio = AlertasServiceContador()..falla = true;
      final repositorio = AlertasRepositoryRemoto(service: servicio);

      await expectLater(repositorio.obtenerAlertas(), throwsException);
      expect(repositorio.estado, EstadoFuturo.error);
      expect(repositorio.pedido.error, isNotNull);

      servicio.falla = false;
      final alertas = await repositorio.obtenerAlertas();
      expect(repositorio.estado, EstadoFuturo.exito);
      expect(repositorio.pedido.error, isNull);
      expect(alertas, hasLength(1));
    });

    test(
      'TurnosRepositoryRemoto mantiene un Future con estado por cada mes',
      () async {
        final octubre = DateTime(2026, 10);
        final servidor = ServidorSimulado(
          reloj: RelojFijo(DateTime(2026, 10, 1, 12)),
          demora: const Duration(milliseconds: 20),
        );
        final repositorio = TurnosRepositoryRemoto(
          service: TurnosServiceSimulado(servidor),
        );

        expect(repositorio.estadoDelMes(octubre), EstadoFuturo.inicial);

        final p1 = repositorio.obtenerTurnos(octubre);
        final p2 = repositorio.obtenerTurnos(octubre);
        expect(repositorio.estadoDelMes(octubre), EstadoFuturo.cargando);
        expect(identical(p1, p2), isTrue);

        await Future.wait([p1, p2]);
        expect(repositorio.estadoDelMes(octubre), EstadoFuturo.exito);
      },
    );
  });

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
