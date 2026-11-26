// Pruebas de la app completa: arranque, SOS sin red, la pantalla sin
// conexión que tapa a todas las demás y el informe mensual de alertas
// para la comisión.

import 'dart:async';
import 'dart:io';

import 'package:barrio_seguro/data/repositories/alertas_repository.dart';
import 'package:barrio_seguro/data/repositories/turnos_repository.dart';
import 'package:barrio_seguro/data/services/bus_de_eventos.dart';
import 'package:barrio_seguro/data/services/error_del_servidor.dart';
import 'package:barrio_seguro/data/services/local/preferencias.dart';
import 'package:barrio_seguro/data/services/simulados/conexion_service_simulado.dart';
import 'package:barrio_seguro/dependencias.dart';
import 'package:barrio_seguro/domain/evento_de_app.dart';
import 'package:barrio_seguro/domain/models/alerta.dart';
import 'package:barrio_seguro/domain/models/turno.dart';
import 'package:barrio_seguro/domain/models/vecino.dart';
import 'package:barrio_seguro/domain/reglas_alertas.dart';
import 'package:barrio_seguro/main.dart';
import 'package:barrio_seguro/ui/alerta_detalle/view_models/detalle_alerta_view_model.dart';
import 'package:barrio_seguro/ui/alerta_detalle/widgets/detalle_alerta_screen.dart';
import 'package:barrio_seguro/ui/core/widgets/con_view_model.dart';
import 'package:barrio_seguro/ui/core/widgets/boton_sos.dart';
import 'package:barrio_seguro/ui/core/widgets/chip_estado.dart';
import 'package:barrio_seguro/ui/core/widgets/mapa_barrio.dart';
import 'package:barrio_seguro/ui/core/widgets/marca_sos.dart';
import 'package:barrio_seguro/ui/core/widgets/marca_tardia.dart';
import 'package:barrio_seguro/ui/core/widgets/pin_alerta.dart';
import 'package:barrio_seguro/ui/core/widgets/tarjeta_alerta.dart';
import 'package:barrio_seguro/ui/core/widgets/tarjeta_tocable.dart';
import 'package:barrio_seguro/ui/core/tema/app_theme.dart';
import 'package:barrio_seguro/ui/core/ubicacion_de_alerta.dart';
import 'package:barrio_seguro/ui/inicio/widgets/inicio_screen.dart';
import 'package:barrio_seguro/ui/perfil/view_models/perfil_view_model.dart';
import 'package:barrio_seguro/ui/perfil/widgets/perfil_screen.dart';
import 'package:barrio_seguro/ui/reportar_alerta/view_models/reportar_alerta_view_model.dart';
import 'package:barrio_seguro/ui/reportar_alerta/widgets/reportar_alerta_screen.dart';
import 'package:barrio_seguro/ui/sos/view_models/sos_view_model.dart';
import 'package:barrio_seguro/ui/sos/widgets/sos_screen.dart';
import 'package:barrio_seguro/ui/turno_incompleto/widgets/tarjeta_turno_incompleto.dart';
import 'package:barrio_seguro/ui/turnos/view_models/turnos_view_model.dart';
import 'package:barrio_seguro/ui/turnos/widgets/turnos_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'ayudas/app_de_prueba.dart';
import 'ayudas/bases_de_prueba.dart';
import 'ayudas/falsos.dart';

const tituloSinConexion = 'Necesitás conexión a internet para usar la app';

/// Deja pasar el próximo ciclo de comprobación (30 s con conexión, 5 s
/// sin conexión) y que se dibuje lo que cambió.
Future<void> esperarComprobacion(
  WidgetTester tester, {
  Duration cada = const Duration(seconds: 30),
}) async {
  await tester.pump(cada);
  await tester.pumpAndSettle();
}

Future<void> ingresar(WidgetTester tester) async {
  await tester.tap(find.text('Ingresar'));
  await tester.pumpAndSettle();
  expect(find.text('Hola, Clara'), findsOneWidget);
}

