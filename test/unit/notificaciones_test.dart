// Pruebas de los avisos de alertas nuevas, con la app abierta (vigilante)
// y con la app cerrada (push).

import 'package:barrio_seguro/data/services/bus_de_eventos.dart';
import 'package:barrio_seguro/data/services/local/preferencias.dart';
import 'package:barrio_seguro/data/services/notificaciones_service.dart';
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

    /// El reloj del vigilante (estado_alerta R60 a R63). Empieza en
    /// [creada] y no avanza salvo que la prueba lo mueva.
    late RelojManual reloj;

    setUp(() async {
      alertas = AlertasFalsas([
        alertaDePrueba(id: 'vieja', reportadaPor: 'jorge'),
      ]);
      notificaciones = NotificacionesFalsas();
      preferencias = preferenciasEnMemoria();
      await preferencias.guardarNotificaciones(true);
      bus = BusDeEventos();
      avisos = AvisosRecibidosFalsos();
      reloj = RelojManual(creada);
    });

    VigilanteDeAlertas crear() => VigilanteDeAlertas(
      alertas: alertas,
      sesion: SesionFalsa(vecinaDePrueba),
      notificaciones: notificaciones,
      preferencias: preferencias,
      bus: bus,
      avisos: avisos,
      reloj: reloj,
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

    /// Arranca el vigilante con una alerta resuelta y la reabre (como si
    /// alguien la hubiera vuelto a abrir entre dos revisiones).
    Future<VigilanteDeAlertas> conUnaReabierta({
      String reportadaPor = 'jorge',
      EstadoAlerta estadoNuevo = EstadoAlerta.activa,
    }) async {
      alertas.alertas.add(
        alertaDePrueba(
          id: 'reabierta',
          reportadaPor: reportadaPor,
          estado: EstadoAlerta.resuelta,
          creadaEn: creada,
        ),
      );
      final vigilante = crear();
      await vigilante.revisar();
      await alertas.cambiarEstado('reabierta', estadoNuevo);
      return vigilante;
    }

    test(
      'una alerta ajena que estaba resuelta y se reabrió muestra el aviso de '
      'reapertura',
      () async {
        final vigilante = await conUnaReabierta();

        final avisadas = await vigilante.revisar();

        expect(notificaciones.reaperturas.map((a) => a.id), ['reabierta']);
        expect(notificaciones.reaperturas.single.estado, EstadoAlerta.activa);
        // No es una alerta nueva: no se avisa como tal.
        expect(avisadas, isEmpty);
        expect(notificaciones.avisadas, isEmpty);
        expect(notificaciones.tardias, isEmpty);

        // La revisión siguiente no la vuelve a avisar.
        await vigilante.revisar();
        expect(notificaciones.reaperturas, hasLength(1));
      },
    );

    test('reabrir a en atención también se avisa', () async {
      final vigilante = await conUnaReabierta(
        estadoNuevo: EstadoAlerta.enAtencion,
      );

      await vigilante.revisar();

      expect(notificaciones.reaperturas.map((a) => a.id), ['reabierta']);
    });

    test('una reapertura publica AlertasActualizadas', () async {
      final eventos = <Object>[];
      bus.eventos.listen(eventos.add);
      final vigilante = await conUnaReabierta();

      await vigilante.revisar();
      await Future<void>.delayed(Duration.zero);

      expect(eventos, [isA<AlertasActualizadas>()]);
    });

    test('la reapertura de una alerta propia no se avisa', () async {
      final eventos = <Object>[];
      bus.eventos.listen(eventos.add);
      final vigilante = await conUnaReabierta(reportadaPor: 'clara');

      await vigilante.revisar();
      await Future<void>.delayed(Duration.zero);

      expect(notificaciones.reaperturas, isEmpty);
      // Igual se actualizan las pantallas ("Mis alertas").
      expect(eventos, [isA<AlertasActualizadas>()]);
    });

    test('con los avisos apagados la reapertura no se avisa pero se publica '
        'AlertasActualizadas', () async {
      await preferencias.guardarNotificaciones(false);
      final eventos = <Object>[];
      bus.eventos.listen(eventos.add);
      final vigilante = await conUnaReabierta();

      await vigilante.revisar();
      await Future<void>.delayed(Duration.zero);

      expect(notificaciones.reaperturas, isEmpty);
      expect(eventos, [isA<AlertasActualizadas>()]);
    });

    test('una alerta que pasa de activa a en atención no se avisa', () async {
      final eventos = <Object>[];
      bus.eventos.listen(eventos.add);
      final vigilante = crear();
      await vigilante.revisar();
      await alertas.cambiarEstado('vieja', EstadoAlerta.enAtencion);

      await vigilante.revisar();
      await Future<void>.delayed(Duration.zero);

      expect(notificaciones.reaperturas, isEmpty);
      expect(notificaciones.avisadas, isEmpty);
      expect(eventos, isEmpty);
    });

    test('una reapertura no guarda llegadas', () async {
      final vigilante = await conUnaReabierta();

      await vigilante.revisar();

      expect(notificaciones.reaperturas, hasLength(1));
      expect(avisos.guardadas, isEmpty);
    });

    test('lo que ya estaba reabierto al abrir la app no se avisa', () async {
      alertas.alertas.add(
        alertaDePrueba(id: 'ya-reabierta', reportadaPor: 'jorge'),
      );
      final vigilante = crear();

      await vigilante.revisar();
      await vigilante.revisar();

      expect(notificaciones.reaperturas, isEmpty);
    });

    // Reapertura tardía con la app abierta (estado_alerta R60 a R66).

    test('una reapertura encontrada después de más de 2 horas sin revisar se '
        'avisa como tardía sin hora', () async {
      final vigilante = await conUnaReabierta();
      reloj.hora = creada.add(const Duration(hours: 2, minutes: 1));

      final avisadas = await vigilante.revisar();

      expect(avisadas, isEmpty);
      expect(notificaciones.reaperturasTardiasSinHora.map((a) => a.id), [
        'reabierta',
      ]);
      expect(notificaciones.reaperturas, isEmpty);
      expect(notificaciones.reaperturasTardias, isEmpty);
      // El título y el cuerpo que arma NotificacionesServiceLocales.
      final alerta = notificaciones.reaperturasTardiasSinHora.single;
      expect(tituloAvisoReapertura(alerta), 'Se reabrió una alerta: Robo');
      expect(
        cuerpoAvisoTardio,
        'Llegó con demora por falta de señal. Puede que ya no esté pasando.',
      );
    });

    test('con 2 horas justas se avisa a tiempo', () async {
      final vigilante = await conUnaReabierta();
      reloj.hora = creada.add(const Duration(hours: 2));

      await vigilante.revisar();

      expect(notificaciones.reaperturas.map((a) => a.id), ['reabierta']);
      expect(notificaciones.reaperturasTardiasSinHora, isEmpty);
    });

    test('si la revisión del medio falla, la demora se mide desde la última '
        'que funcionó', () async {
      final vigilante = await conUnaReabierta();
      alertas.falla = true;
      reloj.hora = creada.add(const Duration(hours: 1));
      await vigilante.revisar();
      alertas.falla = false;
      reloj.hora = creada.add(const Duration(hours: 2, minutes: 30));

      await vigilante.revisar();

      expect(notificaciones.reaperturasTardiasSinHora.map((a) => a.id), [
        'reabierta',
      ]);
      expect(notificaciones.reaperturas, isEmpty);
    });

    test('una revisión que funcionó reinicia la cuenta', () async {
      alertas.alertas.add(
        alertaDePrueba(
          id: 'reabierta',
          reportadaPor: 'jorge',
          estado: EstadoAlerta.resuelta,
          creadaEn: creada,
        ),
      );
      final vigilante = crear();
      await vigilante.revisar();
      reloj.hora = creada.add(const Duration(hours: 1, minutes: 30));
      await vigilante.revisar();
      await alertas.cambiarEstado('reabierta', EstadoAlerta.activa);
      reloj.hora = creada.add(const Duration(hours: 3));

      await vigilante.revisar();

      expect(notificaciones.reaperturas.map((a) => a.id), ['reabierta']);
      expect(notificaciones.reaperturasTardiasSinHora, isEmpty);
    });

    test('la reapertura tardía de una alerta propia no se avisa', () async {
      final vigilante = await conUnaReabierta(reportadaPor: 'clara');
      reloj.hora = creada.add(const Duration(hours: 3));

      await vigilante.revisar();

      expect(notificaciones.reaperturasTardiasSinHora, isEmpty);
      expect(notificaciones.reaperturas, isEmpty);
    });

    test('con los avisos apagados la reapertura tardía no se avisa pero se '
        'publica AlertasActualizadas', () async {
      await preferencias.guardarNotificaciones(false);
      final eventos = <Object>[];
      bus.eventos.listen(eventos.add);
      final vigilante = await conUnaReabierta();
      reloj.hora = creada.add(const Duration(hours: 3));

      await vigilante.revisar();
      await Future<void>.delayed(Duration.zero);

      expect(notificaciones.reaperturasTardiasSinHora, isEmpty);
      expect(notificaciones.reaperturas, isEmpty);
      expect(eventos, [isA<AlertasActualizadas>()]);
    });

    test('una reapertura tardía no guarda llegadas', () async {
      final vigilante = await conUnaReabierta();
      reloj.hora = creada.add(const Duration(hours: 3));

      await vigilante.revisar();

      expect(notificaciones.reaperturasTardiasSinHora, hasLength(1));
      expect(avisos.guardadas, isEmpty);
    });

    test('una alerta nueva encontrada después de más de 2 horas sin revisar '
        'se clasifica por creada_en', () async {
      final vigilante = crear();
      await vigilante.revisar();
      alertas.alertas.insert(
        0,
        alertaDePrueba(
          id: 'reciente',
          reportadaPor: 'jorge',
          creadaEn: avisos.ahora.subtract(const Duration(minutes: 1)),
        ),
      );
      reloj.hora = creada.add(const Duration(hours: 3));

      final avisadas = await vigilante.revisar();

      expect(avisadas.map((a) => a.id), ['reciente']);
      expect(notificaciones.avisadas.map((a) => a.id), ['reciente']);
      expect(notificaciones.tardias, isEmpty);
    });

    test('NotificacionesServiceNinguno.avisarReaperturaTardiaSinHora termina '
        'sin hacer nada', () async {
      // Como la app sin notificaciones locales (por ejemplo, en la web).
      const ninguno = NotificacionesServiceNinguno();
      await expectLater(
        ninguno.avisarReaperturaTardiaSinHora(
          alertaDePrueba(id: 'reabierta', reportadaPor: 'jorge'),
        ),
        completes,
      );
    });

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

  group('Aviso push de reapertura', () {
    late NotificacionesFalsas notificaciones;
    late Preferencias preferencias;
    late AvisosRecibidosFalsos avisos;

    /// La alerta se creó un día antes y se reabrió a las 15:10; por
    /// defecto el aviso llega a las 15:10 (a tiempo).
    final reabierta = DateTime(2026, 10, 1, 15, 10);
    final creada = reabierta.subtract(const Duration(days: 1));

    Map<String, dynamic> datosPush({
      String id = 'reabierta-1',
      String estado = 'activa',
      String reportadaPor = 'jorge',
      Object? reabiertaEn = _sinCambio,
      String direccion = 'Calle Plantamura',
    }) => {
      'id': id,
      'categoria': 'robo',
      'tipo': 'Robo de celular',
      'descripcion': 'En la parada',
      'direccion': direccion,
      'creada_en': '${creada.millisecondsSinceEpoch}',
      'estado': estado,
      'latitud': '-32.877264',
      'longitud': '-68.868785',
      'reportada_por': reportadaPor,
      'reportada_por_nombre': 'Jorge',
      'aviso': 'reabierta',
      'reabierta_en': identical(reabiertaEn, _sinCambio)
          ? '${reabierta.millisecondsSinceEpoch}'
          : reabiertaEn,
    };

    setUp(() async {
      avisos = AvisosRecibidosFalsos(ahora: reabierta);
      notificaciones = NotificacionesFalsas();
      preferencias = preferenciasEnMemoria();
      await preferencias.guardarNotificaciones(true);
      await preferencias.guardarVecino(vecinaDePrueba);
    });

    Future<bool> procesar(Map<String, dynamic> datos) => procesarAvisoPush(
      datos,
      preferencias: preferencias,
      notificaciones: notificaciones,
      avisos: avisos,
    );

    void sinNingunAviso() {
      expect(notificaciones.reaperturas, isEmpty);
      expect(notificaciones.reaperturasTardias, isEmpty);
      expect(notificaciones.avisadas, isEmpty);
      expect(notificaciones.tardias, isEmpty);
    }

    test('una reapertura a tiempo muestra el aviso de reapertura', () async {
      avisos.ahora = reabierta.add(const Duration(minutes: 5));

      expect(await procesar(datosPush()), isTrue);

      final alerta = notificaciones.reaperturas.single;
      expect(alerta.id, 'reabierta-1');
      expect(alerta.estado, EstadoAlerta.activa);
      expect(notificaciones.avisadas, isEmpty);
      expect(notificaciones.tardias, isEmpty);
      expect(notificaciones.reaperturasTardias, isEmpty);
      expect(tituloAvisoReapertura(alerta), 'Se reabrió una alerta: Robo');
      expect(
        cuerpoAvisoReapertura(alerta),
        'Calle Plantamura. Tocá para ver dónde.',
      );
    });

    test('una reapertura con 30 minutos de demora muestra el aviso de '
        'reapertura tardío', () async {
      avisos.ahora = reabierta.add(const Duration(minutes: 30));

      expect(await procesar(datosPush(estado: 'en_atencion')), isTrue);

      expect(notificaciones.reaperturas, isEmpty);
      expect(notificaciones.avisadas, isEmpty);
      expect(notificaciones.tardias, isEmpty);
      final (alerta, reabiertaEn) = notificaciones.reaperturasTardias.single;
      expect(alerta.id, 'reabierta-1');
      expect(reabiertaEn, reabierta);
      expect(
        tituloAvisoReaperturaTardia(alerta, reabiertaEn),
        'Se reabrió una alerta: Robo 15:10',
      );
    });

    test('una reapertura con 3 horas de demora no muestra nada', () async {
      avisos.ahora = reabierta.add(const Duration(hours: 3));

      expect(await procesar(datosPush()), isFalse);
      sinNingunAviso();
    });

    test('la reapertura de una alerta propia no se avisa', () async {
      expect(await procesar(datosPush(reportadaPor: 'clara')), isFalse);
      sinNingunAviso();
    });

    test('con los avisos apagados no se avisa', () async {
      await preferencias.guardarNotificaciones(false);
      expect(await procesar(datosPush()), isFalse);
      sinNingunAviso();
    });

    test('sin reabierta_en, con reabierta_en inválido o con estado resuelta no '
        'se avisa', () async {
      expect(await procesar(datosPush()..remove('reabierta_en')), isFalse);
      expect(await procesar(datosPush(reabiertaEn: 'ayer')), isFalse);
      expect(await procesar(datosPush(estado: 'resuelta')), isFalse);
      expect(
        await procesar({'aviso': 'reabierta', 'id': 'incompleta'}),
        isFalse,
      );
      sinNingunAviso();
    });

    test(
      'una reapertura no cambia la llegada guardada del aviso original',
      () async {
        final original = creada.add(const Duration(minutes: 20));
        avisos.guardadas['reabierta-1'] = original;

        expect(await procesar(datosPush()), isTrue);
        expect(avisos.guardadas, {'reabierta-1': original});

        // Sin llegada guardada, tampoco se agrega una.
        avisos.guardadas.clear();
        expect(await procesar(datosPush(id: 'reabierta-2')), isTrue);
        expect(avisos.guardadas, isEmpty);
      },
    );

    test('un push sin aviso sigue el camino de siempre', () async {
      // El mismo push sin "aviso": se clasifica por creada_en (un día
      // antes), así que es demasiado tardío, y guarda la llegada.
      final datos = datosPush()..remove('aviso');

      expect(await procesar(datos), isFalse);
      sinNingunAviso();
      expect(avisos.guardadas['reabierta-1'], reabierta);
    });

    test('reabiertaEnDesdeDatosPush lee entero y texto', () {
      final ms = reabierta.millisecondsSinceEpoch;
      expect(reabiertaEnDesdeDatosPush({'reabierta_en': ms}), reabierta);
      expect(reabiertaEnDesdeDatosPush({'reabierta_en': '$ms'}), reabierta);
      expect(reabiertaEnDesdeDatosPush({'reabierta_en': 'x'}), isNull);
      expect(reabiertaEnDesdeDatosPush({}), isNull);
    });
  });
}

/// Marca "no me pasaron este parámetro" (distinto de pasar null).
const _sinCambio = Object();
