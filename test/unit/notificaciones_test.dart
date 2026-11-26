// Pruebas de los avisos de alertas nuevas, con la app abierta (vigilante)
// y con la app cerrada (push).

import 'package:barrio_seguro/data/services/bus_de_eventos.dart';
import 'package:barrio_seguro/data/services/local/preferencias.dart';
import 'package:barrio_seguro/data/services/push_service.dart';
import 'package:barrio_seguro/domain/avisos_tardios.dart';
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

    /// Las alertas de prueba son de las 11:55 y el aviso llega, por
    /// defecto, a las 12:00 (a tiempo).
    late AvisosRecibidosFalsos avisos;
    final creada = DateTime(2026, 10, 1, 11, 55);

    setUp(() async {
      alertas = AlertasFalsas([
        alertaDePrueba(id: 'vieja', reportadaPor: 'jorge'),
      ]);
      notificaciones = NotificacionesFalsas();
      preferencias = preferenciasEnMemoria();
      await preferencias.guardarNotificaciones(true);
      bus = BusDeEventos();
      avisos = AvisosRecibidosFalsos();
    });

    VigilanteDeAlertas crear() => VigilanteDeAlertas(
      alertas: alertas,
      sesion: SesionFalsa(vecinaDePrueba),
      notificaciones: notificaciones,
      preferencias: preferencias,
      bus: bus,
      avisos: avisos,
    );

    /// Arranca el vigilante y agrega una alerta nueva de otro vecino.
    Future<VigilanteDeAlertas> conUnaNueva(String id) async {
      final vigilante = crear();
      await vigilante.revisar();
      alertas.alertas.insert(
        0,
        alertaDePrueba(
          id: id,
          reportadaPor: 'jorge',
          reportadaPorNombre: 'Jorge',
          creadaEn: creada,
        ),
      );
      return vigilante;
    }

    test('lo que ya estaba al abrir la app no se avisa', () async {
      await crear().revisar();
      expect(notificaciones.avisadas, isEmpty);
      expect(avisos.guardadas, isEmpty);
    });

    test('una alerta nueva a tiempo se avisa igual que antes', () async {
      final vigilante = await conUnaNueva('nueva');

      final avisadas = await vigilante.revisar();

      expect(avisadas.map((a) => a.id), ['nueva']);
      expect(notificaciones.avisadas.map((a) => a.id), ['nueva']);
      expect(notificaciones.tardias, isEmpty);
      expect(avisos.guardadas.keys, ['nueva']);
    });

    test(
      'una alerta nueva con 10 minutos de demora se avisa como tardía',
      () async {
        final vigilante = await conUnaNueva('tardia');
        avisos.ahora = creada.add(const Duration(minutes: 10));

        final avisadas = await vigilante.revisar();

        expect(avisadas.map((a) => a.id), ['tardia']);
        expect(notificaciones.avisadas, isEmpty);
        expect(notificaciones.tardias.map((a) => a.id), ['tardia']);
        expect(
          tituloAvisoTardio(notificaciones.tardias.single),
          'Robo de Jorge 11:55',
        );
      },
    );

    test('una alerta nueva con 3 horas de demora no se avisa', () async {
      final eventos = <Object>[];
      bus.eventos.listen(eventos.add);
      final vigilante = await conUnaNueva('vieja-nueva');
      avisos.ahora = creada.add(const Duration(hours: 3));

      final avisadas = await vigilante.revisar();
      await Future<void>.delayed(Duration.zero);

      expect(avisadas, isEmpty);
      expect(notificaciones.avisadas, isEmpty);
      expect(notificaciones.tardias, isEmpty);
      // Igual queda guardada para la marca y las pantallas se actualizan.
      expect(avisos.guardadas['vieja-nueva'], avisos.ahora);
      expect(eventos, contains(isA<AlertasActualizadas>()));
    });

    test(
      'si el push ya guardó una llegada a tiempo, el vigilante avisa a tiempo',
      () async {
        final vigilante = await conUnaNueva('del-push');
        avisos.guardadas['del-push'] = creada.add(const Duration(minutes: 1));
        avisos.ahora = creada.add(const Duration(minutes: 30));

        await vigilante.revisar();

        expect(notificaciones.avisadas.map((a) => a.id), ['del-push']);
        expect(notificaciones.tardias, isEmpty);
        expect(
          avisos.guardadas['del-push'],
          creada.add(const Duration(minutes: 1)),
        );
      },
    );

    test('con los avisos apagados no guarda llegadas', () async {
      await preferencias.guardarNotificaciones(false);
      final vigilante = await conUnaNueva('apagada');
      avisos.ahora = creada.add(const Duration(minutes: 10));

      await vigilante.revisar();

      expect(avisos.guardadas, isEmpty);
      expect(notificaciones.tardias, isEmpty);
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

    /// La alerta se crea a las 12:00 y, por defecto, el aviso llega a las
    /// 12:00 (a tiempo).
    late AvisosRecibidosFalsos avisos;
    final creada = DateTime(2026, 10, 1, 12);

    Map<String, dynamic> datosPush({
      String id = 'a-push-1',
      String estado = 'activa',
      String reportadaPor = 'jorge',
      String? reportadaPorNombre,
    }) => {
      'id': id,
      'categoria': 'sos',
      'tipo': 'Pedido de ayuda (SOS)',
      'descripcion': 'Urgencia en la vereda',
      'direccion': 'Calle Plantamura',
      'creada_en': '${creada.millisecondsSinceEpoch}',
      'estado': estado,
      'latitud': '-32.877264',
      'longitud': '-68.868785',
      'reportada_por': reportadaPor,
      'reportada_por_nombre': ?reportadaPorNombre,
    };

    setUp(() async {
      avisos = AvisosRecibidosFalsos(ahora: creada);
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
        avisos: avisos,
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
        avisos: avisos,
      );

      expect(mostrada, isFalse);
      expect(notificaciones.avisadas, isEmpty);
    });

    test('si la alerta ya está resuelta cuando se va a mostrar el aviso, no se avisa', () async {
      final mostrada = await procesarAvisoPush(
        datosPush(id: 'resuelta', estado: 'resuelta', reportadaPor: 'jorge'),
        preferencias: preferencias,
        notificaciones: notificaciones,
        avisos: avisos,
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
            avisos: avisos,
          ),
          isFalse,
        );

        await preferencias.guardarNotificaciones(true);
        expect(
          await procesarAvisoPush(
            {'id': 'incompleta'},
            preferencias: preferencias,
            notificaciones: notificaciones,
            avisos: avisos,
          ),
          isFalse,
        );
        expect(notificaciones.avisadas, isEmpty);
      },
    );

    test('un push a tiempo se avisa igual que antes', () async {
      avisos.ahora = creada.add(const Duration(minutes: 5));

      final mostrada = await procesarAvisoPush(
        datosPush(id: 'a-tiempo', reportadaPorNombre: 'Marta'),
        preferencias: preferencias,
        notificaciones: notificaciones,
        avisos: avisos,
      );

      expect(mostrada, isTrue);
      expect(notificaciones.avisadas.map((a) => a.id), ['a-tiempo']);
      expect(notificaciones.tardias, isEmpty);
      expect(avisos.guardadas['a-tiempo'], avisos.ahora);
    });

    test('un push con más de 5 minutos de demora muestra el aviso tardío con título y cuerpo', () async {
      avisos.ahora = creada.add(const Duration(minutes: 5, seconds: 1));

      final mostrada = await procesarAvisoPush(
        datosPush(id: 'tardia', reportadaPorNombre: 'Marta'),
        preferencias: preferencias,
        notificaciones: notificaciones,
        avisos: avisos,
      );

      expect(mostrada, isTrue);
      expect(notificaciones.avisadas, isEmpty);
      final tardia = notificaciones.tardias.single;
      expect(tardia.id, 'tardia');
      expect(tituloAvisoTardio(tardia), 'SOS de Marta 12:00');
      expect(
        cuerpoAvisoTardio,
        'Llegó con demora por falta de señal. Puede que ya no esté pasando.',
      );
    });

    test('un push con más de 2 horas de demora no muestra notificación pero guarda la llegada', () async {
      avisos.ahora = creada.add(const Duration(hours: 2, minutes: 1));

      final mostrada = await procesarAvisoPush(
        datosPush(id: 'vieja'),
        preferencias: preferencias,
        notificaciones: notificaciones,
        avisos: avisos,
      );

      expect(mostrada, isFalse);
      expect(notificaciones.avisadas, isEmpty);
      expect(notificaciones.tardias, isEmpty);
      expect(avisos.guardadas['vieja'], avisos.ahora);
    });

    test(
      'si ya había una llegada guardada, clasifica con la primera',
      () async {
        avisos.guardadas['repetida'] = creada.add(const Duration(minutes: 1));
        avisos.ahora = creada.add(const Duration(hours: 1));

        await procesarAvisoPush(
          datosPush(id: 'repetida'),
          preferencias: preferencias,
          notificaciones: notificaciones,
          avisos: avisos,
        );

        expect(notificaciones.avisadas.map((a) => a.id), ['repetida']);
        expect(notificaciones.tardias, isEmpty);
      },
    );

    test('con los avisos apagados no se guarda la llegada', () async {
      await preferencias.guardarNotificaciones(false);

      await procesarAvisoPush(
        datosPush(id: 'apagados'),
        preferencias: preferencias,
        notificaciones: notificaciones,
        avisos: avisos,
      );

      expect(avisos.guardadas, isEmpty);
    });

    test('un push propio o resuelto no guarda la llegada', () async {
      await procesarAvisoPush(
        datosPush(id: 'propia', reportadaPor: 'clara'),
        preferencias: preferencias,
        notificaciones: notificaciones,
        avisos: avisos,
      );
      await procesarAvisoPush(
        datosPush(id: 'resuelta', estado: 'resuelta'),
        preferencias: preferencias,
        notificaciones: notificaciones,
        avisos: avisos,
      );

      expect(avisos.guardadas, isEmpty);
    });

    test('los datos del push traen reportada_por_nombre', () {
      expect(
        alertaDesdeDatosPush(datosPush(reportadaPorNombre: 'Marta'))!
            .reportadaPorNombre,
        'Marta',
      );
      // Un push de un servidor viejo, sin el campo: queda vacío.
      expect(alertaDesdeDatosPush(datosPush())!.reportadaPorNombre, '');
    });

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
