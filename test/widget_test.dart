// Pruebas de la app completa: arranque, SOS sin red, la pantalla sin
// conexión que tapa a todas las demás y el informe mensual de alertas
// para la comisión.

import 'dart:io';

import 'package:barrio_seguro/data/repositories/alertas_repository.dart';
import 'package:barrio_seguro/data/services/bus_de_eventos.dart';
import 'package:barrio_seguro/data/services/simulados/conexion_service_simulado.dart';
import 'package:barrio_seguro/dependencias.dart';
import 'package:barrio_seguro/domain/models/alerta.dart';
import 'package:barrio_seguro/main.dart';
import 'package:barrio_seguro/ui/alerta_detalle/view_models/detalle_alerta_view_model.dart';
import 'package:barrio_seguro/ui/alerta_detalle/widgets/detalle_alerta_screen.dart';
import 'package:barrio_seguro/ui/core/widgets/con_view_model.dart';
import 'package:barrio_seguro/ui/core/widgets/boton_sos.dart';
import 'package:barrio_seguro/ui/core/widgets/mapa_barrio.dart';
import 'package:barrio_seguro/ui/core/widgets/marca_sos.dart';
import 'package:barrio_seguro/ui/core/widgets/marca_tardia.dart';
import 'package:barrio_seguro/ui/core/widgets/pin_alerta.dart';
import 'package:barrio_seguro/ui/core/widgets/tarjeta_alerta.dart';
import 'package:barrio_seguro/ui/core/tema/app_theme.dart';
import 'package:barrio_seguro/ui/perfil/view_models/perfil_view_model.dart';
import 'package:barrio_seguro/ui/perfil/widgets/perfil_screen.dart';
import 'package:barrio_seguro/ui/sos/view_models/sos_view_model.dart';
import 'package:barrio_seguro/ui/sos/widgets/sos_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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
}