/// Una pantalla de 540 x 1200 dp: el detalle entero (con el control de
/// estado) entra sin desplazar.
void pantallaAlta(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

Future<void> _tocar(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('La app abre en el login y entra al inicio', (tester) async {
    await tester.pumpWidget(appDePrueba());
    await tester.pumpAndSettle();

    expect(find.text('Barrio Seguro'), findsOneWidget);

    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();

    expect(find.text('Hola, Clara'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets(
    'el SOS sin red muestra "No pudimos enviar la alerta. Probá de nuevo o llamá al 911."',
    (tester) async {
      final vm = SosViewModel(
        alertas: AlertasRepositoryRemoto(
          service: AlertasServiceQueFalla(const SocketException('sin señal')),
        ),
        sesion: SesionFalsa(vecinaDePrueba),
        bus: BusDeEventos(),
        preferencias: preferenciasEnMemoria(),
        ubicacion: UbicacionFalsa(),
        capacidades: const CapacidadesFalsas(),
      );
      addTearDown(vm.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: SosScreen(
            viewModel: vm,
            capacidades: const CapacidadesFalsas(),
            telefono: TelefonoFalso(),
          ),
        ),
      );

      await tester.tap(find.text('Sí, enviar alerta'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'No pudimos enviar la alerta. Probá de nuevo o llamá al 911.',
        ),
        findsOneWidget,
      );
      expect(find.text('Volver a intentar'), findsOneWidget);
      expect(find.text('Alerta enviada'), findsNothing);
      expect(find.text('Alerta guardada'), findsNothing);
    },
  );

  group('Sin conexión', () {
    testWidgets(
      'al arrancar comprueba la conexión y sin conexión el login muestra "$tituloSinConexion"',
      (tester) async {
        final conexion = ConexionFalsa(hay: false);
        await tester.pumpWidget(appDePrueba(conexion: conexion));
        await tester.pumpAndSettle();

        expect(conexion.comprobaciones, 1);
        expect(find.text(tituloSinConexion), findsOneWidget);
        expect(find.text('Llamar al 911'), findsOneWidget);
        expect(find.text('Ingresar'), findsNothing);
        expect(find.text('Barrio Seguro'), findsNothing);
      },
    );

    testWidgets(
      'sin conexión con sesión abierta se tapa la principal y no se ven alertas ni turnos guardados',
      (tester) async {
        final semantica = tester.ensureSemantics();
        // Pantalla alta: así las tarjetas de alertas de la lista se
        // construyen sin desplazar.
        tester.view.devicePixelRatio = 3;
        tester.view.physicalSize = const Size(360 * 3, 2400 * 3);
        addTearDown(tester.view.reset);
        MapaBarrio.cargarCalles = false;
        final conexion = ConexionServiceSimulado();
        final alertasDao = AlertasDaoEnMemoria();
        final turnosDao = TurnosDaoEnMemoria();
        await tester.pumpWidget(
          BarrioSeguroApp(
            dependencias: Dependencias.simuladas(
              reloj: relojDePrueba,
              demora: Duration.zero,
              capacidades: const CapacidadesFalsas(),
              politicas: const PoliticasFalsas(),
              telefono: TelefonoFalso(),
              ubicacion: UbicacionFalsa(),
              notificaciones: NotificacionesFalsas(),
              push: PushFalso(),
              conexion: conexion,
              preferencias: preferenciasEnMemoria(),
              almacenSeguro: almacenSeguroEnMemoria(),
              alertasDao: alertasDao,
              turnosDao: turnosDao,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await ingresar(tester);

        // La principal guardó su copia en el teléfono.
        expect(alertasDao.guardadas, isNotEmpty);
        expect(turnosDao.guardados, isNotEmpty);
        // Una alerta guardada que la principal muestra en pantalla.
        final direccion = alertasDao.guardadas
            .map((a) => a.direccion)
            .firstWhere((d) => find.text(d).evaluate().isNotEmpty);
        expect(find.text(direccion), findsWidgets);
        expect(
          find.semantics.byLabel(RegExp(RegExp.escape(direccion))),
          findsWidgets,
        );
        // La tarjeta del próximo turno, armada con los turnos guardados.
        const tituloTurno = 'Tu próximo turno de patrullaje';
        expect(find.text(tituloTurno), findsOneWidget);
        expect(
          find.semantics.byLabel(RegExp(RegExp.escape(tituloTurno))),
          findsWidgets,
        );

        conexion.conectado = false;
        await esperarComprobacion(tester);

        expect(find.text(tituloSinConexion), findsOneWidget);
        expect(find.text('Hola, Clara'), findsNothing);
        expect(find.text(direccion), findsNothing);
        expect(find.byType(BotonSos), findsNothing);
        // El lector de pantalla tampoco las lee.
        expect(find.semantics.byLabel(RegExp('Hola, Clara')), findsNothing);
        expect(
          find.semantics.byLabel(RegExp(RegExp.escape(direccion))),
          findsNothing,
        );
        expect(find.text(tituloTurno), findsNothing);
        expect(
          find.semantics.byLabel(RegExp(RegExp.escape(tituloTurno))),
          findsNothing,
        );
        expect(find.semantics.byLabel(tituloSinConexion), findsOneWidget);
        semantica.dispose();
      },
    );

    testWidgets(
      'si se corta la conexión con el SOS abierto aparece la pantalla sin conexión y al volver se ve el SOS como estaba',
      (tester) async {
        final conexion = ConexionServiceSimulado();
        await tester.pumpWidget(appDePrueba(conexion: conexion));
        await tester.pumpAndSettle();
        await ingresar(tester);
        await tester.tap(find.byType(BotonSos));
        await tester.pumpAndSettle();
        expect(find.text('¿Enviar alerta SOS?'), findsOneWidget);

        conexion.conectado = false;
        await esperarComprobacion(tester);

        expect(find.text(tituloSinConexion), findsOneWidget);
        expect(find.text('¿Enviar alerta SOS?'), findsNothing);

        conexion.conectado = true;
        await esperarComprobacion(tester, cada: const Duration(seconds: 5));

        expect(find.text(tituloSinConexion), findsNothing);
        expect(find.text('¿Enviar alerta SOS?'), findsOneWidget);

        // Con la alerta ya enviada, al volver sigue en "Alerta enviada".
        await tester.tap(find.text('Sí, enviar alerta'));
        await tester.pumpAndSettle();
        expect(find.text('Alerta enviada'), findsOneWidget);

        conexion.conectado = false;
        await esperarComprobacion(tester);
        expect(find.text('Alerta enviada'), findsNothing);

        conexion.conectado = true;
        await esperarComprobacion(tester, cada: const Duration(seconds: 5));
        expect(find.text('Alerta enviada'), findsOneWidget);
        expect(find.text('Ya estoy a salvo'), findsOneWidget);
      },
    );

    testWidgets('el texto escrito en el login sigue al volver', (tester) async {
      final conexion = ConexionServiceSimulado();
      await tester.pumpWidget(appDePrueba(conexion: conexion));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Teléfono'),
        '2615550123',
      );
      await tester.pump();

      conexion.conectado = false;
      await esperarComprobacion(tester);
      expect(find.text(tituloSinConexion), findsOneWidget);
      expect(find.text('2615550123'), findsNothing);

      conexion.conectado = true;
      await esperarComprobacion(tester, cada: const Duration(seconds: 5));

      expect(find.text(tituloSinConexion), findsNothing);
      expect(find.text('2615550123'), findsOneWidget);
    });

    testWidgets(
      'el formulario de reportar alerta conserva lo escrito al volver la '
      'conexión',
      (tester) async {
        final conexion = ConexionServiceSimulado();
        await tester.pumpWidget(appDePrueba(conexion: conexion));
        await tester.pumpAndSettle();
        await ingresar(tester);
        await _tocar(
          tester,
          find.ancestor(
            of: find.text('Reportar alerta'),
            matching: find.byWidgetPredicate((w) => w is FilledButton),
          ),
        );
        await _tocar(
          tester,
          find.widgetWithText(RadioListTile<CategoriaAlerta>, 'Ruidos'),
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Título'),
          'Ruidos en el baldío',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Descripción (opcional)'),
          'Golpes y linternas.',
        );
        await tester.pump();

        conexion.conectado = false;
        await esperarComprobacion(tester);
        expect(find.text(tituloSinConexion), findsOneWidget);
        expect(find.text('Ruidos en el baldío'), findsNothing);

        conexion.conectado = true;
        await esperarComprobacion(tester, cada: const Duration(seconds: 5));

        expect(find.text(tituloSinConexion), findsNothing);
        expect(find.byType(ReportarAlertaScreen), findsOneWidget);
        expect(find.text('Ruidos en el baldío'), findsOneWidget);
        expect(find.text('Golpes y linternas.'), findsOneWidget);
        expect(
          tester
              .widget<RadioGroup<CategoriaAlerta>>(
                find.byType(RadioGroup<CategoriaAlerta>),
              )
              .groupValue,
          CategoriaAlerta.ruidos,
        );
      },
    );

    testWidgets('"Llamar al 911" sin conexión abre el teléfono con el 911', (
      tester,
    ) async {
      final telefono = TelefonoFalso();
      await tester.pumpWidget(
        appDePrueba(
          conexion: ConexionServiceSimulado(conectado: false),
          telefono: telefono,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Llamar al 911'));
      await tester.pumpAndSettle();
      expect(find.text('¿Llamar al 911?'), findsOneWidget);
      await tester.tap(find.text('Llamar'));
      await tester.pumpAndSettle();

      expect(telefono.marcados, ['911']);
    });

    testWidgets('sin poder llamar muestra "Llamá al 911 desde un teléfono"', (
      tester,
    ) async {
      final telefono = TelefonoFalso();
      await tester.pumpWidget(
        appDePrueba(
          capacidades: const CapacidadesFalsas(puedeHacerLlamadas: false),
          conexion: ConexionServiceSimulado(conectado: false),
          telefono: telefono,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Llamar al 911'));
      await tester.pumpAndSettle();

      expect(find.text('Llamá al 911 desde un teléfono'), findsOneWidget);
      expect(telefono.marcados, isEmpty);
    });

    testWidgets(
      'sin conexión el botón Atrás no cierra el SOS tapado y al volver se ve el SOS',
      (tester) async {
        final conexion = ConexionServiceSimulado();
        await tester.pumpWidget(appDePrueba(conexion: conexion));
        await tester.pumpAndSettle();
        await ingresar(tester);
        await tester.tap(find.byType(BotonSos));
        await tester.pumpAndSettle();
        expect(find.text('¿Enviar alerta SOS?'), findsOneWidget);

        conexion.conectado = false;
        await esperarComprobacion(tester);
        expect(find.text(tituloSinConexion), findsOneWidget);

        final atendido = await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(atendido, isTrue);
        expect(find.text(tituloSinConexion), findsOneWidget);

        conexion.conectado = true;
        await esperarComprobacion(tester, cada: const Duration(seconds: 5));

        expect(find.text(tituloSinConexion), findsNothing);
        expect(find.text('¿Enviar alerta SOS?'), findsOneWidget);
      },
    );

    testWidgets('sin conexión el botón Atrás en el inicio no cierra la app', (
      tester,
    ) async {
      final conexion = ConexionServiceSimulado();
      await tester.pumpWidget(appDePrueba(conexion: conexion));
      await tester.pumpAndSettle();
      await ingresar(tester);

      conexion.conectado = false;
      await esperarComprobacion(tester);
      expect(find.text(tituloSinConexion), findsOneWidget);

      // true: no se llega a SystemNavigator.pop().
      final atendido = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(atendido, isTrue);
      expect(find.text(tituloSinConexion), findsOneWidget);

      conexion.conectado = true;
      await esperarComprobacion(tester, cada: const Duration(seconds: 5));

      expect(find.text(tituloSinConexion), findsNothing);
      expect(find.text('Hola, Clara'), findsOneWidget);
    });

    testWidgets('con conexión el botón Atrás cierra el SOS como siempre', (
      tester,
    ) async {
      await tester.pumpWidget(appDePrueba());
      await tester.pumpAndSettle();
      await ingresar(tester);
      await tester.tap(find.byType(BotonSos));
      await tester.pumpAndSettle();
      expect(find.text('¿Enviar alerta SOS?'), findsOneWidget);

      final atendido = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(atendido, isTrue);
      expect(find.text('¿Enviar alerta SOS?'), findsNothing);
      expect(find.text('Hola, Clara'), findsOneWidget);
    });
  });

  group('Informe de alertas para la comisión', () {
    testWidgets(
      'un miembro de la comisión ve la opción, consulta el informe, descarga el CSV y ve el aviso en un mes sin alertas',
      (tester) async {
        tester.view.devicePixelRatio = 3;
        tester.view.physicalSize = const Size(360 * 3, 1600 * 3);
        addTearDown(tester.view.reset);

        final descargaCsv = DescargaCsvFalsa();
        await tester.pumpWidget(appDePrueba(descargaCsv: descargaCsv));
        await tester.pumpAndSettle();
        await _tocar(tester, find.text('Ingresar'));

        await _tocar(
          tester,
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Perfil'),
          ),
        );

        expect(find.text('Informe mensual de alertas'), findsOneWidget);
        await _tocar(tester, find.text('Informe mensual de alertas'));

        // En octubre 2026 están las alertas de ejemplo.
        expect(find.text('Informe de alertas'), findsOneWidget);
        expect(find.text('Octubre 2026'), findsOneWidget);
        expect(find.text('Por calle'), findsOneWidget);
        expect(find.text('Por tipo de alerta'), findsOneWidget);
        expect(find.text('Por franja horaria'), findsOneWidget);
        expect(find.text('Calle Plantamura'), findsOneWidget);
        expect(find.text('Intento de robo'), findsOneWidget);

        // Descargar el archivo CSV.
        await _tocar(tester, find.text('Descargar informe (CSV)'));
        expect(descargaCsv.descargas, 1);
        expect(descargaCsv.ultimoNombre, 'informe_alertas_2026_10.csv');
        expect(
          find.text('Informe descargado: informe_alertas_2026_10.csv'),
          findsOneWidget,
        );

        // Cambiar a noviembre 2026 (sin alertas).
        await _tocar(tester, find.byTooltip('Mes siguiente'));
        expect(find.text('Noviembre 2026'), findsOneWidget);
        expect(
          find.text('No hubo alertas registradas en noviembre 2026.'),
          findsOneWidget,
        );
        expect(find.text('Por calle'), findsNothing);
        expect(find.text('Por tipo de alerta'), findsNothing);
        expect(find.text('Por franja horaria'), findsNothing);
        expect(find.text('Descargar informe (CSV)'), findsNothing);
      },
    );

    testWidgets(
      'para un vecino común la opción del informe no aparece en el perfil',
      (tester) async {
        final dependencias = Dependencias.simuladas(
          reloj: relojDePrueba,
          demora: Duration.zero,
          capacidades: const CapacidadesFalsas(),
          politicas: const PoliticasFalsas(),
          telefono: TelefonoFalso(),
          ubicacion: UbicacionFalsa(),
          notificaciones: NotificacionesFalsas(),
          push: PushFalso(),
          descargaCsv: DescargaCsvFalsa(),
          preferencias: preferenciasEnMemoria(),
          almacenSeguro: almacenSeguroEnMemoria(),
        );

        // vecinaDePrueba tiene RolVecino.vecino.
        await tester.pumpWidget(
          MaterialApp(
            home: ConViewModel(
              crear: () => PerfilViewModel(
                sesion: SesionFalsa(vecinaDePrueba),
                bus: dependencias.bus,
                reloj: dependencias.reloj,
                capacidades: dependencias.capacidades,
                politicas: dependencias.politicas,
                preferencias: dependencias.preferencias,
                ubicacion: dependencias.ubicacion,
                notificacionesService: dependencias.notificaciones,
                pushService: dependencias.push,
              )..cargar(),
              builder: (_, vm) => PerfilScreen(
                viewModel: vm,
                dependencias: dependencias,
                onIrA: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Mi perfil'), findsOneWidget);
        expect(find.text('Mis alertas reportadas'), findsOneWidget);
        expect(find.text('Informe mensual de alertas'), findsNothing);
      },
    );
  });

  group('Perfil: guardia normal', () {
    const titulo = 'Hacer guardia normal (patrulla)';
    const textoApagado =
        'Hacés guardia de ventana desde tu casa. Los turnos que ya tomaste '
        'no cambian.';
    const textoPrendido =
        'Te anotás en la patrulla, como el resto. Los turnos que ya tomaste '
        'no cambian.';

    /// Arma el perfil del vecino de [sesion] con las dependencias simuladas.
    Future<void> abrirPerfil(WidgetTester tester, SesionFalsa sesion) async {
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = const Size(360 * 3, 1600 * 3);
      addTearDown(tester.view.reset);
      final dependencias = Dependencias.simuladas(
        reloj: relojDePrueba,
        demora: Duration.zero,
        capacidades: const CapacidadesFalsas(),
        politicas: const PoliticasFalsas(),
        telefono: TelefonoFalso(),
        ubicacion: UbicacionFalsa(),
        notificaciones: NotificacionesFalsas(),
        push: PushFalso(),
        descargaCsv: DescargaCsvFalsa(),
        preferencias: preferenciasEnMemoria(),
        almacenSeguro: almacenSeguroEnMemoria(),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ConViewModel(
            crear: () => PerfilViewModel(
              sesion: sesion,
              bus: dependencias.bus,
              reloj: dependencias.reloj,
              capacidades: dependencias.capacidades,
              politicas: dependencias.politicas,
              preferencias: dependencias.preferencias,
              ubicacion: dependencias.ubicacion,
              notificacionesService: dependencias.notificaciones,
              pushService: dependencias.push,
            )..cargar(),
            builder: (_, vm) => PerfilScreen(
              viewModel: vm,
              dependencias: dependencias,
              onIrA: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    SwitchListTile interruptor(WidgetTester tester) => tester
        .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, titulo));

    testWidgets('un menor no ve la opción', (tester) async {
      await abrirPerfil(tester, SesionFalsa(vecinaDePrueba));

      expect(find.text('Mi perfil'), findsOneWidget);
      expect(find.text(titulo), findsNothing);
      expect(find.text('Turnos'), findsNothing);
      expect(find.text('Turnos: patrullaje'), findsOneWidget);
    });

    testWidgets('un mayor la ve apagada con su texto', (tester) async {
      await abrirPerfil(tester, SesionFalsa(vecinoMayor));

      expect(find.text('Turnos'), findsOneWidget);
      expect(find.text(titulo), findsOneWidget);
      expect(interruptor(tester).value, isFalse);
      expect(interruptor(tester).onChanged, isNotNull);
      expect(find.text(textoApagado), findsOneWidget);
      expect(find.text('Turnos: guardia de ventana'), findsOneWidget);
    });

    testWidgets('al tocarla espera al servidor y después queda prendida', (
      tester,
    ) async {
      final sesion = SesionFalsa(vecinoMayor)
        ..demoraAlCambiarGuardia = Completer<void>();
      await abrirPerfil(tester, sesion);

      await _tocar(tester, find.text(titulo));

      expect(sesion.cambiosDeGuardiaNormal, [true]);
      expect(find.text('Guardando el cambio'), findsOneWidget);
      expect(interruptor(tester).onChanged, isNull);
      expect(interruptor(tester).value, isFalse);

      sesion.demoraAlCambiarGuardia!.complete();
      await tester.pumpAndSettle();

      expect(interruptor(tester).value, isTrue);
      expect(interruptor(tester).onChanged, isNotNull);
      expect(find.text(textoPrendido), findsOneWidget);
      expect(find.text('Guardando el cambio'), findsNothing);
      expect(find.text('Turnos: patrullaje'), findsOneWidget);
    });

    testWidgets('si el servidor la rechaza muestra el mensaje y queda '
        'apagada', (tester) async {
      const mensaje =
          'Solo los vecinos de 70 años o más pueden elegir la guardia normal.';
      final sesion = SesionFalsa(vecinoMayor)
        ..errorAlCambiarGuardia = const ErrorDelServidor(mensaje);
      await abrirPerfil(tester, sesion);

      await _tocar(tester, find.text(titulo));

      expect(find.text(mensaje), findsOneWidget);
      expect(interruptor(tester).value, isFalse);
      expect(find.text(textoApagado), findsOneWidget);
      expect(find.text('Turnos: guardia de ventana'), findsOneWidget);
      expect(sesion.usuario?.guardiaNormal, isFalse);
    });

    testWidgets('sin conexión muestra el aviso de conexión y queda apagada', (
      tester,
    ) async {
      final sesion = SesionFalsa(vecinoMayor)
        ..falloAlCambiarGuardia = const SocketException('sin red');
      await abrirPerfil(tester, sesion);

      await _tocar(tester, find.text(titulo));

      expect(
        find.text(
          'No pudimos guardar el cambio. Revisá tu conexión y probá de nuevo.',
        ),
        findsOneWidget,
      );
      expect(interruptor(tester).value, isFalse);
      expect(find.text(textoApagado), findsOneWidget);
      expect(sesion.usuario?.guardiaNormal, isFalse);
    });

    testWidgets('al activar la guardia normal, Turnos ofrece "Anotarme" sin '
        'recargar', (tester) async {
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = const Size(360 * 3, 1600 * 3);
      addTearDown(tester.view.reset);
      final bus = BusDeEventos();
      addTearDown(bus.cerrar);
      final sesion = SesionFalsa(vecinoMayor);
      await tester.pumpWidget(
        MaterialApp(
          home: ConViewModel(
            crear: () => TurnosViewModel(
              turnos: TurnosFalsos(),
              sesion: sesion,
              bus: bus,
              reloj: relojDePrueba,
              mes: DateTime(2026, 10),
            )..cargar(),
            builder: (_, vm) => TurnosScreen(viewModel: vm),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // El 1/10, sin turnos: los tres horarios ofrecen la guardia.
      expect(find.text('Anotarme como guardia de ventana'), findsWidgets);
      expect(find.text('Anotarme'), findsNothing);

      sesion.usuario = Vecino.fromJson({
        ...vecinoMayor.toJson(),
        'guardia_normal': true,
      });
      bus.publicar(const PerfilActualizado());
      await tester.pumpAndSettle();

      expect(find.text('Anotarme'), findsWidgets);
      expect(find.text('Anotarme como guardia de ventana'), findsNothing);
    });
  });

  group('Alertas tardías', () {
    // El reloj de prueba marca las 12:00. En los datos de ejemplo, a3
    // ("Intento de robo", de Pedro) es de las 11:00 y a2 ("Moto a alta
    // velocidad", de Martín) de las 11:42.
    final llegadas = {
      'a3': DateTime(2026, 10, 1, 11, 30), // 30 minutos tarde
      'a2': DateTime(2026, 10, 1, 11, 43), // a tiempo
    };
    const marca = 'Llegó con demora. Alerta de las 11:00';

    Future<void> abrir(
      WidgetTester tester, {
      Map<String, DateTime>? conLlegadas,
    }) async {
      await tester.pumpWidget(appDePrueba(llegadas: conLlegadas ?? llegadas));
      await tester.pumpAndSettle();
      await ingresar(tester);
    }

    Future<void> irAlMapa(WidgetTester tester) async {
      await _tocar(
        tester,
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Mapa'),
        ),
      );
    }

    Finder tarjeta(String tipo) => find.widgetWithText(TarjetaAlerta, tipo);

    Finder pin(String tipo) => find.bySemanticsLabel(RegExp('^Alerta: $tipo'));

    testWidgets(
      'el inicio muestra "Llegó con demora. Alerta de las …" en la tarjeta de una alerta tardía',
      (tester) async {
        await abrir(tester);

        await tester.scrollUntilVisible(tarjeta('Intento de robo'), 200);
        expect(
          find.descendant(
            of: tarjeta('Intento de robo'),
            matching: find.text(marca),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('una alerta a tiempo no muestra la marca', (tester) async {
      await abrir(tester, conLlegadas: {'a2': llegadas['a2']!});

      await tester.scrollUntilVisible(tarjeta('Moto a alta velocidad'), 200);
      expect(find.textContaining('Llegó con demora'), findsNothing);
      expect(find.byType(MarcaTardia), findsNothing);

      await irAlMapa(tester);
      expect(
        find.descendant(
          of: pin('Moto a alta velocidad'),
          matching: find.byIcon(Icons.schedule),
        ),
        findsNothing,
      );

      await _tocar(tester, pin('Moto a alta velocidad'));
      expect(find.byType(MarcaTardia), findsNothing);
      await _tocar(tester, find.text('Ver detalle'));
      expect(find.text('Detalle de alerta'), findsOneWidget);
      expect(find.byType(MarcaTardia), findsNothing);
    });

    testWidgets(
      'el pin de una alerta tardía tiene el reloj y el resumen muestra la marca',
      (tester) async {
        await abrir(tester);
        await irAlMapa(tester);

        expect(
          find.descendant(
            of: pin('Intento de robo'),
            matching: find.byIcon(Icons.schedule),
          ),
          findsOneWidget,
        );
        // Las demás no llevan el reloj.
        expect(
          find.descendant(
            of: pin('Moto a alta velocidad'),
            matching: find.byIcon(Icons.schedule),
          ),
          findsNothing,
        );

        await _tocar(tester, pin('Intento de robo'));
        expect(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.text(marca),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('el detalle de una alerta tardía muestra la marca', (
      tester,
    ) async {
      await abrir(tester);
      await tester.scrollUntilVisible(tarjeta('Intento de robo'), 200);
      await _tocar(tester, tarjeta('Intento de robo'));

      expect(find.text('Detalle de alerta'), findsOneWidget);
      expect(find.text(marca), findsOneWidget);
    });

    testWidgets('la leyenda muestra "Llegó con demora"', (tester) async {
      await abrir(tester);
      await irAlMapa(tester);

      final item = find.ancestor(
        of: find.text('Llegó con demora'),
        matching: find.byType(Row),
      );
      expect(item, findsOneWidget);
      final muestra = tester.widget<PinAlerta>(
        find.descendant(of: item, matching: find.byType(PinAlerta)),
      );
      expect(muestra.tardia, isTrue);
    });

    testWidgets('la marca tiene ícono de reloj y texto', (tester) async {
      await abrir(tester);
      await tester.scrollUntilVisible(tarjeta('Intento de robo'), 200);

      final marcaEnTarjeta = find.descendant(
        of: tarjeta('Intento de robo'),
        matching: find.byType(MarcaTardia),
      );
      expect(
        find.descendant(
          of: marcaEnTarjeta,
          matching: find.byIcon(Icons.schedule),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: marcaEnTarjeta, matching: find.text(marca)),
        findsOneWidget,
      );
    });

    testWidgets(
      'el detalle de una alerta ajena muestra el nombre de quien la reportó',
      (tester) async {
        await abrir(tester);
        await tester.scrollUntilVisible(tarjeta('Intento de robo'), 200);
        await _tocar(tester, tarjeta('Intento de robo'));

        final reportadaPor = find.widgetWithText(ListTile, 'Reportada por');
        await tester.ensureVisible(reportadaPor);
        expect(
          find.descendant(of: reportadaPor, matching: find.text('Pedro')),
          findsOneWidget,
        );
        expect(find.text('Un vecino de la zona'), findsNothing);
      },
    );

    testWidgets(
      'el detalle de una alerta ajena sin nombre muestra "Un vecino"',
      (tester) async {
        MapaBarrio.cargarCalles = false;
        final alerta = alertaDePrueba(reportadaPor: 'jorge');
        final vm = DetalleAlertaViewModel(
          alerta: alerta,
          alertas: AlertasFalsas([alerta]),
          sesion: SesionFalsa(vecinaDePrueba),
          bus: BusDeEventos(),
          reloj: relojDePrueba,
          avisos: AvisosRecibidosFalsos(),
        );
        addTearDown(vm.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: DetalleAlertaScreen(
              viewModel: vm,
              capacidades: const CapacidadesFalsas(),
              telefono: TelefonoFalso(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final reportadaPor = find.widgetWithText(ListTile, 'Reportada por');
        await tester.ensureVisible(reportadaPor);
        expect(
          find.descendant(of: reportadaPor, matching: find.text('Un vecino')),
          findsOneWidget,
        );
      },
    );

    testWidgets('el detalle de una alerta propia muestra "Vos"', (
      tester,
    ) async {
      await abrir(tester);
      // a1, "Actividad sospechosa", la reportó Clara (la vecina de prueba).
      await tester.scrollUntilVisible(tarjeta('Actividad sospechosa'), 200);
      await _tocar(tester, tarjeta('Actividad sospechosa'));

      final reportadaPor = find.widgetWithText(ListTile, 'Reportada por');
      await tester.ensureVisible(reportadaPor);
      expect(
        find.descendant(of: reportadaPor, matching: find.text('Vos')),
        findsOneWidget,
      );
      expect(find.text('Clara'), findsNothing);
    });

    testWidgets('la tarjeta y el resumen del mapa no muestran quién reportó', (
      tester,
    ) async {
      await abrir(tester);
      await tester.scrollUntilVisible(tarjeta('Intento de robo'), 200);
      expect(
        find.descendant(
          of: tarjeta('Intento de robo'),
          matching: find.textContaining('Pedro'),
        ),
        findsNothing,
      );
      expect(
        tester
            .getSemantics(find.bySemanticsLabel(RegExp('^Alerta de intento')))
            .label,
        isNot(contains('Pedro')),
      );

      await irAlMapa(tester);
      expect(
        tester.getSemantics(pin('Intento de robo')).label,
        isNot(contains('Pedro')),
      );
      await _tocar(tester, pin('Intento de robo'));
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.textContaining('Pedro'),
        ),
        findsNothing,
      );
    });
  });

  group('SOS enviado', () {
    const avisoSigueActiva =
        'Tu alerta sigue activa. La encontrás en Perfil, en '
        '"Mis alertas reportadas".';

    late AlertasFalsas alertas;
    late SosViewModel vm;

    /// Una pantalla base con un botón que empuja el SOS, como hace el
    /// inicio: así se ve si el SOS se cierra y qué aviso queda. Deja el SOS
    /// ya enviado.
    Future<void> abrirSosEnviado(WidgetTester tester) async {
      alertas = AlertasFalsas();
      vm = SosViewModel(
        alertas: alertas,
        sesion: SesionFalsa(vecinaDePrueba),
        bus: BusDeEventos(),
        preferencias: preferenciasEnMemoria(),
        ubicacion: UbicacionFalsa(),
        capacidades: const CapacidadesFalsas(),
      );
      addTearDown(vm.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      fullscreenDialog: true,
                      builder: (_) => SosScreen(
                        viewModel: vm,
                        capacidades: const CapacidadesFalsas(),
                        telefono: TelefonoFalso(),
                      ),
                    ),
                  ),
                  child: const Text('Pantalla base'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Pantalla base'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sí, enviar alerta'));
      await tester.pumpAndSettle();
      expect(find.text('Alerta enviada'), findsOneWidget);
    }

    void sigueAbiertoYActivo() {
      expect(find.text('Alerta enviada'), findsOneWidget);
      expect(alertas.alertas.single.estado, EstadoAlerta.activa);
      expect(alertas.cambiosDeEstado, 0);
    }

    void cerradoConAviso(String aviso) {
      expect(find.text('Alerta enviada'), findsNothing);
      expect(find.text('Pantalla base'), findsOneWidget);
      expect(find.text(aviso), findsOneWidget);
    }

    testWidgets('la pantalla del SOS enviado muestra "Volver"', (tester) async {
      await abrirSosEnviado(tester);

      final volver = find.widgetWithText(OutlinedButton, 'Volver');
      expect(volver, findsOneWidget);
      // Debajo de "Fue una falsa alarma".
      final falsaAlarma = find.widgetWithText(
        OutlinedButton,
        'Fue una falsa alarma',
      );
      expect(
        tester.getTopLeft(volver).dy,
        greaterThan(tester.getTopLeft(falsaAlarma).dy),
      );
    });

    testWidgets(
      '"Volver" cierra el SOS, deja la alerta activa y avisa dónde encontrarla',
      (tester) async {
        await abrirSosEnviado(tester);

        await _tocar(tester, find.text('Volver'));

        cerradoConAviso(avisoSigueActiva);
        expect(alertas.alertas.single.estado, EstadoAlerta.activa);
        expect(alertas.cambiosDeEstado, 0);
      },
    );

    testWidgets('el botón Atrás en el SOS enviado hace lo mismo que "Volver"', (
      tester,
    ) async {
      await abrirSosEnviado(tester);

      final atendido = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(atendido, isTrue);
      cerradoConAviso(avisoSigueActiva);
      expect(alertas.alertas.single.estado, EstadoAlerta.activa);
      expect(alertas.cambiosDeEstado, 0);
    });

    testWidgets(
      '"Ya estoy a salvo" pide confirmación con los textos acordados',
      (tester) async {
        await abrirSosEnviado(tester);

        await _tocar(tester, find.text('Ya estoy a salvo'));

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('¿Ya estás a salvo?'), findsOneWidget);
        expect(
          find.text(
            'Tu alerta va a quedar como resuelta. Si todavía necesitás '
            'ayuda, tocá "Seguir con la alerta".',
          ),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(OutlinedButton, 'Seguir con la alerta'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(FilledButton, 'Sí, estoy a salvo'),
          findsOneWidget,
        );
        expect(alertas.cambiosDeEstado, 0);
      },
    );

    testWidgets(
      'confirmar "Sí, estoy a salvo" resuelve la alerta y cierra con aviso',
      (tester) async {
        await abrirSosEnviado(tester);

        await _tocar(tester, find.text('Ya estoy a salvo'));
        await _tocar(tester, find.text('Sí, estoy a salvo'));

        expect(alertas.alertas.single.estado, EstadoAlerta.resuelta);
        cerradoConAviso('Marcaste la alerta como resuelta');
        expect(find.text(avisoSigueActiva), findsNothing);
      },
    );

    testWidgets('"Seguir con la alerta" en "Ya estoy a salvo" no cambia nada', (
      tester,
    ) async {
      await abrirSosEnviado(tester);

      await _tocar(tester, find.text('Ya estoy a salvo'));
      await _tocar(tester, find.text('Seguir con la alerta'));

      expect(find.byType(AlertDialog), findsNothing);
      sigueAbiertoYActivo();
    });

    testWidgets('Atrás en el diálogo de "Ya estoy a salvo" no cambia nada', (
      tester,
    ) async {
      await abrirSosEnviado(tester);

      await _tocar(tester, find.text('Ya estoy a salvo'));
      final atendido = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(atendido, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text(avisoSigueActiva), findsNothing);
      sigueAbiertoYActivo();
    });

    testWidgets(
      '"Fue una falsa alarma" pide confirmación con los textos acordados',
      (tester) async {
        await abrirSosEnviado(tester);

        await _tocar(tester, find.text('Fue una falsa alarma'));

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('¿Fue una falsa alarma?'), findsOneWidget);
        expect(
          find.text(
            'Tu alerta se va a cancelar y va a quedar como resuelta. Si de '
            'verdad necesitás ayuda, tocá "Seguir con la alerta".',
          ),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(OutlinedButton, 'Seguir con la alerta'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(FilledButton, 'Sí, fue una falsa alarma'),
          findsOneWidget,
        );
        expect(alertas.cambiosDeEstado, 0);
      },
    );

    testWidgets(
      'confirmar "Sí, fue una falsa alarma" resuelve la alerta y cierra con aviso',
      (tester) async {
        await abrirSosEnviado(tester);

        await _tocar(tester, find.text('Fue una falsa alarma'));
        await _tocar(tester, find.text('Sí, fue una falsa alarma'));

        expect(alertas.alertas.single.estado, EstadoAlerta.resuelta);
        cerradoConAviso('Cancelaste la alerta: fue una falsa alarma');
        expect(find.text(avisoSigueActiva), findsNothing);
      },
    );

    testWidgets(
      '"Seguir con la alerta" en "Fue una falsa alarma" no cambia nada',
      (tester) async {
        await abrirSosEnviado(tester);

        await _tocar(tester, find.text('Fue una falsa alarma'));
        await _tocar(tester, find.text('Seguir con la alerta'));

        expect(find.byType(AlertDialog), findsNothing);
        sigueAbiertoYActivo();
      },
    );

    testWidgets(
      'tocar fuera del diálogo de "Fue una falsa alarma" no cambia nada',
      (tester) async {
        await abrirSosEnviado(tester);

        await _tocar(tester, find.text('Fue una falsa alarma'));
        // Una esquina de la pantalla, fuera del diálogo.
        await tester.tapAt(const Offset(4, 4));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
        sigueAbiertoYActivo();
      },
    );

    testWidgets('si falla el cierre se avisa que se haga desde "Mis alertas"', (
      tester,
    ) async {
      await abrirSosEnviado(tester);
      alertas.falla = true;

      await _tocar(tester, find.text('Ya estoy a salvo'));
      await _tocar(tester, find.text('Sí, estoy a salvo'));

      expect(alertas.cambiosDeEstado, 1);
      expect(alertas.alertas.single.estado, EstadoAlerta.activa);
      cerradoConAviso(
        'No pudimos cerrar la alerta. Hacelo desde "Mis alertas".',
      );
    });
  });

  group('SOS y robo con el mismo título', () {
    // Se envía un SOS ("Intento de robo") y se vuelve con "Volver". En los
    // datos de ejemplo, a3 es un robo con el mismo título, en la Calle Gran
    // Cap. Sur.
    Finder tarjetaSos() => find.bySemanticsLabel(RegExp('^Alerta SOS: '));
    Finder tarjetaRobo() => find.bySemanticsLabel(RegExp('^Alerta de intento'));
    Finder pinSos() => find.bySemanticsLabel(RegExp('^Alerta SOS: Intento'));
    Finder pinRobo() => find.bySemanticsLabel(RegExp('^Alerta: Intento'));
    const direccionSos = 'Barrio Soberanía (zona aproximada)';

    Future<void> enviarSosYVolver(WidgetTester tester) async {
      await tester.pumpWidget(appDePrueba());
      await tester.pumpAndSettle();
      await ingresar(tester);
      await tester.tap(find.byType(BotonSos));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sí, enviar alerta'));
      await tester.pumpAndSettle();
      await _tocar(tester, find.text('Volver'));
      expect(find.text('Hola, Clara'), findsOneWidget);
    }

    Future<void> irA(WidgetTester tester, String pestania) => _tocar(
      tester,
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(pestania),
      ),
    );

    /// Toca el pin como un lector de pantalla: los pines pueden quedar
    /// juntos y un toque en el centro caer en otro.
    Future<void> activarPin(WidgetTester tester, Finder pin) async {
      final nodo = tester.getSemantics(pin);
      nodo.owner!.performAction(nodo.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
    }

    Finder marcaDentroDe(Finder lugar) =>
        find.descendant(of: lugar, matching: find.byType(MarcaSos));

    testWidgets('la tarjeta del SOS lleva la marca SOS y la de robo no', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await enviarSosYVolver(tester);

      await tester.scrollUntilVisible(tarjetaSos(), 200);
      expect(marcaDentroDe(tarjetaSos()), findsOneWidget);
      await tester.scrollUntilVisible(tarjetaRobo(), 200);
      expect(marcaDentroDe(tarjetaRobo()), findsNothing);
      handle.dispose();
    });

    testWidgets(
      'la tarjeta del SOS se anuncia "Alerta SOS: intento de robo, …" y la de robo como antes',
      (tester) async {
        final handle = tester.ensureSemantics();
        await enviarSosYVolver(tester);

        await tester.scrollUntilVisible(tarjetaSos(), 200);
        expect(
          tester.getSemantics(tarjetaSos()).label,
          'Alerta SOS: intento de robo, recién, activa. '
          '$direccionSos. Ver detalle',
        );
        await tester.scrollUntilVisible(tarjetaRobo(), 200);
        expect(
          tester.getSemantics(tarjetaRobo()).label,
          'Alerta de intento de robo, hace 1 hora, activa. '
          'Calle Gran Cap. Sur. Ver detalle',
        );
        handle.dispose();
      },
    );

    testWidgets(
      'el pin del SOS se anuncia "Alerta SOS: Intento de robo, …" y su resumen muestra la marca y lee "SOS: Intento de robo"',
      (tester) async {
        final handle = tester.ensureSemantics();
        await enviarSosYVolver(tester);
        await irA(tester, 'Mapa');

        expect(
          tester.getSemantics(pinSos()).label,
          'Alerta SOS: Intento de robo, activa, $direccionSos. Ver resumen',
        );
        expect(
          tester.getSemantics(pinRobo()).label,
          'Alerta: Intento de robo, activa, Calle Gran Cap. Sur. Ver resumen',
        );

        await activarPin(tester, pinSos());
        expect(marcaDentroDe(find.byType(BottomSheet)), findsOneWidget);
        expect(find.bySemanticsLabel('SOS: Intento de robo'), findsOneWidget);
        Navigator.of(tester.element(find.byType(BottomSheet))).pop();
        await tester.pumpAndSettle();

        await activarPin(tester, pinRobo());
        expect(marcaDentroDe(find.byType(BottomSheet)), findsNothing);
        expect(find.bySemanticsLabel('SOS: Intento de robo'), findsNothing);
        expect(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.bySemanticsLabel('Intento de robo'),
          ),
          findsOneWidget,
        );
        handle.dispose();
      },
    );

    testWidgets(
      'el detalle del SOS muestra la marca y lee "SOS: Intento de robo"',
      (tester) async {
        final handle = tester.ensureSemantics();
        await enviarSosYVolver(tester);

        await tester.scrollUntilVisible(tarjetaSos(), 200);
        await _tocar(tester, tarjetaSos());
        expect(find.text('Detalle de alerta'), findsOneWidget);
        expect(find.byType(MarcaSos), findsOneWidget);
        expect(find.bySemanticsLabel('SOS: Intento de robo'), findsOneWidget);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(tarjetaRobo(), 200);
        await _tocar(tester, tarjetaRobo());
        expect(find.text('Detalle de alerta'), findsOneWidget);
        expect(find.byType(MarcaSos), findsNothing);
        expect(find.bySemanticsLabel('SOS: Intento de robo'), findsNothing);
        expect(find.bySemanticsLabel('Intento de robo'), findsOneWidget);
        handle.dispose();
      },
    );

    testWidgets(
      '"Mis alertas reportadas" muestra la marca SOS en la alerta enviada',
      (tester) async {
        final handle = tester.ensureSemantics();
        await enviarSosYVolver(tester);
        await irA(tester, 'Perfil');
        // El perfil es una lista: la opción puede no estar construida todavía.
        await tester.scrollUntilVisible(
          find.text('Mis alertas reportadas'),
          200,
          scrollable: find
              .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
              )
              .hitTestable()
              .first,
        );
        await _tocar(tester, find.text('Mis alertas reportadas'));

        expect(tarjetaSos(), findsOneWidget);
        expect(marcaDentroDe(tarjetaSos()), findsOneWidget);
        handle.dispose();
      },
    );

    testWidgets('la marca SOS no se anuncia aparte', (tester) async {
      final handle = tester.ensureSemantics();
      await enviarSosYVolver(tester);

      await tester.scrollUntilVisible(tarjetaSos(), 200);
      expect(find.byType(MarcaSos), findsWidgets);
      expect(find.bySemanticsLabel('SOS'), findsNothing);

      await _tocar(tester, tarjetaSos());
      expect(find.byType(MarcaSos), findsOneWidget);
      expect(find.bySemanticsLabel('SOS'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      await irA(tester, 'Mapa');
      await activarPin(tester, pinSos());
      expect(marcaDentroDe(find.byType(BottomSheet)), findsOneWidget);
      expect(find.bySemanticsLabel('SOS'), findsNothing);
      handle.dispose();
    });
  });

  group('Reportar alerta', () {
    late AlertasFalsas alertas;
    late ReportarAlertaViewModel vm;

    // skipOffstage: false para encontrar también lo que quedó fuera de la
    // vista al desplazar el formulario.
    Finder campo(String etiqueta) => find.ancestor(
      of: find.text(etiqueta, skipOffstage: false),
      matching: find.byType(TextField, skipOffstage: false),
    );

    Future<void> escribir(
      WidgetTester tester,
      String etiqueta,
      String texto,
    ) async {
      await tester.ensureVisible(campo(etiqueta));
      await tester.pumpAndSettle();
      await tester.enterText(campo(etiqueta), texto);
      await tester.pump();
    }

    Future<void> tocarEnviar(WidgetTester tester) =>
        _tocar(tester, find.text('Enviar alerta', skipOffstage: false));

    String textoDe(WidgetTester tester, String etiqueta) =>
        tester.widget<TextField>(campo(etiqueta)).controller!.text;

    Finder tipo(String nombre) => find.ancestor(
      of: find.text(nombre, skipOffstage: false),
      matching: find.byType(
        RadioListTile<CategoriaAlerta>,
        skipOffstage: false,
      ),
    );

    RadioGroup<CategoriaAlerta> grupo(WidgetTester tester) =>
        tester.widget<RadioGroup<CategoriaAlerta>>(
          find.byType(RadioGroup<CategoriaAlerta>, skipOffstage: false),
        );

    Finder botonEnviar() => find.ancestor(
      of: find.text('Enviar alerta'),
      matching: find.byWidgetPredicate(
        (w) => w is FilledButton,
        skipOffstage: false,
      ),
    );

    /// Una pantalla base con un botón que empuja el formulario, como hace
    /// el inicio: así se ve si el formulario se cierra y qué aviso queda.
    Future<void> abrirFormulario(
      WidgetTester tester, {
      AlertasFalsas? repositorio,
      bool conUbicacionExacta = true,
    }) async {
      alertas = repositorio ?? AlertasFalsas();
      vm = ReportarAlertaViewModel(
        alertas: alertas,
        sesion: SesionFalsa(vecinaDePrueba),
        bus: BusDeEventos(),
        ubicacion: UbicacionDeAlerta(
          capacidades: const CapacidadesFalsas(),
          preferencias: preferenciasEnMemoria({
            Preferencias.claveCompartirUbicacion: conUbicacionExacta,
          }),
          ubicacion: UbicacionFalsa(),
        ),
      );
      addTearDown(vm.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      fullscreenDialog: true,
                      builder: (_) => ReportarAlertaScreen(viewModel: vm),
                    ),
                  ),
                  child: const Text('Pantalla base'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Pantalla base'));
      await tester.pumpAndSettle();
      await vm.cargar();
      await tester.pumpAndSettle();
      expect(find.text('¿Qué pasó?'), findsOneWidget);
    }

    void formularioAbierto() {
      expect(find.byType(ReportarAlertaScreen), findsOneWidget);
      expect(find.text('Pantalla base'), findsNothing);
    }

    void formularioCerrado() {
      expect(find.text('¿Qué pasó?'), findsNothing);
      expect(find.text('Pantalla base'), findsOneWidget);
    }

    /// Elige Robo y escribe en los tres campos.
    Future<void> completar(WidgetTester tester) async {
      await _tocar(tester, tipo('Robo'));
      await escribir(tester, 'Título', 'Robo de bicicleta');
      await escribir(
        tester,
        'Descripción (opcional)',
        'Se llevaron una bici del patio.',
      );
      await escribir(
        tester,
        'Dirección o referencia (opcional)',
        'Cabildo de Mendoza y Ascasubi',
      );
      await tester.pump();
    }

    void conservaLoEscrito(WidgetTester tester) {
      expect(vm.tipo, CategoriaAlerta.robo);
      expect(grupo(tester).groupValue, CategoriaAlerta.robo);
      expect(textoDe(tester, 'Título'), 'Robo de bicicleta');
      expect(
        textoDe(tester, 'Descripción (opcional)'),
        'Se llevaron una bici del patio.',
      );
      expect(
        textoDe(tester, 'Dirección o referencia (opcional)'),
        'Cabildo de Mendoza y Ascasubi',
      );
    }

    // --- Tipos, título y ubicación (R6, R7, R8, R10, R11, R12) ---

    testWidgets('muestra los cuatro tipos sin ninguno elegido y los campos '
        'vacíos', (tester) async {
      await abrirFormulario(tester);

      final nombres = tester
          .widgetList<RadioListTile<CategoriaAlerta>>(
            find.byType(RadioListTile<CategoriaAlerta>),
          )
          .map((t) => (t.title! as Text).data)
          .toList();
      expect(nombres, [
        'Actividad sospechosa',
        'Vehículo sospechoso',
        'Robo',
        'Ruidos',
      ]);
      expect(find.text('Arrebato'), findsNothing);
      expect(grupo(tester).groupValue, isNull);
      expect(textoDe(tester, 'Título'), '');
      expect(textoDe(tester, 'Descripción (opcional)'), '');
      expect(textoDe(tester, 'Dirección o referencia (opcional)'), '');
    });

    testWidgets('elegir "Robo" completa el título con "Robo"', (tester) async {
      await abrirFormulario(tester);

      await _tocar(tester, tipo('Robo'));

      expect(grupo(tester).groupValue, CategoriaAlerta.robo);
      expect(textoDe(tester, 'Título'), 'Robo');

      // Con el título sin tocar, otro tipo cambia la sugerencia.
      await _tocar(tester, tipo('Ruidos'));
      expect(textoDe(tester, 'Título'), 'Ruidos');
    });

    testWidgets('el vecino puede cambiar el título', (tester) async {
      await abrirFormulario(tester);
      await _tocar(tester, tipo('Robo'));

      await escribir(tester, 'Título', 'Robo de bicicleta');
      await tester.pump();
      expect(textoDe(tester, 'Título'), 'Robo de bicicleta');

      // Otro tipo ya no lo pisa (R9).
      await _tocar(tester, tipo('Vehículo sospechoso'));
      expect(textoDe(tester, 'Título'), 'Robo de bicicleta');
    });

    testWidgets(
      'con ubicación exacta dice "Vamos a mandar tu ubicación exacta."',
      (tester) async {
        await abrirFormulario(tester);
        expect(
          find.text('Vamos a mandar tu ubicación exacta.'),
          findsOneWidget,
        );
        expect(
          find.text(
            'Vamos a mandar la zona del barrio, no tu ubicación exacta.',
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'sin ubicación exacta dice "Vamos a mandar la zona del barrio, no tu '
      'ubicación exacta."',
      (tester) async {
        await abrirFormulario(tester, conUbicacionExacta: false);
        expect(
          find.text(
            'Vamos a mandar la zona del barrio, no tu ubicación exacta.',
          ),
          findsOneWidget,
        );
        expect(find.text('Vamos a mandar tu ubicación exacta.'), findsNothing);
      },
    );

    // --- Envío (R20, R22, R23) ---

    testWidgets(
      'enviar cierra el formulario y muestra "Reportaste la alerta. Ya '
      'aparece en la lista y el mapa."',
      (tester) async {
        await abrirFormulario(tester);
        await completar(tester);

        await tocarEnviar(tester);

        formularioCerrado();
        expect(
          find.text('Reportaste la alerta. Ya aparece en la lista y el mapa.'),
          findsOneWidget,
        );
        final creada = alertas.creadas.single;
        expect(creada.categoria, CategoriaAlerta.robo);
        expect(creada.tipo, 'Robo de bicicleta');
        expect(creada.direccion, 'Cabildo de Mendoza y Ascasubi');
      },
    );

    testWidgets(
      'mientras envía, "Enviar alerta" está deshabilitado con "Enviando la '
      'alerta" y Atrás no cierra',
      (tester) async {
        final lentas = _AlertasLentas();
        await abrirFormulario(tester, repositorio: lentas);
        await completar(tester);

        await tester.ensureVisible(
          find.text('Enviar alerta', skipOffstage: false),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Enviar alerta'));
        await tester.pump();
        await tester.pump();

        expect(vm.enviando, isTrue);
        expect(
          tester.widget<ButtonStyleButton>(botonEnviar()).onPressed,
          isNull,
        );
        expect(
          find.bySemanticsLabel(RegExp('Enviando la alerta')),
          findsOneWidget,
        );
        expect(
          tester
              .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.close))
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Cancelar'),
              )
              .onPressed,
          isNull,
        );

        final atendido = await tester.binding.handlePopRoute();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(atendido, isTrue);
        formularioAbierto();
        expect(find.text('¿Descartar la alerta?'), findsNothing);

        lentas.soltar.complete();
        await tester.pumpAndSettle();
        formularioCerrado();
      },
    );

    // --- Errores (R24 a R29, R32 a R34) ---

    testWidgets(
      'enviar vacío muestra "Elegí qué tipo de alerta es." y "Escribí un '
      'título para la alerta." y lleva el foco al primer tipo',
      (tester) async {
        await abrirFormulario(tester);

        await tocarEnviar(tester);

        formularioAbierto();
        expect(find.text('Elegí qué tipo de alerta es.'), findsOneWidget);
        expect(find.text('Escribí un título para la alerta.'), findsOneWidget);
        final primerTipo = tester.widget<RadioListTile<CategoriaAlerta>>(
          tipo('Actividad sospechosa'),
        );
        expect(primerTipo.focusNode!.hasPrimaryFocus, isTrue);
        expect(alertas.creadas, isEmpty);
      },
    );

    testWidgets(
      'un título de 61 letras muestra "Acortá el título: puede tener hasta 60 '
      'letras." y lleva el foco al Título',
      (tester) async {
        await abrirFormulario(tester);
        await _tocar(tester, tipo('Robo'));
        await escribir(tester, 'Título', 'a' * 61);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();

        await tocarEnviar(tester);

        expect(
          find.text('Acortá el título: puede tener hasta 60 letras.'),
          findsOneWidget,
        );
        expect(
          tester.widget<TextField>(campo('Título')).focusNode!.hasFocus,
          isTrue,
        );
        expect(alertas.creadas, isEmpty);
      },
    );

    testWidgets('descripción y dirección largas muestran sus mensajes', (
      tester,
    ) async {
      await abrirFormulario(tester);
      await _tocar(tester, tipo('Robo'));
      await escribir(tester, 'Descripción (opcional)', 'a' * 501);
      await escribir(tester, 'Dirección o referencia (opcional)', 'a' * 121);
      await tester.pump();

      await tocarEnviar(tester);

      expect(
        find.text('Acortá la descripción: puede tener hasta 500 letras.'),
        findsOneWidget,
      );
      expect(
        find.text('Acortá la dirección: puede tener hasta 120 letras.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextField>(campo('Descripción (opcional)'))
            .focusNode!
            .hasFocus,
        isTrue,
      );
      expect(alertas.creadas, isEmpty);
    });

    testWidgets(
      'si la API rechaza, el formulario muestra el mensaje y conserva tipo, '
      'título, descripción y dirección',
      (tester) async {
        await abrirFormulario(
          tester,
          repositorio: AlertasFalsas()
            ..errorAlCrear = const ErrorDelServidor(
              'Elegí qué tipo de alerta es.',
            ),
        );
        await completar(tester);

        await tocarEnviar(tester);

        formularioAbierto();
        expect(find.text('Elegí qué tipo de alerta es.'), findsOneWidget);
        conservaLoEscrito(tester);
      },
    );

    testWidgets(
      'sin conexión el formulario muestra el error de red y conserva lo '
      'escrito',
      (tester) async {
        await abrirFormulario(tester, repositorio: AlertasFalsas([], true));
        await completar(tester);

        await tocarEnviar(tester);

        formularioAbierto();
        expect(
          find.text(
            'No pudimos enviar la alerta. Revisá tu conexión y probá de '
            'nuevo.',
          ),
          findsOneWidget,
        );
        conservaLoEscrito(tester);
      },
    );

    // --- Cerrar (R36 a R39) ---

    testWidgets('la X sin datos cierra sin preguntar', (tester) async {
      await abrirFormulario(tester);

      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();

      expect(find.text('¿Descartar la alerta?'), findsNothing);
      formularioCerrado();
    });

    testWidgets('"Cancelar" con un tipo elegido pide "¿Descartar la alerta?"', (
      tester,
    ) async {
      await abrirFormulario(tester);
      await _tocar(tester, tipo('Ruidos'));
      // Solo el tipo: sin texto escrito.
      await escribir(tester, 'Título', '');
      await tester.pump();

      await _tocar(tester, find.text('Cancelar', skipOffstage: false));

      expect(find.text('¿Descartar la alerta?'), findsOneWidget);
      expect(
        find.text(
          'Todavía no la enviaste. Si salís, se borra lo que escribiste.',
        ),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(OutlinedButton, 'Seguir escribiendo'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(FilledButton, 'Sí, descartar'),
        findsOneWidget,
      );
    });

    testWidgets('Atrás con texto escrito pide "¿Descartar la alerta?"', (
      tester,
    ) async {
      await abrirFormulario(tester);
      await escribir(tester, 'Descripción (opcional)', 'Algo raro');
      await tester.pump();

      final atendido = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(atendido, isTrue);
      expect(find.text('¿Descartar la alerta?'), findsOneWidget);
    });

    testWidgets('"Sí, descartar" cierra sin crear ninguna alerta', (
      tester,
    ) async {
      await abrirFormulario(tester);
      await completar(tester);

      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();
      await _tocar(tester, find.text('Sí, descartar'));

      formularioCerrado();
      expect(alertas.creadas, isEmpty);
      expect(alertas.alertas, isEmpty);
    });

    testWidgets('"Seguir escribiendo" vuelve con todo lo escrito', (
      tester,
    ) async {
      await abrirFormulario(tester);
      await completar(tester);

      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();
      await _tocar(tester, find.text('Seguir escribiendo'));

      expect(find.text('¿Descartar la alerta?'), findsNothing);
      formularioAbierto();
      conservaLoEscrito(tester);

      // Atrás en el diálogo también vuelve al formulario.
      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('¿Descartar la alerta?'), findsNothing);
      formularioAbierto();
      conservaLoEscrito(tester);
    });

    testWidgets('tocar fuera del diálogo vuelve con todo lo escrito', (
      tester,
    ) async {
      await abrirFormulario(tester);
      await completar(tester);

      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();

      expect(find.text('¿Descartar la alerta?'), findsNothing);
      formularioAbierto();
      conservaLoEscrito(tester);
    });
  });

  group('Inicio: reportar alerta', () {
    Finder boton(String texto, bool Function(Widget) tipo) => find.ancestor(
      of: find.text(texto, skipOffstage: false),
      matching: find.byWidgetPredicate(tipo, skipOffstage: false),
    );

    Finder reportar() => boton('Reportar alerta', (w) => w is FilledButton);
    Finder llamar() => boton('Llamar al 911', (w) => w is OutlinedButton);
    Finder mapa() => find.ancestor(
      of: find.text('Abrir el mapa de alertas', skipOffstage: false),
      matching: find.byType(TarjetaTocable, skipOffstage: false),
    );

    Future<void> abrirInicio(WidgetTester tester) async {
      await tester.pumpWidget(appDePrueba());
      await tester.pumpAndSettle();
      await ingresar(tester);
      await tester.ensureVisible(llamar());
      await tester.pumpAndSettle();
    }

    testWidgets(
      '"Reportar alerta" está debajo del mapa y arriba de "Llamar al 911"',
      (tester) async {
        await abrirInicio(tester);

        expect(reportar(), findsOneWidget);
        expect(
          tester.getTopLeft(reportar()).dy,
          greaterThanOrEqualTo(tester.getBottomLeft(mapa()).dy),
        );
        expect(
          tester.getBottomLeft(reportar()).dy,
          lessThanOrEqualTo(tester.getTopLeft(llamar()).dy),
        );
      },
    );

    testWidgets(
      '"Reportar alerta" y "Llamar al 911" tienen el ancho de la tarjeta del '
      'mapa',
      (tester) async {
        await abrirInicio(tester);

        final anchoMapa = tester.getSize(mapa()).width;
        expect(tester.getSize(reportar()).width, anchoMapa);
        expect(tester.getSize(llamar()).width, anchoMapa);
        expect(tester.getTopLeft(reportar()).dx, tester.getTopLeft(mapa()).dx);
        expect(tester.getTopLeft(llamar()).dx, tester.getTopLeft(mapa()).dx);
      },
    );

    testWidgets('los dos botones son más bajos que el botón SOS', (
      tester,
    ) async {
      await abrirInicio(tester);

      final altoSos = tester.getSize(find.byType(BotonSos)).height;
      expect(altoSos, 104);
      expect(tester.getSize(reportar()).height, 52);
      expect(tester.getSize(llamar()).height, 52);
      expect(tester.getSize(reportar()).height, lessThan(altoSos));
      expect(tester.getSize(llamar()).height, lessThan(altoSos));
    });

    testWidgets('"Reportar alerta" abre el formulario', (tester) async {
      await abrirInicio(tester);

      await _tocar(tester, reportar());

      expect(find.byType(ReportarAlertaScreen), findsOneWidget);
      expect(find.text('¿Qué pasó?'), findsOneWidget);
      expect(find.byTooltip('Cerrar'), findsOneWidget);
      // Pantalla completa: el inicio queda tapado.
      expect(find.text('Hola, Clara'), findsNothing);
    });

    testWidgets(
      'una alerta reportada aparece en "Alertas cerca tuyo" y en el mapa',
      (tester) async {
        final handle = tester.ensureSemantics();
        await abrirInicio(tester);
        await _tocar(tester, reportar());

        await _tocar(
          tester,
          find.widgetWithText(
            RadioListTile<CategoriaAlerta>,
            'Vehículo sospechoso',
          ),
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Título'),
          'Auto gris dando vueltas',
        );
        await tester.pump();
        await _tocar(tester, find.text('Enviar alerta', skipOffstage: false));

        expect(find.byType(ReportarAlertaScreen), findsNothing);
        expect(
          find.text('Reportaste la alerta. Ya aparece en la lista y el mapa.'),
          findsOneWidget,
        );

        final tarjeta = find.ancestor(
          of: find.text('Auto gris dando vueltas'),
          matching: find.byType(TarjetaAlerta),
        );
        await tester.scrollUntilVisible(tarjeta, 200);
        expect(tarjeta, findsOneWidget);
        final alerta = tester.widget<TarjetaAlerta>(tarjeta).alerta;
        expect(alerta.estado, EstadoAlerta.activa);
        expect(alerta.categoria, CategoriaAlerta.vehiculo);

        await _tocar(
          tester,
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Mapa'),
          ),
        );
        expect(
          find.bySemanticsLabel(RegExp('^Alerta: Auto gris dando vueltas')),
          findsOneWidget,
        );
        handle.dispose();
      },
    );
  });

  testWidgets(
    'una alerta de arrebato guardada se ve con su título y el ícono de '
    'arrebato',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: TarjetaAlerta(
              alerta: alertaDePrueba(
                categoria: CategoriaAlerta.arrebato,
                tipo: 'Arrebato',
              ),
              hace: 'Hace 5 minutos',
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Arrebato'), findsOneWidget);
      expect(find.byIcon(Icons.phone_android), findsOneWidget);
    },
  );
  group('Detalle: estado de la alerta', () {
    late AlertasFalsas alertas;
    late DetalleAlertaViewModel vm;

    /// Abre el detalle de [alerta] encima de una "Pantalla anterior", con
    /// [vecino] en la sesión (por defecto, Clara como vecina común).
    Future<void> abrirDetalle(
      WidgetTester tester, {
      Alerta? alerta,
      Vecino? vecino,
    }) async {
      pantallaAlta(tester);
      MapaBarrio.cargarCalles = false;
      final laAlerta = alerta ?? alertaDePrueba();
      alertas = AlertasFalsas([laAlerta]);
      vm = DetalleAlertaViewModel(
        alerta: laAlerta,
        alertas: alertas,
        sesion: SesionFalsa(vecino ?? vecinaDePrueba),
        bus: BusDeEventos(),
        reloj: relojDePrueba,
        avisos: AvisosRecibidosFalsos(),
      );
      addTearDown(vm.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: Text('Pantalla anterior')),
        ),
      );
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .push(
            MaterialPageRoute<void>(
              builder: (_) => DetalleAlertaScreen(
                viewModel: vm,
                capacidades: const CapacidadesFalsas(),
                telefono: TelefonoFalso(),
              ),
            ),
          );
      await tester.pumpAndSettle();
    }

    Finder opcion(String etiqueta) =>
        find.widgetWithText(RadioListTile<EstadoAlerta>, etiqueta);

    Finder chip(String etiqueta) => find.descendant(
      of: find.byType(ChipEstado),
      matching: find.text(etiqueta),
    );

    EstadoAlerta? elegida(WidgetTester tester) => tester
        .widget<RadioGroup<EstadoAlerta>>(find.byType(RadioGroup<EstadoAlerta>))
        .groupValue;

    bool habilitada(WidgetTester tester, String etiqueta) =>
        tester.widget<RadioListTile<EstadoAlerta>>(opcion(etiqueta)).enabled ??
        true;

    /// Sigue el detalle con [estado] arriba y como opción elegida.
    void muestraEstado(WidgetTester tester, EstadoAlerta estado, String texto) {
      expect(find.text('Detalle de alerta'), findsOneWidget);
      expect(chip(texto), findsOneWidget);
      expect(elegida(tester), estado);
    }

    const textoResolver =
        'Va a dejar de aparecer en "Alertas cerca tuyo". Si hace falta, la '
        'podés volver a abrir desde acá.';

    // Quién ve el control.

    testWidgets(
      'quien la reportó ve "Estado de la alerta" con Activa, En atención y '
      'Resuelta en orden',
      (tester) async {
        await abrirDetalle(tester);

        expect(find.text('Estado de la alerta'), findsOneWidget);
        expect(find.byType(RadioListTile<EstadoAlerta>), findsNWidgets(3));
        final activa = tester.getTopLeft(opcion('Activa')).dy;
        final enAtencion = tester.getTopLeft(opcion('En atención')).dy;
        final resuelta = tester.getTopLeft(opcion('Resuelta')).dy;
        expect(activa, lessThan(enAtencion));
        expect(enAtencion, lessThan(resuelta));
      },
    );

    testWidgets('la comisión ve el control en una alerta ajena', (
      tester,
    ) async {
      await abrirDetalle(
        tester,
        alerta: alertaDePrueba(reportadaPor: 'jorge'),
        vecino: miembroDeLaComision,
      );

      expect(find.text('Estado de la alerta'), findsOneWidget);
      expect(find.byType(RadioListTile<EstadoAlerta>), findsNWidgets(3));
      // La falsa alarma es solo de quien la reportó.
      expect(find.text('Fue una falsa alarma'), findsNothing);
    });

    testWidgets('un vecino común ve el estado pero no el control', (
      tester,
    ) async {
      await abrirDetalle(tester, alerta: alertaDePrueba(reportadaPor: 'jorge'));

      expect(chip('Activa'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ChipEstado),
          matching: find.byIcon(Icons.priority_high),
        ),
        findsOneWidget,
      );
      expect(find.text('Estado de la alerta'), findsNothing);
      expect(find.byType(RadioListTile<EstadoAlerta>), findsNothing);
      expect(find.text('Fue una falsa alarma'), findsNothing);
    });

    testWidgets('la opción elegida es el estado actual', (tester) async {
      await abrirDetalle(
        tester,
        alerta: alertaDePrueba(estado: EstadoAlerta.enAtencion),
      );

      expect(elegida(tester), EstadoAlerta.enAtencion);
      expect(chip('En atención'), findsOneWidget);
    });

    testWidgets('no está el botón "Marcar como resuelta"', (tester) async {
      for (final (alerta, vecino) in [
        (alertaDePrueba(), vecinaDePrueba),
        (alertaDePrueba(reportadaPor: 'jorge'), miembroDeLaComision),
        (alertaDePrueba(reportadaPor: 'jorge'), vecinaDePrueba),
      ]) {
        await abrirDetalle(tester, alerta: alerta, vecino: vecino);
        expect(find.text('Marcar como resuelta'), findsNothing);
      }
    });

    testWidgets('en una alerta resuelta las tres opciones están habilitadas', (
      tester,
    ) async {
      for (final (alerta, vecino) in [
        (alertaDePrueba(estado: EstadoAlerta.resuelta), vecinaDePrueba),
        (
          alertaDePrueba(reportadaPor: 'jorge', estado: EstadoAlerta.resuelta),
          miembroDeLaComision,
        ),
      ]) {
        await abrirDetalle(tester, alerta: alerta, vecino: vecino);
        expect(elegida(tester), EstadoAlerta.resuelta);
        for (final etiqueta in ['Activa', 'En atención', 'Resuelta']) {
          expect(habilitada(tester, etiqueta), isTrue, reason: etiqueta);
        }
        // Resuelta: "Fue una falsa alarma" ya no se ofrece.
        expect(find.text('Fue una falsa alarma'), findsNothing);
      }
    });

    // Cambiar.

    testWidgets(
      'elegir "En atención" no pide confirmación, cambia el estado de arriba '
      'y la opción, muestra "Cambiaste el estado a En atención." y el '
      'detalle sigue abierto',
      (tester) async {
        await abrirDetalle(tester);

        await _tocar(tester, opcion('En atención'));

        expect(find.byType(AlertDialog), findsNothing);
        expect(alertas.cambiosDeEstado, 1);
        expect(alertas.alertas.single.estado, EstadoAlerta.enAtencion);
        muestraEstado(tester, EstadoAlerta.enAtencion, 'En atención');
        expect(chip('Activa'), findsNothing);
        expect(find.text('Cambiaste el estado a En atención.'), findsOneWidget);
        expect(find.text('Pantalla anterior'), findsNothing);
      },
    );

    testWidgets(
      'mientras cambia, las opciones están deshabilitadas y se ve "Cambiando '
      'el estado"',
      (tester) async {
        final handle = tester.ensureSemantics();
        await abrirDetalle(tester);
        alertas.demoraAlCambiar = Completer<void>();

        await tester.ensureVisible(opcion('En atención'));
        await tester.pumpAndSettle();
        await tester.tap(opcion('En atención'));
        await tester.pump();

        for (final etiqueta in ['Activa', 'En atención', 'Resuelta']) {
          expect(habilitada(tester, etiqueta), isFalse, reason: etiqueta);
        }
        expect(find.text('Cambiando el estado'), findsOneWidget);
        expect(find.bySemanticsLabel('Cambiando el estado'), findsOneWidget);
        expect(
          tester
              .widget<TextButton>(
                find.widgetWithText(TextButton, 'Fue una falsa alarma'),
              )
              .onPressed,
          isNull,
        );

        alertas.demoraAlCambiar!.complete();
        await tester.pumpAndSettle();

        expect(find.text('Cambiando el estado'), findsNothing);
        expect(habilitada(tester, 'Activa'), isTrue);
        muestraEstado(tester, EstadoAlerta.enAtencion, 'En atención');
        handle.dispose();
      },
    );

    testWidgets('tocar la opción actual no pide nada', (tester) async {
      await abrirDetalle(tester);

      await _tocar(tester, opcion('Activa'));

      expect(alertas.cambiosDeEstado, 0);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      muestraEstado(tester, EstadoAlerta.activa, 'Activa');
    });

    testWidgets('si la API rechaza se ve su mensaje y el estado anterior', (
      tester,
    ) async {
      await abrirDetalle(
        tester,
        alerta: alertaDePrueba(reportadaPor: 'jorge'),
        vecino: miembroDeLaComision,
      );
      alertas.errorAlCambiar = const ErrorDelServidor(
        ReglasAlertas.mensajeSinPermisoEstado,
      );

      await _tocar(tester, opcion('En atención'));

      expect(
        find.text(
          'Solo quien reportó la alerta o la comisión vecinal pueden cambiar '
          'su estado.',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      muestraEstado(tester, EstadoAlerta.activa, 'Activa');
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets(
      'sin conexión se ve "No pudimos cambiar el estado. Probá de nuevo." y '
      'el estado anterior',
      (tester) async {
        await abrirDetalle(tester);
        alertas.falla = true;

        await _tocar(tester, opcion('En atención'));

        expect(
          find.text('No pudimos cambiar el estado. Probá de nuevo.'),
          findsOneWidget,
        );
        muestraEstado(tester, EstadoAlerta.activa, 'Activa');
        expect(find.byType(SnackBar), findsNothing);
      },
    );

    testWidgets(
      '"Fue una falsa alarma" sigue cerrando el detalle con "Cancelaste la '
      'alerta: falsa alarma" sin diálogo',
      (tester) async {
        await abrirDetalle(tester);

        await tester.ensureVisible(find.text('Fue una falsa alarma'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Fue una falsa alarma'));
        await tester.pump();
        expect(find.byType(AlertDialog), findsNothing);
        await tester.pumpAndSettle();

        expect(alertas.alertas.single.estado, EstadoAlerta.resuelta);
        expect(find.text('Pantalla anterior'), findsOneWidget);
        expect(find.text('Detalle de alerta'), findsNothing);
        expect(find.text('Cancelaste la alerta: falsa alarma'), findsOneWidget);
      },
    );

    // Confirmación.

    testWidgets(
      'elegir "Resuelta" muestra "¿Marcar la alerta como resuelta?" con su '
      'texto y los botones, y no pide nada mientras está abierto',
      (tester) async {
        await abrirDetalle(tester);

        await _tocar(tester, opcion('Resuelta'));

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('¿Marcar la alerta como resuelta?'), findsOneWidget);
        expect(find.text(textoResolver), findsOneWidget);
        expect(
          find.widgetWithText(OutlinedButton, 'No, dejarla como está'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(FilledButton, 'Sí, está resuelta'),
          findsOneWidget,
        );
        expect(alertas.cambiosDeEstado, 0);
        // Mientras el diálogo está abierto la opción elegida no se movió.
        expect(elegida(tester), EstadoAlerta.activa);
      },
    );

    testWidgets(
      '"Sí, está resuelta" cierra el diálogo, pide el cambio y muestra '
      '"Cambiaste el estado a Resuelta."',
      (tester) async {
        await abrirDetalle(tester);

        await _tocar(tester, opcion('Resuelta'));
        await _tocar(tester, find.text('Sí, está resuelta'));

        expect(find.byType(AlertDialog), findsNothing);
        expect(alertas.cambiosDeEstado, 1);
        expect(alertas.alertas.single.estado, EstadoAlerta.resuelta);
        muestraEstado(tester, EstadoAlerta.resuelta, 'Resuelta');
        expect(find.text('Cambiaste el estado a Resuelta.'), findsOneWidget);
      },
    );

    testWidgets(
      'en una alerta resuelta, elegir "En atención" o "Activa" muestra '
      '"¿Volver a abrir la alerta?" con su texto',
      (tester) async {
        for (final (etiqueta, nombre) in [
          ('En atención', 'En atención'),
          ('Activa', 'Activa'),
        ]) {
          await abrirDetalle(
            tester,
            alerta: alertaDePrueba(estado: EstadoAlerta.resuelta),
          );

          await _tocar(tester, opcion(etiqueta));

          expect(find.text('¿Volver a abrir la alerta?'), findsOneWidget);
          expect(
            find.text(
              'Va a quedar como $nombre y se les va a avisar a los vecinos '
              'del barrio.',
            ),
            findsOneWidget,
          );
          expect(
            find.widgetWithText(OutlinedButton, 'No, dejarla resuelta'),
            findsOneWidget,
          );
          expect(
            find.widgetWithText(FilledButton, 'Sí, volver a abrirla'),
            findsOneWidget,
          );
          expect(alertas.cambiosDeEstado, 0);
          await _tocar(tester, find.text('No, dejarla resuelta'));
        }
      },
    );

    testWidgets('"Sí, volver a abrirla" pide el cambio y muestra el estado '
        'nuevo', (tester) async {
      await abrirDetalle(
        tester,
        alerta: alertaDePrueba(
          reportadaPor: 'jorge',
          estado: EstadoAlerta.resuelta,
        ),
        vecino: miembroDeLaComision,
      );

      await _tocar(tester, opcion('En atención'));
      await _tocar(tester, find.text('Sí, volver a abrirla'));

      expect(find.byType(AlertDialog), findsNothing);
      expect(alertas.cambiosDeEstado, 1);
      expect(alertas.alertas.single.estado, EstadoAlerta.enAtencion);
      muestraEstado(tester, EstadoAlerta.enAtencion, 'En atención');
      expect(find.text('Cambiaste el estado a En atención.'), findsOneWidget);
    });

    group('cerrar el diálogo sin confirmar no pide nada', () {
      /// Abre el diálogo de [elegir] y lo cierra con [cerrar].
      Future<void> probar(
        WidgetTester tester, {
        required EstadoAlerta actual,
        required String etiquetaActual,
        required String elegir,
        required Future<void> Function() cerrar,
      }) async {
        await abrirDetalle(tester, alerta: alertaDePrueba(estado: actual));
        await _tocar(tester, opcion(elegir));
        expect(find.byType(AlertDialog), findsOneWidget);

        await cerrar();
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
        expect(alertas.cambiosDeEstado, 0);
        muestraEstado(tester, actual, etiquetaActual);
        expect(find.byType(SnackBar), findsNothing);
        expect(find.byIcon(Icons.error_outline), findsNothing);
      }

      testWidgets('con "No, dejarla como está"', (tester) async {
        await probar(
          tester,
          actual: EstadoAlerta.activa,
          etiquetaActual: 'Activa',
          elegir: 'Resuelta',
          cerrar: () => tester.tap(find.text('No, dejarla como está')),
        );
      });

      testWidgets('con "No, dejarla resuelta"', (tester) async {
        await probar(
          tester,
          actual: EstadoAlerta.resuelta,
          etiquetaActual: 'Resuelta',
          elegir: 'Activa',
          cerrar: () => tester.tap(find.text('No, dejarla resuelta')),
        );
      });

      testWidgets('tocando fuera del diálogo', (tester) async {
        await probar(
          tester,
          actual: EstadoAlerta.enAtencion,
          etiquetaActual: 'En atención',
          elegir: 'Resuelta',
          // Una esquina de la pantalla, fuera del diálogo.
          cerrar: () => tester.tapAt(const Offset(4, 4)),
        );
      });

      testWidgets('con el botón Atrás', (tester) async {
        await probar(
          tester,
          actual: EstadoAlerta.resuelta,
          etiquetaActual: 'Resuelta',
          elegir: 'En atención',
          cerrar: () async {
            expect(await tester.binding.handlePopRoute(), isTrue);
          },
        );
      });
    });
  });

  group('Estado: lista y mapa', () {
    // En el servidor simulado Clara es de la comisión. a1 ("Actividad
    // sospechosa") es de Clara y a2 ("Moto a alta velocidad", en atención)
    // de Martín.
    Finder tarjeta(String tipo) =>
        find.widgetWithText(TarjetaAlerta, tipo, skipOffstage: false);

    Finder opcion(String etiqueta) =>
        find.widgetWithText(RadioListTile<EstadoAlerta>, etiqueta);

    Future<void> abrirApp(WidgetTester tester) async {
      pantallaAlta(tester);
      await tester.pumpWidget(appDePrueba());
      await tester.pumpAndSettle();
      await ingresar(tester);
    }

    Future<void> irA(WidgetTester tester, String pestania) => _tocar(
      tester,
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(pestania),
      ),
    );

    Future<void> volver(WidgetTester tester) async {
      await tester.pageBack();
      await tester.pumpAndSettle();
    }

    /// Abre el detalle desde el inicio, elige [etiqueta] (confirmando si
    /// hace falta) y vuelve.
    Future<void> cambiarDesdeElInicio(
      WidgetTester tester,
      String tipo,
      String etiqueta, {
      String? confirmar,
    }) async {
      await tester.scrollUntilVisible(
        find.widgetWithText(TarjetaAlerta, tipo),
        200,
      );
      await _tocar(tester, find.widgetWithText(TarjetaAlerta, tipo));
      await _tocar(tester, opcion(etiqueta));
      if (confirmar != null) await _tocar(tester, find.text(confirmar));
      expect(find.text('Detalle de alerta'), findsOneWidget);
      await volver(tester);
    }

    testWidgets(
      'poner En atención "Actividad sospechosa" se ve en "Alertas cerca '
      'tuyo"',
      (tester) async {
        final handle = tester.ensureSemantics();
        await abrirApp(tester);

        await cambiarDesdeElInicio(
          tester,
          'Actividad sospechosa',
          'En atención',
        );

        expect(find.text('Hola, Clara'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.widgetWithText(TarjetaAlerta, 'Actividad sospechosa'),
          200,
        );
        expect(
          find.descendant(
            of: tarjeta('Actividad sospechosa'),
            matching: find.descendant(
              of: find.byType(ChipEstado),
              matching: find.text('En atención'),
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(
            RegExp('^Alerta de actividad sospechosa, .*, en atención\\.'),
          ),
          findsOneWidget,
        );
        handle.dispose();
      },
    );

    testWidgets(
      'poner Resuelta "Moto a alta velocidad" la quita de "Alertas cerca '
      'tuyo"',
      (tester) async {
        await abrirApp(tester);

        await cambiarDesdeElInicio(
          tester,
          'Moto a alta velocidad',
          'Resuelta',
          confirmar: 'Sí, está resuelta',
        );

        expect(find.text('Hola, Clara'), findsOneWidget);
        expect(tarjeta('Moto a alta velocidad'), findsNothing);
        // Las otras siguen.
        expect(tarjeta('Actividad sospechosa'), findsOneWidget);
      },
    );

    testWidgets('el pin del mapa dice el estado nuevo', (tester) async {
      final handle = tester.ensureSemantics();
      await abrirApp(tester);
      await cambiarDesdeElInicio(
        tester,
        'Moto a alta velocidad',
        'Resuelta',
        confirmar: 'Sí, está resuelta',
      );

      await irA(tester, 'Mapa');
      await _tocar(tester, find.text('Todas'));

      expect(
        find.bySemanticsLabel(
          RegExp('^Alerta: Moto a alta velocidad, resuelta'),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          RegExp('^Alerta: Moto a alta velocidad, en atención'),
        ),
        findsNothing,
      );
      handle.dispose();
    });

    testWidgets(
      'una alerta propia cambiada se ve con el estado nuevo en "Mis alertas"',
      (tester) async {
        await abrirApp(tester);
        await irA(tester, 'Perfil');
        await _tocar(tester, find.text('Mis alertas reportadas'));
        expect(find.text('Mis alertas'), findsOneWidget);

        await _tocar(
          tester,
          find.widgetWithText(TarjetaAlerta, 'Actividad sospechosa'),
        );
        await _tocar(tester, opcion('En atención'));
        await volver(tester);

        expect(find.text('Mis alertas'), findsOneWidget);
        expect(
          find.descendant(
            of: find.widgetWithText(TarjetaAlerta, 'Actividad sospechosa'),
            matching: find.descendant(
              of: find.byType(ChipEstado),
              matching: find.text('En atención'),
            ),
          ),
          findsOneWidget,
        );
      },
    );
  });

  group('Botón SOS', () {
    testWidgets('el SOS mide 216 x 104 dp con el texto "SOS" en 32', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = const Size(360 * 3, 640 * 3);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(appDePrueba());
      await tester.pumpAndSettle();
      await ingresar(tester);

      expect(tester.getSize(find.byType(BotonSos)), const Size(216, 104));
      final texto = tester.widget<Text>(
        find.descendant(of: find.byType(BotonSos), matching: find.text('SOS')),
      );
      expect(texto.style!.fontSize, 32);
      expect(tester.takeException(), isNull);
    });

    testWidgets('BotonSos.altoActual es 104 al 100 % y al 200 %', (
      tester,
    ) async {
      final altos = <double, double>{};
      for (final escala in [1.0, 2.0]) {
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(escala)),
            child: Builder(
              builder: (context) {
                altos[escala] = BotonSos.altoActual(context);
                return const SizedBox();
              },
            ),
          ),
        );
      }
      expect(altos, {1.0: 104, 2.0: 104});
    });
  });

  group('Aviso de turno incompleto', () {
    const titulo = 'Tu guardia no se va a hacer';
    final nueve = DateTime(2026, 10, 9);
    final sofia = Vecino(
      id: 'sofia',
      nombre: 'Sofía Díaz',
      fechaNacimiento: DateTime(1990),
    );
    final ernesto = Vecino(
      id: 'ernesto',
      nombre: 'Ernesto Funes',
      fechaNacimiento: DateTime(1950),
    );

    /// El servidor simulado espera `Future.delayed` aun sin demora: hay que
    /// dejar pasar el tiempo falso para que responda (un `pump()` sin
    /// duración no alcanza).
    Future<T> enElServidor<T>(WidgetTester tester, Future<T> pedido) async {
      var listo = false;
      pedido.whenComplete(() => listo = true).ignore();
      for (var i = 0; i < 100 && !listo; i++) {
        await tester.pump(const Duration(milliseconds: 1));
      }
      return pedido;
    }

    Finder tarjetaEn(Type pantalla) => find.descendant(
      of: find.byType(pantalla, skipOffstage: false),
      matching: find.byType(TarjetaTurnoIncompleto),
      skipOffstage: false,
    );

    List<String> clavesEn(WidgetTester tester, Type pantalla) => [
      for (final t in tester.widgetList<TarjetaTurnoIncompleto>(
        tarjetaEn(pantalla),
      ))
        t.aviso.clave,
    ];

    Future<void> irA(WidgetTester tester, String pestania) async {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(pestania),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// Deja pasar el minuto del recálculo y que se dibuje.
    Future<void> pasarUnMinuto(WidgetTester tester) async {
      await tester.pump(const Duration(minutes: 1));
      await tester.pumpAndSettle();
    }

    /// Clara queda sola en la Noche del 9/10 (sin Sofía y, salvo
    /// [conErnesto], sin Ernesto), con el reloj en [hora], e ingresa.
    Future<(BarrioSeguroApp, RelojManual)> abrir(
      WidgetTester tester, {
      DateTime? hora,
      bool conErnesto = false,
      NotificacionesFalsas? notificaciones,
      PushFalso? push,
    }) async {
      pantallaAlta(tester);
      final reloj = RelojManual(hora ?? DateTime(2026, 10, 9, 21, 30));
      final app = appDePrueba(
        reloj: reloj,
        notificaciones: notificaciones,
        push: push,
      );
      final turnos = app.dependencias.turnos;
      await enElServidor(tester, turnos.salir(sofia, nueve, Franja.noche));
      if (!conErnesto) {
        await enElServidor(tester, turnos.salir(ernesto, nueve, Franja.noche));
      }
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      await ingresar(tester);
      return (app, reloj);
    }

    testWidgets('a las 21:29 no hay aviso y a las 21:30, sin tocar nada, '
        'aparece "$titulo" al pasar 1 minuto', (tester) async {
      final (_, reloj) = await abrir(
        tester,
        hora: DateTime(2026, 10, 9, 21, 29),
      );
      expect(find.text(titulo), findsNothing);

      reloj.hora = DateTime(2026, 10, 9, 21, 30);
      await pasarUnMinuto(tester);

      expect(find.text(titulo), findsOneWidget);
      expect(find.text('Entendido'), findsOneWidget);
      expect(find.text('Tocá para ver tus turnos'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(TarjetaTurnoIncompleto),
          matching: find.byIcon(Icons.chevron_right),
        ),
        findsOneWidget,
      );
    });

    testWidgets('con Ernesto de guardia de ventana no hay aviso a las '
        '21:30', (tester) async {
      await abrir(tester, conErnesto: true);
      await pasarUnMinuto(tester);
      expect(find.byType(TarjetaTurnoIncompleto), findsNothing);
    });

    testWidgets('si Sofía se vuelve a anotar, el aviso se va al minuto '
        'siguiente', (tester) async {
      final (app, _) = await abrir(tester);
      expect(find.text(titulo), findsOneWidget);

      await enElServidor(
        tester,
        app.dependencias.turnos.anotarse(sofia, nueve, Franja.noche),
      );
      await pasarUnMinuto(tester);

      expect(find.text(titulo), findsNothing);
    });

    testWidgets('a las 00:00 del 10 el aviso ya no está', (tester) async {
      final (_, reloj) = await abrir(tester);
      expect(find.text(titulo), findsOneWidget);

      reloj.hora = DateTime(2026, 10, 10);
      await pasarUnMinuto(tester);

      expect(find.text(titulo), findsNothing);
    });

    testWidgets('en segundo plano no aparece y al volver a primer plano '
        'aparece sin esperar el minuto', (tester) async {
      final (_, reloj) = await abrir(
        tester,
        hora: DateTime(2026, 10, 9, 21, 29),
      );
      expect(find.text(titulo), findsNothing);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      reloj.hora = DateTime(2026, 10, 9, 21, 30);
      await tester.pump(const Duration(minutes: 3));
      expect(find.text(titulo), findsNothing);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      // Menos de un minuto: el aviso no espera al temporizador.
      await tester.pumpAndSettle();

      expect(find.text(titulo), findsOneWidget);
    });

    testWidgets('el aviso está arriba del banner de alertas activas y de "Tu '
        'próximo turno"', (tester) async {
      await abrir(tester);

      final aviso = tester.getTopLeft(find.text(titulo)).dy;
      final banner = tester.getTopLeft(find.textContaining('en tu zona')).dy;
      final proximo = tester
          .getTopLeft(find.text('Tu próximo turno de patrullaje'))
          .dy;
      expect(aviso, lessThan(banner));
      expect(aviso, lessThan(proximo));
    });

    testWidgets('en la pestaña Turnos el aviso está arriba de "Todos / Mis '
        'turnos", en el calendario y en "Mis turnos"', (tester) async {
      await abrir(tester);
      await irA(tester, 'Turnos');

      double arriba(Finder f) => tester.getTopLeft(f).dy;
      expect(find.text(titulo), findsOneWidget);
      expect(arriba(find.text(titulo)), lessThan(arriba(find.text('Todos'))));

      await tester.tap(find.text('Mis turnos').hitTestable());
      await tester.pumpAndSettle();

      expect(find.text(titulo), findsOneWidget);
      expect(arriba(find.text(titulo)), lessThan(arriba(find.text('Todos'))));
    });

    testWidgets('el inicio y Turnos muestran los mismos avisos', (
      tester,
    ) async {
      await abrir(tester);
      // Cada lista se lee con su pestaña a la vista: la que está oculta en
      // el IndexedStack no construye sus elementos.
      final enInicio = clavesEn(tester, InicioScreen);
      await irA(tester, 'Turnos');

      expect(enInicio, ['clara|2026-10-09|noche']);
      expect(clavesEn(tester, TurnosScreen), enInicio);
    });

    testWidgets('tocar el aviso del inicio abre Turnos en "Todos" con el '
        'viernes 9 de octubre elegido', (tester) async {
      await abrir(tester);
      // En Turnos: otro día y "Mis turnos".
      await irA(tester, 'Turnos');
      await tester.tap(find.byTooltip('Día siguiente').hitTestable());
      await tester.pumpAndSettle();
      expect(find.text('Sábado 10 de octubre'), findsOneWidget);
      await tester.tap(find.text('Mis turnos').hitTestable());
      await tester.pumpAndSettle();
      await irA(tester, 'Inicio');

      await tester.tap(find.text(titulo));
      await tester.pumpAndSettle();

      expect(find.text('Turnos de patrullaje'), findsOneWidget);
      final segmentos = tester.widget<SegmentedButton<bool>>(
        find.byType(SegmentedButton<bool>),
      );
      expect(segmentos.selected, {false});
      expect(find.text('Viernes 9 de octubre'), findsOneWidget);
    });

    testWidgets('tocar el aviso en Turnos no cambia la vista ni el día', (
      tester,
    ) async {
      await abrir(tester);
      await irA(tester, 'Turnos');
      await tester.tap(find.text('Mis turnos').hitTestable());
      await tester.pumpAndSettle();

      await tester.tap(find.text(titulo));
      await tester.pumpAndSettle();

      expect(find.text('Turnos de patrullaje'), findsOneWidget);
      final segmentos = tester.widget<SegmentedButton<bool>>(
        find.byType(SegmentedButton<bool>),
      );
      expect(segmentos.selected, {true});
    });

    testWidgets('"Entendido" en el inicio saca el aviso del inicio y de '
        'Turnos', (tester) async {
      await abrir(tester);

      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();

      expect(find.text(titulo), findsNothing);
      expect(tarjetaEn(InicioScreen), findsNothing);
      await irA(tester, 'Turnos');
      expect(find.text(titulo), findsNothing);
    });

    testWidgets('"Entendido" en Turnos saca el aviso de las dos pestañas', (
      tester,
    ) async {
      await abrir(tester);
      await irA(tester, 'Turnos');

      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();

      expect(find.text(titulo), findsNothing);
      expect(tarjetaEn(TurnosScreen), findsNothing);
      await irA(tester, 'Inicio');
      expect(find.text(titulo), findsNothing);
    });

    testWidgets('una guardia de ventana sola ve "Tu guardia de ventana no se '
        'va a hacer"', (tester) async {
      // Clara tiene 45 años: el servidor la anota como patrullera. La
      // guardia de ventana sola es una vecina de 76 que se registra y se
      // anota en la Temprano del 9/10, que no tiene a nadie.
      pantallaAlta(tester);
      final reloj = RelojManual(DateTime(2026, 10, 9, 19, 30));
      final app = appDePrueba(reloj: reloj);
      final d = app.dependencias;
      final mayor = await enElServidor(
        tester,
        d.sesion.registrar(
          nombre: 'Delia Paz',
          fechaNacimiento: DateTime(1950, 2, 1),
          telefono: '1122334455',
          calle: 'Plantamura',
          cuadra: '100',
          codigoComision: 'SOBERANIA',
          clave: 'clave1234',
        ),
      );
      final turno = await enElServidor(
        tester,
        d.turnos.anotarse(mayor, nueve, Franja.temprano),
      );
      expect(turno.guardiaVentana?.id, mayor.id);

      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      expect(
        find.text('Tu guardia de ventana no se va a hacer'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Nadie se anotó para patrullar en el turno del viernes 9 de '
          'octubre, 20:00 - 22:00. Sin patrulla, la guardia no se hace: no '
          'hace falta que vigiles desde tu ventana.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('si fallan los turnos del aviso, el inicio muestra sus alertas '
        'y Turnos su calendario', (tester) async {
      pantallaAlta(tester);
      // El 1/11 a las 00:30 el aviso pide noviembre y octubre; noviembre
      // falla. El inicio y Turnos piden solo octubre.
      final reloj = RelojManual(DateTime(2026, 11, 1, 0, 30));
      final base = appDePrueba(reloj: reloj).dependencias;
      final turnos = _TurnosSoloDeOctubre(base.turnos);
      final app = BarrioSeguroApp(
        dependencias: Dependencias(
          conexion: base.conexion,
          alertas: base.alertas,
          turnos: turnos,
          sesion: base.sesion,
          bus: base.bus,
          reloj: base.reloj,
          mesDeTurnos: base.mesDeTurnos,
          capacidades: base.capacidades,
          politicas: base.politicas,
          telefono: base.telefono,
          preferencias: base.preferencias,
          ubicacion: base.ubicacion,
          notificaciones: base.notificaciones,
          avisos: base.avisos,
          push: base.push,
          descargaCsv: base.descargaCsv,
        ),
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      await ingresar(tester);
      await pasarUnMinuto(tester);

      expect(turnos.fallidos, isNotEmpty);
      expect(find.byType(TarjetaTurnoIncompleto), findsNothing);
      expect(find.text('Alertas cerca tuyo'), findsOneWidget);
      expect(find.text('Tu próximo turno de patrullaje'), findsOneWidget);

      await irA(tester, 'Turnos');
      expect(find.text('Todos'), findsOneWidget);
      expect(find.text('Viernes 9 de octubre'), findsOneWidget);
    });

    testWidgets('con el aviso a la vista no se mostró ninguna notificación ni '
        'hubo suscripciones push', (tester) async {
      final notificaciones = NotificacionesFalsas();
      final push = PushFalso();
      await abrir(tester, notificaciones: notificaciones, push: push);
      await pasarUnMinuto(tester);
      expect(find.text(titulo), findsOneWidget);

      expect(notificaciones.avisadas, isEmpty);
      expect(notificaciones.tardias, isEmpty);
      expect(notificaciones.reaperturas, isEmpty);
      expect(notificaciones.reaperturasTardias, isEmpty);
      expect(notificaciones.reaperturasTardiasSinHora, isEmpty);
      expect(push.suscripciones, 0);
    });
  });
}

/// Turnos que fallan para cualquier mes que no sea octubre de 2026: el mes
/// del calendario anda y el aviso, que también pide noviembre, no.
class _TurnosSoloDeOctubre implements TurnosRepository {
  _TurnosSoloDeOctubre(this._real);

  final TurnosRepository _real;
  final List<DateTime> fallidos = [];

  @override
  bool get sinConexion => _real.sinConexion;

  @override
  Future<List<Turno>> obtenerTurnos(DateTime mes, {bool refrescar = false}) {
    if (mes != DateTime(2026, 10)) {
      fallidos.add(mes);
      return Future.error(Exception('sin conexión'));
    }
    return _real.obtenerTurnos(mes, refrescar: refrescar);
  }

  @override
  Future<Turno> anotarse(Vecino vecino, DateTime fecha, Franja franja) =>
      _real.anotarse(vecino, fecha, franja);

  @override
  Future<Turno> salir(Vecino vecino, DateTime fecha, Franja franja) =>
      _real.salir(vecino, fecha, franja);
}

/// [AlertasFalsas] que no responde a `crearAlerta` hasta que la prueba
/// completa [soltar].
class _AlertasLentas extends AlertasFalsas {
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
