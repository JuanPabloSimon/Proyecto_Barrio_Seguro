// Pruebas de la app completa: arranque, SOS sin red, la pantalla sin
// conexión que tapa a todas las demás y el informe mensual de alertas
// para la comisión.

import 'dart:io';

import 'package:barrio_seguro/data/repositories/alertas_repository.dart';
import 'package:barrio_seguro/data/services/bus_de_eventos.dart';
import 'package:barrio_seguro/data/services/simulados/conexion_service_simulado.dart';
import 'package:barrio_seguro/dependencias.dart';
import 'package:barrio_seguro/main.dart';
import 'package:barrio_seguro/ui/core/widgets/con_view_model.dart';
import 'package:barrio_seguro/ui/core/widgets/boton_sos.dart';
import 'package:barrio_seguro/ui/core/widgets/mapa_barrio.dart';
import 'package:barrio_seguro/ui/core/tema/app_theme.dart';
import 'package:barrio_seguro/ui/perfil/view_models/perfil_view_model.dart';
import 'package:barrio_seguro/ui/perfil/widgets/perfil_screen.dart';
import 'package:barrio_seguro/ui/sos/view_models/sos_view_model.dart';
import 'package:barrio_seguro/ui/sos/widgets/sos_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
