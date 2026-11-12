// Pruebas de los ViewModels con repositorios falsos: sin servidor, sin
// widgets y con un reloj fijo, así los resultados no dependen del día.

import 'package:BarrioSeguro/data/services/bus_de_eventos.dart';
import 'package:BarrioSeguro/data/services/reloj.dart';
import 'package:BarrioSeguro/domain/evento_de_app.dart';
import 'package:BarrioSeguro/domain/models/alerta.dart';
import 'package:BarrioSeguro/domain/models/turno.dart';
import 'package:BarrioSeguro/ui/alerta_detalle/view_models/detalle_alerta_view_model.dart';
import 'package:BarrioSeguro/ui/core/estado_carga.dart';
import 'package:BarrioSeguro/ui/mapa/view_models/mapa_view_model.dart';
import 'package:BarrioSeguro/ui/registro/view_models/registro_view_model.dart';
import 'package:BarrioSeguro/ui/sos/view_models/sos_view_model.dart';
import 'package:BarrioSeguro/ui/turnos/view_models/turnos_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../ayudas/falsos.dart';

void main() {
  final reloj = RelojFijo(DateTime(2026, 10, 1, 12));
  late BusDeEventos bus;

  setUp(() => bus = BusDeEventos());
  tearDown(() => bus.cerrar());

  group('RegistroViewModel', () {
    RegistroViewModel crear() =>
        RegistroViewModel(sesion: SesionFalsa(), reloj: reloj);

    test('con 76 años avisa que será guardia de ventana', () {
      final vm = crear()..cambiarFecha('14/05/1950');
      expect(vm.edad, 76);
      expect(vm.seraGuardiaVentana, isTrue);
      expect(vm.errorFecha, isNull);
    });

    test('con 45 años será patrullero', () {
      final vm = crear()..cambiarFecha('14/05/1981');
      expect(vm.seraGuardiaVentana, isFalse);
    });

    test('una fecha imposible muestra un error con un ejemplo', () {
      final vm = crear()..cambiarFecha('31/02/1990');
      expect(vm.edad, isNull);
      expect(vm.errorFecha, contains('14/05/1950'));
    });

    test('avisa a la vista cada vez que cambia', () {
      final vm = crear();
      var avisos = 0;
      vm.addListener(() => avisos++);
      vm
        ..cambiarNombre('Ana')
        ..cambiarFecha('01/01/1990');
      expect(avisos, 2);
    });
  });

  group('MapaViewModel', () {
    MapaViewModel crear(AlertasFalsas alertas) =>
        MapaViewModel(alertas: alertas, bus: bus, reloj: reloj);

    test('carga las alertas y las filtra por estado', () async {
      final vm = crear(
        AlertasFalsas([
          alertaDePrueba(id: 'a', estado: EstadoAlerta.activa),
          alertaDePrueba(id: 'b', estado: EstadoAlerta.resuelta),
        ]),
      );
      await vm.cargar();
      expect(vm.estado, EstadoCarga.exito);
      expect(vm.visibles, hasLength(2));

      vm.elegirFiltro(EstadoAlerta.resuelta);
      expect(vm.visibles.map((a) => a.id), ['b']);

      vm.elegirFiltro(null);
      expect(vm.visibles, hasLength(2));
    });

    test('sin conexión queda en estado de error', () async {
      final vm = crear(AlertasFalsas([], true));
      await vm.cargar();
      expect(vm.estado, EstadoCarga.error);
    });

    test('la lista que expone no se puede modificar desde la vista', () async {
      final vm = crear(AlertasFalsas([alertaDePrueba()]));
      await vm.cargar();
      expect(() => vm.visibles.clear(), throwsUnsupportedError);
    });

    test(
      'se recarga sola cuando otra pantalla avisa que cambiaron las alertas',
      () async {
        final alertas = AlertasFalsas([alertaDePrueba()]);
        final vm = crear(alertas);
        await vm.cargar();
        expect(alertas.pedidos, 1);

        bus.publicar(const AlertasActualizadas());
        await Future<void>.delayed(Duration.zero);
        expect(alertas.pedidos, 2);
        vm.dispose();
      },
    );

    test('al cerrarse deja de escuchar el bus', () {
      final vm = crear(AlertasFalsas());
      expect(bus.tieneOyentes, isTrue);
      vm.dispose();
      expect(bus.tieneOyentes, isFalse);
    });
  });

  group('SosViewModel', () {
    test('enviar crea una alerta SOS y avisa al resto de la app', () async {
      final alertas = AlertasFalsas();
      final vm = SosViewModel(
        alertas: alertas,
        sesion: SesionFalsa(vecinaDePrueba),
        bus: bus,
      );
      final eventos = <Object>[];
      bus.eventos.listen(eventos.add);

      expect(vm.paso, PasoSos.confirmar);
      await vm.enviar();
      await Future<void>.delayed(Duration.zero);

      expect(vm.paso, PasoSos.enviada);
      expect(alertas.alertas, hasLength(1));
      expect(alertas.alertas.first.reportadaPor, 'clara');
      expect(eventos.single, isA<AlertasActualizadas>());
    });

    test('sin conexión pasa al paso de error', () async {
      final vm = SosViewModel(
        alertas: AlertasFalsas([], true),
        sesion: SesionFalsa(vecinaDePrueba),
        bus: bus,
      );
      await vm.enviar();
      expect(vm.paso, PasoSos.error);
    });

    test('"Ya estoy a salvo" deja la alerta resuelta', () async {
      final alertas = AlertasFalsas();
      final vm = SosViewModel(
        alertas: alertas,
        sesion: SesionFalsa(vecinaDePrueba),
        bus: bus,
      );
      await vm.enviar();
      expect(await vm.cerrarAlerta(), isTrue);
      expect(alertas.alertas.first.estado, EstadoAlerta.resuelta);
    });
  });

  group('DetalleAlertaViewModel', () {
    DetalleAlertaViewModel crear(Alerta alerta, AlertasFalsas alertas) =>
        DetalleAlertaViewModel(
          alerta: alerta,
          alertas: alertas,
          sesion: SesionFalsa(vecinaDePrueba),
          bus: bus,
          reloj: reloj,
        );

    test('solo quien la reportó puede cerrarla', () {
      final mia = alertaDePrueba(reportadaPor: 'clara');
      final ajena = alertaDePrueba(reportadaPor: 'jorge');
      expect(crear(mia, AlertasFalsas([mia])).puedeCerrarla, isTrue);
      expect(crear(ajena, AlertasFalsas([ajena])).puedeCerrarla, isFalse);
    });

    test('marcarla resuelta cambia su estado de verdad', () async {
      final alerta = alertaDePrueba();
      final alertas = AlertasFalsas([alerta]);
      final vm = crear(alerta, alertas);

      expect(await vm.marcarResuelta(), isTrue);
      expect(vm.alerta.estado, EstadoAlerta.resuelta);
      expect(alertas.alertas.single.estado, EstadoAlerta.resuelta);
      expect(vm.puedeCerrarla, isFalse);
    });

    test('si falla muestra un mensaje y la alerta sigue abierta', () async {
      final alerta = alertaDePrueba();
      final vm = crear(alerta, AlertasFalsas([alerta], true));

      expect(await vm.marcarResuelta(), isFalse);
      expect(vm.estado, EstadoCarga.error);
      expect(vm.error, isNotNull);
      expect(vm.alerta.estado, EstadoAlerta.activa);
    });

    test('el tiempo transcurrido usa el reloj inyectado', () {
      final alerta = alertaDePrueba(); // creada a las 11:55
      expect(crear(alerta, AlertasFalsas([alerta])).hace, 'Hace 5 minutos');
    });
  });

  group('TurnosViewModel', () {
    final octubre = DateTime(2026, 10);

    TurnosViewModel crear(TurnosFalsos turnos) => TurnosViewModel(
      turnos: turnos,
      sesion: SesionFalsa(vecinaDePrueba),
      bus: bus,
      reloj: reloj,
      mes: octubre,
    );

    test('el calendario abre en el primer turno propio', () async {
      final vm = crear(
        TurnosFalsos([
          Turno(
            fecha: DateTime(2026, 10, 9),
            franja: Franja.noche,
            patrulleros: [vecinaDePrueba],
          ),
        ]),
      );
      await vm.cargar();
      expect(vm.dia, DateTime(2026, 10, 9));
      expect(vm.misTurnos, hasLength(1));
    });

    test('con dos turnos en el mes no deja tomar un tercero', () async {
      final vm = crear(
        TurnosFalsos([
          for (final dia in [9, 16])
            Turno(
              fecha: DateTime(2026, 10, dia),
              franja: Franja.noche,
              patrulleros: [vecinaDePrueba],
            ),
        ]),
      );
      await vm.cargar();
      final libre = vm.turno(DateTime(2026, 10, 23), Franja.noche);
      expect(vm.motivoNoDisponible(libre), contains('máximo'));
    });

    test('anotarse devuelve el mensaje de éxito y avisa por el bus', () async {
      final turnos = TurnosFalsos();
      final vm = crear(turnos);
      await vm.cargar();
      final eventos = <Object>[];
      bus.eventos.listen(eventos.add);

      final mensaje = await vm.anotarse(
        vm.turno(DateTime(2026, 10, 23), Franja.noche),
      );
      await Future<void>.delayed(Duration.zero);

      expect(mensaje, startsWith('Te anotaste'));
      expect(vm.misTurnos, hasLength(1));
      expect(vm.ocupado, isFalse);
      expect(eventos, contains(isA<TurnosActualizados>()));
      vm.dispose();
    });

    test(
      'sin conexión devuelve un mensaje claro y no se queda ocupado',
      () async {
        final turnos = TurnosFalsos();
        final vm = crear(turnos);
        await vm.cargar();
        turnos.falla = true;

        final mensaje = await vm.anotarse(
          vm.turno(DateTime(2026, 10, 23), Franja.noche),
        );
        expect(mensaje, contains('conexión'));
        expect(vm.ocupado, isFalse);
      },
    );

    test('"Mis turnos" vuelve al calendario en el día elegido', () {
      final vm = crear(TurnosFalsos())..mostrarSoloMios(true);
      vm.verEnCalendario(DateTime(2026, 10, 9));
      expect(vm.soloMios, isFalse);
      expect(vm.dia, DateTime(2026, 10, 9));
    });
  });
}
