// Pruebas de los avisos de alertas nuevas, con la app abierta (vigilante)
// y con la app cerrada (push).

import 'package:barrio_seguro/data/services/bus_de_eventos.dart';
import 'package:barrio_seguro/data/services/local/preferencias.dart';
import 'package:barrio_seguro/data/services/push_service.dart';
import 'package:barrio_seguro/domain/evento_de_app.dart';
import 'package:barrio_seguro/domain/models/alerta.dart';
import 'package:barrio_seguro/ui/perfil/view_models/perfil_view_model.dart';
import 'package:barrio_seguro/ui/principal/vigilante_de_alertas.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../ayudas/app_de_prueba.dart';
import '../ayudas/bases_de_prueba.dart';
import '../ayudas/falsos.dart';

void main() {
  group('Vigilante de alertas', () {
    late AlertasFalsas alertas;
    late NotificacionesFalsas notificaciones;
    late Preferencias preferencias;
    late BusDeEventos bus;

    setUp(() async {
      alertas = AlertasFalsas([
        alertaDePrueba(id: 'vieja', reportadaPor: 'jorge'),
      ]);
      notificaciones = NotificacionesFalsas();
      preferencias = preferenciasEnMemoria();
      await preferencias.guardarNotificaciones(true);
      bus = BusDeEventos();
    });

    VigilanteDeAlertas crear() => VigilanteDeAlertas(
      alertas: alertas,
      sesion: SesionFalsa(vecinaDePrueba),
      notificaciones: notificaciones,
      preferencias: preferencias,
      bus: bus,
    );

    test('lo que ya estaba al abrir la app no se avisa', () async {
      await crear().revisar();
      expect(notificaciones.avisadas, isEmpty);
    });

    test('avisa las alertas nuevas de otros vecinos', () async {
      final vigilante = crear();
      await vigilante.revisar();
      alertas.alertas.insert(
        0,
        alertaDePrueba(id: 'nueva', reportadaPor: 'jorge'),
      );

      await vigilante.revisar();

      expect(notificaciones.avisadas.map((a) => a.id), ['nueva']);
    });

    test('no avisa las propias ni las ya resueltas', () async {
      final vigilante = crear();
      await vigilante.revisar();
      alertas.alertas.insertAll(0, [
        alertaDePrueba(id: 'mia', reportadaPor: 'clara'),
        alertaDePrueba(
          id: 'cerrada',
          reportadaPor: 'jorge',
          estado: EstadoAlerta.resuelta,
        ),
      ]);

      await vigilante.revisar();

      expect(notificaciones.avisadas, isEmpty);
    });

    test(
      'con los avisos apagados no notifica, pero actualiza las pantallas',
      () async {
        await preferencias.guardarNotificaciones(false);
        final eventos = <Object>[];
        bus.eventos.listen(eventos.add);
        final vigilante = crear();
        await vigilante.revisar();
        alertas.alertas.insert(
          0,
          alertaDePrueba(id: 'nueva', reportadaPor: 'jorge'),
        );

        await vigilante.revisar();
        await Future<void>.delayed(Duration.zero);

        expect(notificaciones.avisadas, isEmpty);
        expect(eventos, contains(isA<AlertasActualizadas>()));
      },
    );

    testWidgets(
      'reacciona a eventos del sistema: pausa el reloj en segundo plano y revisa al volver (onResume)',
      (tester) async {
        final vigilante = crear()..empezar();
        addTearDown(vigilante.detener);
        await tester.pump();
        expect(vigilante.enPrimerPlano, isTrue);

        // El sistema operativo pasa la app a segundo plano.
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        expect(vigilante.enPrimerPlano, isFalse);

        // Otro vecino reporta una alerta mientras la app estaba en pausa.
        alertas.alertas.insert(
          0,
          alertaDePrueba(id: 'al-volver', reportadaPor: 'jorge'),
        );

        // El sistema operativo devuelve la app a primer plano (onResume).
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();

        expect(vigilante.enPrimerPlano, isTrue);
        expect(notificaciones.avisadas.map((a) => a.id), ['al-volver']);

        vigilante.detener();
      },
    );
  });

  group('Avisos push con la app cerrada', () {
    late NotificacionesFalsas notificaciones;
    late Preferencias preferencias;

    Map<String, dynamic> datosPush({
      String id = 'a-push-1',
      String estado = 'activa',
      String reportadaPor = 'jorge',
    }) => {
      'id': id,
      'categoria': 'sos',
      'tipo': 'Pedido de ayuda (SOS)',
      'descripcion': 'Urgencia en la vereda',
      'direccion': 'Calle Plantamura',
      'creada_en': '${DateTime(2026, 10, 1, 12).millisecondsSinceEpoch}',
      'estado': estado,
      'latitud': '-32.877264',
      'longitud': '-68.868785',
      'reportada_por': reportadaPor,
    };

    setUp(() async {
      notificaciones = NotificacionesFalsas();
      preferencias = preferenciasEnMemoria();
      await preferencias.guardarNotificaciones(true);
      await preferencias.guardarVecino(vecinaDePrueba);
    });

    test('con la app cerrada, cuando otro vecino crea una alerta, muestra una notificación', () async {
      final mostrada = await procesarAvisoPush(
        datosPush(id: 'ajena', reportadaPor: 'jorge'),
        preferencias: preferencias,
        notificaciones: notificaciones,
      );

      expect(mostrada, isTrue);
      expect(notificaciones.avisadas.map((a) => a.id), ['ajena']);
      expect(notificaciones.avisadas.single.direccion, 'Calle Plantamura');
    });

    test('el vecino que creó la alerta no recibe su propio aviso', () async {
      final mostrada = await procesarAvisoPush(
        datosPush(id: 'propia', reportadaPor: 'clara'),
        preferencias: preferencias,
        notificaciones: notificaciones,
      );

      expect(mostrada, isFalse);
      expect(notificaciones.avisadas, isEmpty);
    });

    test('si la alerta ya está resuelta cuando se va a mostrar el aviso, no se avisa', () async {
      final mostrada = await procesarAvisoPush(
        datosPush(id: 'resuelta', estado: 'resuelta', reportadaPor: 'jorge'),
        preferencias: preferencias,
        notificaciones: notificaciones,
      );

      expect(mostrada, isFalse);
      expect(notificaciones.avisadas, isEmpty);
    });

    test(
      'sin avisos activos o con datos inválidos no muestra notificación',
      () async {
        await preferencias.guardarNotificaciones(false);
        expect(
          await procesarAvisoPush(
            datosPush(),
            preferencias: preferencias,
            notificaciones: notificaciones,
          ),
          isFalse,
        );

        await preferencias.guardarNotificaciones(true);
        expect(
          await procesarAvisoPush(
            {'id': 'incompleta'},
            preferencias: preferencias,
            notificaciones: notificaciones,
          ),
          isFalse,
        );
        expect(notificaciones.avisadas, isEmpty);
      },
    );

    test(
      'activar avisos suscribe al push y apagarlos o cerrar sesión desuscribe',
      () async {
        final push = PushFalso();
        final vm = PerfilViewModel(
          sesion: SesionFalsa(vecinaDePrueba),
          bus: BusDeEventos(),
          reloj: relojDePrueba,
          capacidades: const CapacidadesFalsas(),
          politicas: const PoliticasFalsas(),
          preferencias: preferenciasEnMemoria(),
          ubicacion: UbicacionFalsa(),
          notificacionesService: NotificacionesFalsas(),
          pushService: push,
        );
        await vm.cargar();

        expect(await vm.activarAvisos(), isNull);
        expect(push.suscripto, isTrue);
        expect(push.suscripciones, 1);

        await vm.cambiarNotificaciones(false);
        expect(push.suscripto, isFalse);
        expect(push.desuscripciones, 1);

        await vm.activarAvisos();
        expect(push.suscripto, isTrue);

        await vm.cerrarSesion();
        expect(push.suscripto, isFalse);
        expect(push.desuscripciones, 2);
      },
    );

    test('sin el permiso de notificaciones o si el push falla la app sigue funcionando igual', () async {
      final push = PushFalso(falla: true);
      final vmSinPermiso = PerfilViewModel(
        sesion: SesionFalsa(vecinaDePrueba),
        bus: BusDeEventos(),
        reloj: relojDePrueba,
        capacidades: const CapacidadesFalsas(),
        politicas: const PoliticasFalsas(),
        preferencias: preferenciasEnMemoria(),
        ubicacion: UbicacionFalsa(),
        notificacionesService: NotificacionesFalsas(permiso: false),
        pushService: push,
      );
      await vmSinPermiso.cargar();

      final aviso = await vmSinPermiso.activarAvisos();
      expect(aviso, contains('Sin permiso'));
      expect(vmSinPermiso.notificaciones, isFalse);
      expect(push.suscripciones, 0);

      // Con permiso pero con fallo de red en el servicio de push, no
      // bloquea el cambio de preferencia ni el cierre de sesión.
      final vmConFalloPush = PerfilViewModel(
        sesion: SesionFalsa(vecinaDePrueba),
        bus: BusDeEventos(),
        reloj: relojDePrueba,
        capacidades: const CapacidadesFalsas(),
        politicas: const PoliticasFalsas(),
        preferencias: preferenciasEnMemoria(),
        ubicacion: UbicacionFalsa(),
        notificacionesService: NotificacionesFalsas(permiso: true),
        pushService: push,
      );
      await vmConFalloPush.cargar();

      expect(await vmConFalloPush.activarAvisos(), isNull);
      expect(vmConFalloPush.notificaciones, isTrue);
      await vmConFalloPush.cerrarSesion();
    });
  });
}
