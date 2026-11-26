// Pruebas de los ViewModels con repositorios falsos: sin servidor, sin
// widgets y con un reloj fijo, así los resultados no dependen del día.

import 'dart:async';
import 'dart:io';

import 'package:barrio_seguro/data/repositories/alertas_repository.dart';
import 'package:barrio_seguro/data/services/bus_de_eventos.dart';
import 'package:barrio_seguro/data/services/error_del_servidor.dart';
import 'package:barrio_seguro/data/services/local/alertas_dao.dart';
import 'package:barrio_seguro/data/services/local/preferencias.dart';
import 'package:barrio_seguro/data/services/reloj.dart';
import 'package:barrio_seguro/domain/barrio.dart';
import 'package:barrio_seguro/domain/evento_de_app.dart';
import 'package:barrio_seguro/domain/models/alerta.dart';
import 'package:barrio_seguro/domain/models/turno.dart';
import 'package:barrio_seguro/domain/models/vecino.dart';
import 'package:barrio_seguro/ui/alerta_detalle/view_models/detalle_alerta_view_model.dart';
import 'package:barrio_seguro/ui/core/estado_carga.dart';
import 'package:barrio_seguro/ui/core/ubicacion_de_alerta.dart';
import 'package:barrio_seguro/ui/informe_alertas/view_models/informe_alertas_view_model.dart';
import 'package:barrio_seguro/ui/inicio/view_models/inicio_view_model.dart';
import 'package:barrio_seguro/ui/mapa/view_models/mapa_view_model.dart';
import 'package:barrio_seguro/ui/perfil/view_models/perfil_view_model.dart';
import 'package:barrio_seguro/ui/registro/view_models/registro_view_model.dart';
import 'package:barrio_seguro/ui/reportar_alerta/view_models/reportar_alerta_view_model.dart';
import 'package:barrio_seguro/ui/sos/view_models/sos_view_model.dart';
import 'package:barrio_seguro/ui/turnos/view_models/turnos_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import '../ayudas/bases_de_prueba.dart';
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

    test('con una contraseña corta no crea la cuenta', () async {
      final vm = crear()
        ..cambiarNombre('Ana')
        ..cambiarFecha('01/01/1990');
      final creada = await vm.registrar(
        telefono: '261 555-0999',
        calle: 'Plantamura',
        cuadra: '4',
        codigoComision: 'SOBERANIA',
        clave: '123',
      );
      expect(creada, isFalse);
      expect(vm.errorClave, contains('6 caracteres'));
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
    MapaViewModel crear(AlertasFalsas alertas) => MapaViewModel(
      alertas: alertas,
      bus: bus,
      reloj: reloj,
      avisos: AvisosRecibidosFalsos(),
    );

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
        preferencias: preferenciasEnMemoria(),
        ubicacion: UbicacionFalsa(),
        capacidades: const CapacidadesFalsas(),
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
        preferencias: preferenciasEnMemoria(),
        ubicacion: UbicacionFalsa(),
        capacidades: const CapacidadesFalsas(),
      );
      await vm.enviar();
      expect(vm.paso, PasoSos.error);
    });

    test('el SOS sin red queda en error y no se guarda', () async {
      final db = await baseEnMemoria();
      addTearDown(db.close);
      final repositorio = AlertasRepositoryRemoto(
        service: AlertasServiceQueFalla(const SocketException('sin señal')),
        dao: AlertasDao(db),
      );
      final vm = SosViewModel(
        alertas: repositorio,
        sesion: SesionFalsa(vecinaDePrueba),
        bus: bus,
        preferencias: preferenciasEnMemoria(),
        ubicacion: UbicacionFalsa(),
        capacidades: const CapacidadesFalsas(),
      );
      final eventos = <Object>[];
      bus.eventos.listen(eventos.add);

      await vm.enviar();
      await Future<void>.delayed(Duration.zero);

      expect(vm.paso, PasoSos.error);
      expect(await db.query('alertas'), isEmpty);
      expect(eventos, isEmpty);
    });

    test('"Ya estoy a salvo" deja la alerta resuelta', () async {
      final alertas = AlertasFalsas();
      final vm = SosViewModel(
        alertas: alertas,
        sesion: SesionFalsa(vecinaDePrueba),
        bus: bus,
        preferencias: preferenciasEnMemoria(),
        ubicacion: UbicacionFalsa(),
        capacidades: const CapacidadesFalsas(),
      );
      await vm.enviar();
      expect(await vm.cerrarAlerta(), isTrue);
      expect(alertas.alertas.first.estado, EstadoAlerta.resuelta);
    });

    SosViewModel crearSos(AlertasFalsas alertas) => SosViewModel(
      alertas: alertas,
      sesion: SesionFalsa(vecinaDePrueba),
      bus: bus,
      preferencias: preferenciasEnMemoria(),
      ubicacion: UbicacionFalsa(),
      capacidades: const CapacidadesFalsas(),
    );

    test(
      'enviar crea una alerta sos con el título "Intento de robo"',
      () async {
        final alertas = AlertasFalsas();
        await crearSos(alertas).enviar();

        final creada = alertas.alertas.single;
        expect(creada.categoria, CategoriaAlerta.sos);
        expect(creada.tipo, 'Intento de robo');
        expect(tipoAlertaSos, 'Intento de robo');
      },
    );

    test(
      'enviar manda la descripción, la dirección y quien reporta como antes',
      () async {
        final alertas = AlertasFalsas();
        await crearSos(alertas).enviar();

        final creada = alertas.alertas.single;
        expect(creada.descripcion, 'Un vecino pidió ayuda con el botón SOS.');
        expect(creada.direccion, '${Barrio.nombre} (zona aproximada)');
        expect(alertas.ubicacionesEnviadas.single, Barrio.centro);
        expect(creada.reportadaPor, 'clara');
      },
    );

    test(
      'si falla cerrarAlerta devuelve false y la alerta sigue activa',
      () async {
        final alertas = AlertasFalsas();
        final vm = crearSos(alertas);
        await vm.enviar();
        alertas.falla = true;

        expect(await vm.cerrarAlerta(), isFalse);
        expect(alertas.cambiosDeEstado, 1);
        expect(alertas.alertas.single.estado, EstadoAlerta.activa);
      },
    );
  });

  group('DetalleAlertaViewModel', () {
    DetalleAlertaViewModel crear(Alerta alerta, AlertasFalsas alertas) =>
        DetalleAlertaViewModel(
          alerta: alerta,
          alertas: alertas,
          sesion: SesionFalsa(vecinaDePrueba),
          bus: bus,
          reloj: reloj,
          avisos: AvisosRecibidosFalsos(),
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

  group('InformeAlertasViewModel y rol en PerfilViewModel', () {
    test('PerfilViewModel.esComision distingue comisión de vecino común', () {
      final vecinaComision = Vecino(
        id: 'clara',
        nombre: 'Clara Medina',
        fechaNacimiento: DateTime(1981, 5, 14),
        rol: RolVecino.comision,
      );
      PerfilViewModel crearPerfil(Vecino vecino) => PerfilViewModel(
        sesion: SesionFalsa(vecino),
        bus: bus,
        reloj: reloj,
        capacidades: const CapacidadesFalsas(),
        politicas: const PoliticasFalsas(),
        preferencias: preferenciasEnMemoria(),
        ubicacion: UbicacionFalsa(),
        notificacionesService: NotificacionesFalsas(),
      );

      expect(crearPerfil(vecinaComision).esComision, isTrue);
      expect(crearPerfil(vecinaDePrueba).esComision, isFalse);
    });

    test(
      'carga el informe del mes actual, cambia de mes y reacciona al bus',
      () async {
        final alertas = AlertasFalsas([alertaDePrueba(id: 'oct-1')]);
        final vm = InformeAlertasViewModel(
          alertas: alertas,
          bus: bus,
          reloj: reloj,
        );

        await vm.cargar();
        expect(vm.estado, EstadoCarga.exito);
        expect(vm.mes, DateTime(2026, 10));
        expect(vm.informe.total, 1);
        expect(vm.informe.sinAlertas, isFalse);

        // Cambiar al mes anterior (septiembre 2026, sin alertas).
        vm.mesAnterior();
        expect(vm.mes, DateTime(2026, 9));
        expect(vm.informe.sinAlertas, isTrue);

        // Volver a octubre y publicar una alerta nueva por el bus.
        vm.mesSiguiente();
        expect(vm.mes, DateTime(2026, 10));
        alertas.alertas.add(alertaDePrueba(id: 'oct-2'));
        bus.publicar(const AlertasActualizadas());
        await Future<void>.delayed(Duration.zero);

        expect(vm.informe.total, 2);
        vm.dispose();
      },
    );

    test('si falla la carga pasa al estado de error', () async {
      final vm = InformeAlertasViewModel(
        alertas: AlertasFalsas([], true),
        bus: bus,
        reloj: reloj,
      );

      await vm.cargar();
      expect(vm.estado, EstadoCarga.error);
      vm.dispose();
    });

    test('descargarCsv guarda el CSV del mes y avisa si falla', () async {
      final descarga = DescargaCsvFalsa();
      final vm = InformeAlertasViewModel(
        alertas: AlertasFalsas([alertaDePrueba(id: 'oct-1')]),
        bus: bus,
        reloj: reloj,
        descargaCsv: descarga,
      );
      await vm.cargar();

      final exito = await vm.descargarCsv();
      expect(exito, 'Informe descargado: informe_alertas_2026_10.csv');
      expect(descarga.descargas, 1);
      expect(descarga.ultimoNombre, 'informe_alertas_2026_10.csv');
      expect(descarga.ultimoContenido, contains('Calle de prueba,1'));

      descarga.falla = true;
      final fallo = await vm.descargarCsv();
      expect(fallo, 'No pudimos descargar el informe. Probá de nuevo.');
      vm.dispose();
    });
  });

  group('Alertas tardías en inicio, mapa y detalle', () {
    // El reloj marca las 12:00; las alertas de prueba son de las 11:55.
    final creada = DateTime(2026, 10, 1, 11, 55);
    const marca = 'Llegó con demora. Alerta de las 11:55';

    InicioViewModel inicio(
      AlertasFalsas alertas,
      AvisosRecibidosFalsos avisos,
    ) => InicioViewModel(
      alertas: alertas,
      turnos: TurnosFalsos(),
      sesion: SesionFalsa(vecinaDePrueba),
      bus: bus,
      reloj: reloj,
      mesDeTurnos: DateTime(2026, 10),
      avisos: avisos,
    );

    MapaViewModel mapa(AlertasFalsas alertas, AvisosRecibidosFalsos avisos) =>
        MapaViewModel(alertas: alertas, bus: bus, reloj: reloj, avisos: avisos);

    DetalleAlertaViewModel detalle(
      Alerta alerta,
      AvisosRecibidosFalsos avisos,
    ) => DetalleAlertaViewModel(
      alerta: alerta,
      alertas: AlertasFalsas([alerta]),
      sesion: SesionFalsa(vecinaDePrueba),
      bus: bus,
      reloj: reloj,
      avisos: avisos,
    );

    Alerta ajena(String id, {String nombre = ''}) => alertaDePrueba(
      id: id,
      reportadaPor: 'jorge',
      reportadaPorNombre: nombre,
    );

    test('inicio marca como tardía una alerta con llegada tardía', () async {
      final vm = inicio(
        AlertasFalsas([ajena('t')]),
        AvisosRecibidosFalsos(
          iniciales: {'t': creada.add(const Duration(minutes: 6))},
        ),
      );
      await vm.cargar();

      expect(vm.tardia(vm.cercanas.single), marca);
      expect(vm.tardias, {'t': marca});
    });

    test(
      'inicio no marca una alerta con llegada a tiempo ni una sin llegada',
      () async {
        final vm = inicio(
          AlertasFalsas([ajena('a-tiempo'), ajena('sin-llegada')]),
          AvisosRecibidosFalsos(
            iniciales: {'a-tiempo': creada.add(const Duration(minutes: 5))},
          ),
        );
        await vm.cargar();

        for (final alerta in vm.cercanas) {
          expect(vm.tardia(alerta), isNull, reason: alerta.id);
        }
        expect(vm.tardias, isEmpty);
      },
    );

    test(
      'una alerta demasiado tardía aparece en el inicio y en el mapa con marca',
      () async {
        final alertas = AlertasFalsas([ajena('muy-tarde')]);
        final avisos = AvisosRecibidosFalsos(
          iniciales: {'muy-tarde': creada.add(const Duration(hours: 3))},
        );
        final vmInicio = inicio(alertas, avisos);
        final vmMapa = mapa(alertas, avisos);
        await vmInicio.cargar();
        await vmMapa.cargar();

        expect(vmInicio.cercanas.map((a) => a.id), ['muy-tarde']);
        expect(vmInicio.tardias, {'muy-tarde': marca});
        expect(vmMapa.visibles.map((a) => a.id), ['muy-tarde']);
        expect(vmMapa.tardias, {'muy-tarde': marca});
      },
    );

    test('mapa expone las marcas por id', () async {
      final vm = mapa(
        AlertasFalsas([ajena('t1'), ajena('ok'), ajena('t2')]),
        AvisosRecibidosFalsos(
          iniciales: {
            't1': creada.add(const Duration(minutes: 10)),
            'ok': creada.add(const Duration(minutes: 1)),
            't2': creada.add(const Duration(minutes: 30)),
          },
        ),
      );
      await vm.cargar();

      expect(vm.tardias, {'t1': marca, 't2': marca});
      expect(vm.tardia(vm.visibles[1]), isNull);
    });

    test('detalle carga la marca de su alerta', () async {
      final vm = detalle(
        ajena('t'),
        AvisosRecibidosFalsos(
          iniciales: {'t': creada.add(const Duration(minutes: 20))},
        ),
      );
      var avisos = 0;
      vm.addListener(() => avisos++);
      expect(vm.tardia, isNull);

      await vm.cargarLlegada();

      expect(vm.tardia, marca);
      expect(avisos, 1);

      final aTiempo = detalle(
        ajena('ok'),
        AvisosRecibidosFalsos(iniciales: {'ok': creada}),
      );
      await aTiempo.cargarLlegada();
      expect(aTiempo.tardia, isNull);
    });

    test('si leer las llegadas falla no hay marcas y la lista se ve', () async {
      final alertas = AlertasFalsas([ajena('t')]);
      final avisos = AvisosRecibidosFalsos(
        iniciales: {'t': creada.add(const Duration(minutes: 20))},
        falla: true,
      );
      final vmInicio = inicio(alertas, avisos);
      final vmMapa = mapa(alertas, avisos);
      final vmDetalle = detalle(ajena('t'), avisos);
      await vmInicio.cargar();
      await vmMapa.cargar();
      await vmDetalle.cargarLlegada();

      expect(vmInicio.estado, EstadoCarga.exito);
      expect(vmInicio.cercanas, hasLength(1));
      expect(vmInicio.tardias, isEmpty);
      expect(vmMapa.estado, EstadoCarga.exito);
      expect(vmMapa.tardias, isEmpty);
      expect(vmDetalle.tardia, isNull);
    });

    test(
      'detalle de una alerta ajena con nombre: reportadaPor es el nombre',
      () {
        final vm = detalle(
          ajena('a', nombre: 'Jorge'),
          AvisosRecibidosFalsos(),
        );
        expect(vm.reportadaPor, 'Jorge');
      },
    );

    test(
      'detalle de una alerta ajena sin nombre: reportadaPor es "Un vecino"',
      () {
        final vm = detalle(ajena('a'), AvisosRecibidosFalsos());
        expect(vm.reportadaPor, 'Un vecino');
      },
    );

    test('detalle de una alerta propia: reportadaPor es "Vos" aunque traiga nombre', () {
      final propia = alertaDePrueba(
        reportadaPor: 'clara',
        reportadaPorNombre: 'Clara',
      );
      expect(detalle(propia, AvisosRecibidosFalsos()).reportadaPor, 'Vos');
    });
  });

  group('ReportarAlertaViewModel', () {
    ReportarAlertaViewModel crear({
      AlertasRepository? alertas,
      bool tieneGps = true,
      bool compartir = true,
      UbicacionFalsa? ubicacion,
    }) => ReportarAlertaViewModel(
      alertas: alertas ?? AlertasFalsas(),
      sesion: SesionFalsa(vecinaDePrueba),
      bus: bus,
      ubicacion: UbicacionDeAlerta(
        capacidades: CapacidadesFalsas(tieneGps: tieneGps),
        preferencias: preferenciasEnMemoria({
          Preferencias.claveCompartirUbicacion: compartir,
        }),
        ubicacion: ubicacion ?? UbicacionFalsa(),
      ),
    );

    Future<bool> enviar(
      ReportarAlertaViewModel vm, {
      String titulo = 'Robo',
      String descripcion = '',
      String direccion = '',
    }) => vm.enviar(
      titulo: titulo,
      descripcion: descripcion,
      direccion: direccion,
    );

    // --- Tipos y título (R6 a R9) ---

    test('ofrece los cuatro tipos para reportar en orden', () {
      expect(crear().tipos, [
        CategoriaAlerta.actividadSospechosa,
        CategoriaAlerta.vehiculo,
        CategoriaAlerta.robo,
        CategoriaAlerta.ruidos,
      ]);
    });

    test('arranca sin tipo elegido', () {
      final vm = crear();
      expect(vm.tipo, isNull);
      expect(vm.primerError, isNull);
      expect(vm.errorDeEnvio, isNull);
      expect(vm.enviando, isFalse);
    });

    test('elegir un tipo con el título vacío sugiere su nombre', () {
      final vm = crear();
      final titulo = vm.tituloAlElegir(CategoriaAlerta.robo, tituloActual: '');
      expect(titulo, 'Robo');
      expect(vm.tipo, CategoriaAlerta.robo);
    });

    test('elegir otro tipo cambia la sugerencia si el título no se tocó', () {
      final vm = crear();
      final primero = vm.tituloAlElegir(CategoriaAlerta.robo, tituloActual: '');
      final segundo = vm.tituloAlElegir(
        CategoriaAlerta.vehiculo,
        tituloActual: primero,
      );
      expect(segundo, 'Vehículo sospechoso');
      expect(vm.tipo, CategoriaAlerta.vehiculo);
    });

    test('elegir otro tipo conserva el título que escribió el vecino', () {
      final vm = crear();
      vm.tituloAlElegir(CategoriaAlerta.robo, tituloActual: '');
      final titulo = vm.tituloAlElegir(
        CategoriaAlerta.ruidos,
        tituloActual: 'Robo de bicicleta',
      );
      expect(titulo, 'Robo de bicicleta');
      expect(vm.tipo, CategoriaAlerta.ruidos);
    });

    // --- Ubicación (R11 a R16) ---

    test(
      'con GPS y ubicación exacta activada conUbicacionExacta es true',
      () async {
        final vm = crear();
        expect(vm.conUbicacionExacta, isFalse);
        await vm.cargar();
        expect(vm.conUbicacionExacta, isTrue);
      },
    );

    test('sin GPS o sin la preferencia conUbicacionExacta es false', () async {
      final sinGps = crear(tieneGps: false);
      await sinGps.cargar();
      expect(sinGps.conUbicacionExacta, isFalse);

      final sinPreferencia = crear(compartir: false);
      await sinPreferencia.cargar();
      expect(sinPreferencia.conUbicacionExacta, isFalse);
    });

    test('envía la posición del GPS y "Ubicación exacta del vecino" si la '
        'dirección está vacía', () async {
      final alertas = AlertasFalsas();
      final gps = UbicacionFalsa(posicion: const LatLng(-32.8771, -68.8699));
      final vm = crear(alertas: alertas, ubicacion: gps);
      vm.tituloAlElegir(CategoriaAlerta.robo, tituloActual: '');

      expect(await enviar(vm), isTrue);

      final creada = alertas.creadas.single;
      expect(creada.ubicacion, const LatLng(-32.8771, -68.8699));
      expect(creada.direccion, 'Ubicación exacta del vecino');
    });

    test('si el GPS no responde envía Barrio.centro y "Barrio Soberanía (zona '
        'aproximada)"', () async {
      final alertas = AlertasFalsas();
      final vm = crear(
        alertas: alertas,
        ubicacion: UbicacionFalsa(posicion: null),
      );
      vm.tituloAlElegir(CategoriaAlerta.robo, tituloActual: '');

      expect(await enviar(vm), isTrue);

      final creada = alertas.creadas.single;
      expect(creada.ubicacion, Barrio.centro);
      expect(creada.direccion, 'Barrio Soberanía (zona aproximada)');
    });

    test('sin la preferencia envía Barrio.centro', () async {
      final alertas = AlertasFalsas();
      final gps = UbicacionFalsa();
      final vm = crear(alertas: alertas, compartir: false, ubicacion: gps);
      vm.tituloAlElegir(CategoriaAlerta.robo, tituloActual: '');

      expect(await enviar(vm), isTrue);

      expect(alertas.creadas.single.ubicacion, Barrio.centro);
      expect(
        alertas.creadas.single.direccion,
        'Barrio Soberanía (zona aproximada)',
      );
      expect(gps.posicionesPedidas, 0);

      final sinGps = AlertasFalsas();
      final vmSinGps = crear(alertas: sinGps, tieneGps: false);
      vmSinGps.tituloAlElegir(CategoriaAlerta.robo, tituloActual: '');
      await enviar(vmSinGps);
      expect(sinGps.creadas.single.ubicacion, Barrio.centro);
    });

    test('la dirección escrita viaja sin espacios en los extremos', () async {
      final alertas = AlertasFalsas();
      final vm = crear(alertas: alertas);
      vm.tituloAlElegir(CategoriaAlerta.robo, tituloActual: '');

      await enviar(vm, direccion: '  Cabildo de Mendoza y Ascasubi  ');

      expect(alertas.creadas.single.direccion, 'Cabildo de Mendoza y Ascasubi');
    });

    // --- Envío (R17, R18, R21, R22) ---

    test('enviar crea la alerta con la categoría elegida, el título y la '
        'descripción recortados y el id del vecino', () async {
      final alertas = AlertasFalsas();
      final vm = crear(alertas: alertas);
      vm.tituloAlElegir(CategoriaAlerta.vehiculo, tituloActual: '');

      await enviar(
        vm,
        titulo: '  Auto dando vueltas  ',
        descripcion: '  Un auto gris pasó tres veces.  ',
      );

      final creada = alertas.creadas.single;
      expect(creada.categoria, CategoriaAlerta.vehiculo);
      expect(creada.tipo, 'Auto dando vueltas');
      expect(creada.descripcion, 'Un auto gris pasó tres veces.');
      expect(creada.reportadaPor, 'clara');
    });

    test('enviar con la descripción vacía crea la alerta', () async {
      final alertas = AlertasFalsas();
      final vm = crear(alertas: alertas);
      vm.tituloAlElegir(CategoriaAlerta.ruidos, tituloActual: '');

      expect(await enviar(vm, titulo: 'Ruidos', descripcion: '   '), isTrue);

      expect(alertas.creadas.single.descripcion, '');
      expect(alertas.alertas, hasLength(1));
    });

    test('enviar publica AlertasActualizadas y devuelve true', () async {
      final vm = crear();
      final eventos = <Object>[];
      bus.eventos.listen(eventos.add);
      vm.tituloAlElegir(CategoriaAlerta.robo, tituloActual: '');

      expect(await enviar(vm), isTrue);
      await Future<void>.delayed(Duration.zero);

      expect(eventos.single, isA<AlertasActualizadas>());
      expect(vm.errorDeEnvio, isNull);
    });

    test('mientras envía enviando es true', () async {
      final alertas = _AlertasConDemora();
      final vm = crear(alertas: alertas);
      vm.tituloAlElegir(CategoriaAlerta.robo, tituloActual: '');

      final envio = enviar(vm);
      await Future<void>.delayed(Duration.zero);
      expect(vm.enviando, isTrue);

      alertas.soltar.complete();
      expect(await envio, isTrue);
      expect(vm.enviando, isFalse);
    });

    // --- Validaciones y errores (R24 a R29, R32 a R34, R36, R37) ---

    test('sin tipo marca el error de tipo y no llama a crearAlerta', () async {
      final alertas = AlertasFalsas();
      final vm = crear(alertas: alertas);

      expect(await enviar(vm), isFalse);

      expect(vm.errorDe(CampoReporte.tipo), 'Elegí qué tipo de alerta es.');
      expect(alertas.creadas, isEmpty);
    });

    test(
      'título vacío y descripción larga marcan los dos errores y primerError '
      'es titulo',
      () async {
        final alertas = AlertasFalsas();
        final vm = crear(alertas: alertas);
        vm.tituloAlElegir(CategoriaAlerta.robo, tituloActual: 'x');

        expect(await enviar(vm, titulo: '  ', descripcion: 'a' * 501), isFalse);

        expect(
          vm.errorDe(CampoReporte.titulo),
          'Escribí un título para la alerta.',
        );
        expect(
          vm.errorDe(CampoReporte.descripcion),
          'Acortá la descripción: puede tener hasta 500 letras.',
        );
        expect(vm.errorDe(CampoReporte.tipo), isNull);
        expect(vm.primerError, CampoReporte.titulo);
        expect(alertas.creadas, isEmpty);
      },
    );

    test('sin tipo y con título vacío primerError es tipo', () async {
      final vm = crear();
      await enviar(vm, titulo: '');
      expect(vm.primerError, CampoReporte.tipo);
      expect(
        vm.errorDe(CampoReporte.titulo),
        'Escribí un título para la alerta.',
      );
    });

    test('un título de 61 letras marca su error', () async {
      final vm = crear();
      vm.tituloAlElegir(CategoriaAlerta.robo, tituloActual: '');
      await enviar(vm, titulo: 'a' * 61);
      expect(
        vm.errorDe(CampoReporte.titulo),
        'Acortá el título: puede tener hasta 60 letras.',
      );
      expect(vm.primerError, CampoReporte.titulo);
    });

    test('dirección larga marca su error', () async {
      final alertas = AlertasFalsas();
      final vm = crear(alertas: alertas);
      vm.tituloAlElegir(CategoriaAlerta.robo, tituloActual: '');

      expect(await enviar(vm, direccion: 'a' * 121), isFalse);

      expect(
        vm.errorDe(CampoReporte.direccion),
        'Acortá la dirección: puede tener hasta 120 letras.',
      );
      expect(vm.primerError, CampoReporte.direccion);
      expect(alertas.creadas, isEmpty);
    });

    test('si la API rechaza muestra su mensaje tal cual', () async {
      final alertas = AlertasFalsas()
        ..errorAlCrear = const ErrorDelServidor('La ubicación no es válida.');
      final vm = crear(alertas: alertas);
      vm.tituloAlElegir(CategoriaAlerta.robo, tituloActual: '');

      expect(await enviar(vm), isFalse);

      expect(vm.errorDeEnvio, 'La ubicación no es válida.');
      expect(vm.enviando, isFalse);
    });

    test(
      'sin conexión muestra "No pudimos enviar la alerta. Revisá tu conexión '
      'y probá de nuevo."',
      () async {
        final vm = crear(alertas: AlertasFalsas([], true));
        vm.tituloAlElegir(CategoriaAlerta.robo, tituloActual: '');

        expect(await enviar(vm), isFalse);

        expect(
          vm.errorDeEnvio,
          'No pudimos enviar la alerta. Revisá tu conexión y probá de nuevo.',
        );
      },
    );

    test('si falla, el tipo elegido sigue elegido', () async {
      final vm = crear(alertas: AlertasFalsas([], true));
      vm.tituloAlElegir(CategoriaAlerta.vehiculo, tituloActual: '');

      await enviar(vm, titulo: 'Vehículo sospechoso');

      expect(vm.tipo, CategoriaAlerta.vehiculo);
      expect(vm.errorDeEnvio, isNotNull);
    });

    test('hayDatos es false sin tipo ni texto (solo espacios) y true con '
        'cualquiera de los dos', () {
      final vm = crear();
      expect(
        vm.hayDatos(titulo: ' ', descripcion: '  ', direccion: '\n'),
        isFalse,
      );
      expect(
        vm.hayDatos(titulo: '', descripcion: 'algo', direccion: ''),
        isTrue,
      );
      expect(
        vm.hayDatos(titulo: '', descripcion: '', direccion: 'Cabildo'),
        isTrue,
      );
      expect(
        vm.hayDatos(titulo: 'Robo', descripcion: '', direccion: ''),
        isTrue,
      );
      vm.tituloAlElegir(CategoriaAlerta.robo, tituloActual: '');
      expect(vm.hayDatos(titulo: '', descripcion: '', direccion: ''), isTrue);
    });
  });
}

/// [AlertasFalsas] que no responde a `crearAlerta` hasta que la prueba
/// completa [soltar].
class _AlertasConDemora extends AlertasFalsas {
  final soltar = Completer<void>();

  @override
  Future<Alerta> crearAlerta({
    required CategoriaAlerta categoria,
    required String tipo,
    required String descripcion,
    required String direccion,
    required LatLng ubicacion,
    required String reportadaPor,
  }) async {
    await soltar.future;
    return super.crearAlerta(
      categoria: categoria,
      tipo: tipo,
      descripcion: descripcion,
      direccion: direccion,
      ubicacion: ubicacion,
      reportadaPor: reportadaPor,
    );
  }
}
