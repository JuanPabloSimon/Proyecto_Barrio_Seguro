// Tests de accesibilidad de Barrio Seguro.
//
// - Un test por pantalla principal con las guías de flutter_test: tamaño
//   táctil (Android 48 dp, iOS 44 pt), etiquetas en lo tocable y contraste
//   de texto.
// - Las mismas pantallas con el texto del sistema al 200 %: si algo
//   desborda, Flutter reporta el error y el test falla.
// - El contraste de todos los pares de colores de AppColors (la guía de
//   contraste solo mira texto; esta cubre íconos, bordes y pines).
//
// Los tests usan una fuente de prueba con letras cuadradas, más ancha que
// la real: si el diseño aguanta acá, en el teléfono aguanta con margen.

import 'dart:async';
import 'dart:ui' show CheckedState;

import 'package:barrio_seguro/data/services/bus_de_eventos.dart';
import 'package:barrio_seguro/data/services/simulados/conexion_service_simulado.dart';
import 'package:barrio_seguro/data/services/simulados/servidor_simulado.dart';
import 'package:barrio_seguro/domain/barrio.dart';
import 'package:barrio_seguro/domain/models/alerta.dart';
import 'package:barrio_seguro/domain/models/vecino.dart';
import 'package:barrio_seguro/ui/alerta_detalle/view_models/detalle_alerta_view_model.dart';
import 'package:barrio_seguro/ui/alerta_detalle/widgets/detalle_alerta_screen.dart';
import 'package:barrio_seguro/ui/core/presentacion_alerta.dart';
import 'package:barrio_seguro/ui/core/tema/app_colors.dart';
import 'package:barrio_seguro/ui/core/tema/app_theme.dart';
import 'package:barrio_seguro/ui/core/tema/transiciones.dart';
import 'package:barrio_seguro/ui/core/widgets/boton_sos.dart';
import 'package:barrio_seguro/ui/core/widgets/mapa_barrio.dart';
import 'package:barrio_seguro/ui/core/widgets/marca_sos.dart';
import 'package:barrio_seguro/ui/core/ubicacion_de_alerta.dart';
import 'package:barrio_seguro/ui/core/widgets/tarjeta_alerta.dart';
import 'package:barrio_seguro/ui/core/widgets/tarjeta_tocable.dart';
import 'package:barrio_seguro/ui/reportar_alerta/view_models/reportar_alerta_view_model.dart';
import 'package:barrio_seguro/ui/reportar_alerta/widgets/reportar_alerta_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ayudas/app_de_prueba.dart';
import 'ayudas/bases_de_prueba.dart';
import 'ayudas/falsos.dart';

// ---------------------------------------------------------------------------
// Preparación
// ---------------------------------------------------------------------------

/// Pantalla de teléfono de 360 dp de ancho. Para las guías se usa una
/// pantalla alta, así se evalúa todo el contenido sin desplazar.
void configurarPantalla(
  WidgetTester tester, {
  double alto = 1600,
  double escalaTexto = 1.0,
}) {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = Size(360 * 3, alto * 3);
  tester.platformDispatcher.textScaleFactorTestValue = escalaTexto;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Cada prueba arranca la app con dependencias nuevas (ver
/// `appDePrueba`), así ninguna ve lo que cambió otra.
Future<void> abrirApp(
  WidgetTester tester, {
  Map<String, DateTime> llegadas = const {},
}) async {
  await tester.pumpWidget(appDePrueba(llegadas: llegadas));
  await tester.pumpAndSettle();
}

/// Lleva el elemento a la vista. No pasarle buscadores con .first o .at():
/// fallan si el elemento todavía no se construyó.
///
/// Los ListView solo construyen lo que está cerca de la pantalla: con el
/// texto al 200 % un botón puede ni siquiera existir todavía. En ese caso
/// se desplaza la lista visible hasta que aparezca.
Future<void> mostrar(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    final listaVisible = find
        .byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        )
        .hitTestable()
        .first;
    await tester.scrollUntilVisible(finder, 200, scrollable: listaVisible);
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

/// Lleva el elemento a la vista y lo toca.
Future<void> tocar(WidgetTester tester, Finder finder) async {
  await mostrar(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Activa el elemento como lo hace un lector de pantalla: la acción "tocar"
/// de su nodo de semántica. Sirve para los pines del mapa: con el texto al
/// 200 % el mapa queda bajo, los pines se juntan y el botón SOS tapa parte
/// de ellos, así que un toque en el centro del pin puede caer en otro.
Future<void> activarConLector(WidgetTester tester, Finder finder) async {
  await mostrar(tester, finder);
  final nodo = tester.getSemantics(finder);
  nodo.owner!.performAction(nodo.id, SemanticsAction.tap);
  await tester.pumpAndSettle();
}

Future<void> ingresar(
  WidgetTester tester, {
  Map<String, DateTime> llegadas = const {},
}) async {
  await abrirApp(tester, llegadas: llegadas);
  await tocar(tester, find.text('Ingresar'));
}

Future<void> irAPestania(
  WidgetTester tester,
  String pestania, {
  Map<String, DateTime> llegadas = const {},
}) async {
  await ingresar(tester, llegadas: llegadas);
  await tocar(
    tester,
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(pestania),
    ),
  );
}

Future<void> verificarGuias(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

// ---------------------------------------------------------------------------
// Pantallas: cada una con cómo llegar a ella
// ---------------------------------------------------------------------------

class Pantalla {
  const Pantalla(this.nombre, this.abrir);

  final String nombre;
  final Future<void> Function(WidgetTester tester) abrir;
}

final pantallas = <Pantalla>[
  Pantalla('Login', abrirApp),
  Pantalla('Registro con aviso de rol', (tester) async {
    await abrirApp(tester);
    await tocar(tester, find.text('Todavía no tengo cuenta'));
    final fecha = find.widgetWithText(TextField, 'Fecha de nacimiento');
    await mostrar(tester, fecha);
    await tester.enterText(fecha, '14051950');
    await tester.pumpAndSettle();
    expect(
      find.text('Vas a participar como guardia de ventana'),
      findsOneWidget,
    );
  }),
  Pantalla('Inicio', ingresar),
  Pantalla('Llamar al 911 (diálogo)', (tester) async {
    await ingresar(tester);
    await tocar(tester, find.text('Llamar al 911'));
    expect(find.text('¿Llamar al 911?'), findsOneWidget);
  }),
  Pantalla('Detalle de alerta', (tester) async {
    await ingresar(tester);
    // Un buscador concreto (no .first): .first falla si la tarjeta todavía
    // no se construyó, antes de poder desplazar la lista hasta ella.
    await tocar(tester, find.widgetWithText(TarjetaAlerta, 'Intento de robo'));
    expect(find.text('Detalle de alerta'), findsOneWidget);
  }),
  Pantalla('Turnos', (tester) => irAPestania(tester, 'Turnos')),
  Pantalla('Mis turnos', (tester) async {
    await irAPestania(tester, 'Turnos');
    // hitTestable: "Mis turnos" también existe en el perfil, que está
    // cargado pero no visible.
    await tocar(tester, find.text('Mis turnos').hitTestable());
  }),
  Pantalla('Mapa', (tester) => irAPestania(tester, 'Mapa')),
  Pantalla('Resumen de alerta en el mapa', (tester) async {
    await irAPestania(tester, 'Mapa');
    await activarConLector(
      tester,
      find.bySemanticsLabel(RegExp('^Alerta: Robo de celular')),
    );
    expect(find.text('Ver detalle'), findsOneWidget);
  }),
  Pantalla('Perfil', (tester) => irAPestania(tester, 'Perfil')),
  Pantalla('Editar datos', (tester) async {
    await irAPestania(tester, 'Perfil');
    await tocar(tester, find.text('Editar datos personales'));
  }),
  Pantalla('Aviso antes de compartir la ubicación', (tester) async {
    await irAPestania(tester, 'Perfil');
    await tocar(
      tester,
      find.widgetWithText(
        SwitchListTile,
        'Compartir ubicación exacta en alertas',
      ),
    );
    expect(find.text('¿Compartir tu ubicación exacta?'), findsOneWidget);
  }),
  Pantalla('Llamar al 911 sin teléfono (diálogo)', (tester) async {
    await tester.pumpWidget(
      appDePrueba(
        capacidades: const CapacidadesFalsas(puedeHacerLlamadas: false),
      ),
    );
    await tester.pumpAndSettle();
    await tocar(tester, find.text('Ingresar'));
    await tocar(tester, find.text('Llamar al 911'));
    expect(find.text('Llamá al 911 desde un teléfono'), findsOneWidget);
  }),
  Pantalla('Mis alertas', (tester) async {
    await irAPestania(tester, 'Perfil');
    await tocar(tester, find.text('Mis alertas reportadas'));
  }),
  Pantalla('Informe de alertas', (tester) async {
    await irAPestania(tester, 'Perfil');
    await tocar(tester, find.text('Informe mensual de alertas'));
    expect(find.text('Informe de alertas'), findsOneWidget);
  }),
  Pantalla('SOS: confirmación', (tester) async {
    await ingresar(tester);
    await tocar(tester, find.byType(BotonSos));
    expect(find.text('¿Enviar alerta SOS?'), findsOneWidget);
  }),
  Pantalla('SOS: alerta enviada', (tester) async {
    await ingresar(tester);
    await tocar(tester, find.byType(BotonSos));
    await tocar(tester, find.text('Sí, enviar alerta'));
    expect(find.text('Alerta enviada'), findsOneWidget);
    await mostrar(tester, find.text('Volver'));
    expect(find.text('Volver'), findsOneWidget);
  }),
  Pantalla('SOS: confirmar "Ya estoy a salvo" (diálogo)', (tester) async {
    await abrirSosEnviado(tester);
    await tocar(tester, find.text('Ya estoy a salvo'));
    expect(find.text('¿Ya estás a salvo?'), findsOneWidget);
    await mostrar(tester, find.text('Sí, estoy a salvo'));
  }),
  Pantalla('SOS: confirmar "Fue una falsa alarma" (diálogo)', (tester) async {
    await abrirSosEnviado(tester);
    await tocar(tester, find.text('Fue una falsa alarma'));
    expect(find.text('¿Fue una falsa alarma?'), findsOneWidget);
    await mostrar(tester, find.text('Sí, fue una falsa alarma'));
  }),
  Pantalla('Inicio con una alerta SOS', (tester) async {
    await abrirSosYVolver(tester);
    final tarjeta = find.bySemanticsLabel(RegExp('^Alerta SOS: '));
    await mostrar(tester, tarjeta);
    await mostrar(
      tester,
      find.descendant(of: tarjeta, matching: find.byType(MarcaSos)),
    );
  }),
  Pantalla('Resumen de una alerta SOS en el mapa', (tester) async {
    await abrirSosYVolver(tester);
    await tocar(
      tester,
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Mapa'),
      ),
    );
    await activarConLector(
      tester,
      find.bySemanticsLabel(RegExp('^Alerta SOS: ')),
    );
    await mostrar(
      tester,
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(MarcaSos),
      ),
    );
  }),
  Pantalla('Detalle de una alerta SOS', (tester) async {
    await abrirSosYVolver(tester);
    await tocar(tester, find.bySemanticsLabel(RegExp('^Alerta SOS: ')));
    expect(find.text('Detalle de alerta'), findsOneWidget);
    await mostrar(tester, find.byType(MarcaSos));
  }),
  Pantalla('Sin conexión', abrirSinConexion),
  Pantalla('Inicio con una alerta tardía', (tester) async {
    await ingresar(tester, llegadas: llegadasTardias);
    await mostrar(
      tester,
      find.descendant(
        of: find.widgetWithText(TarjetaAlerta, 'Intento de robo'),
        matching: find.text(marcaDePrueba),
      ),
    );
  }),
  Pantalla('Resumen de una alerta tardía en el mapa', (tester) async {
    await irAPestania(tester, 'Mapa', llegadas: llegadasTardias);
    await activarConLector(
      tester,
      find.bySemanticsLabel(RegExp('^Alerta: Intento')),
    );
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text(marcaDePrueba),
      ),
      findsOneWidget,
    );
  }),
  Pantalla('Detalle de una alerta tardía, con quién la reportó', (
    tester,
  ) async {
    await ingresar(tester, llegadas: llegadasTardias);
    await tocar(tester, find.widgetWithText(TarjetaAlerta, 'Intento de robo'));
    expect(find.text(marcaDePrueba), findsOneWidget);
    await mostrar(tester, find.text('Pedro'));
  }),
  Pantalla('Reportar alerta', abrirReportarAlerta),
  Pantalla('Reportar alerta con errores', (tester) async {
    await abrirReportarAlerta(tester);
    await tocar(tester, find.text('Enviar alerta'));
    await mostrar(
      tester,
      find.text('Elegí qué tipo de alerta es.', skipOffstage: false),
    );
    expect(find.text('Escribí un título para la alerta.'), findsOneWidget);
  }),
  Pantalla(
    'Detalle de alerta con error de estado',
    abrirDetalleConErrorDeEstado,
  ),
  Pantalla('Detalle de alerta de un vecino común', (tester) async {
    await abrirDetalleSuelto(
      tester,
      alerta: alertaDePrueba(reportadaPor: 'jorge'),
    );
    expect(find.text('Estado de la alerta'), findsNothing);
    await mostrar(tester, find.text('Llamar al 911'));
  }),
  Pantalla('Confirmar marcar como resuelta (diálogo)', (tester) async {
    await abrirConfirmarResuelta(tester);
    await mostrar(tester, find.text('Sí, está resuelta'));
  }),
  Pantalla('Confirmar volver a abrir (diálogo)', (tester) async {
    await abrirConfirmarReabrir(tester);
    await mostrar(tester, find.text('Sí, volver a abrirla'));
  }),
  Pantalla('Descartar la alerta (diálogo)', (tester) async {
    await abrirReportarAlerta(tester);
    await tocar(tester, find.text('Robo'));
    await tocar(tester, find.byTooltip('Cerrar'));
    expect(find.text('¿Descartar la alerta?'), findsOneWidget);
    await mostrar(tester, find.text('Sí, descartar'));
  }),
];

/// Ingresa y toca "Reportar alerta" en el inicio.
Future<void> abrirReportarAlerta(WidgetTester tester) async {
  await ingresar(tester);
  await tocar(tester, find.text('Reportar alerta'));
  expect(find.text('¿Qué pasó?'), findsOneWidget);
}

/// Ingresa, toca el botón SOS y envía la alerta.
Future<void> abrirSosEnviado(WidgetTester tester) async {
  await ingresar(tester);
  await tocar(tester, find.byType(BotonSos));
  await tocar(tester, find.text('Sí, enviar alerta'));
  expect(find.text('Alerta enviada'), findsOneWidget);
}

/// Envía un SOS y vuelve al inicio con "Volver": la alerta queda activa.
Future<void> abrirSosYVolver(WidgetTester tester) async {
  await abrirSosEnviado(tester);
  await tocar(tester, find.text('Volver'));
  expect(find.text('Alerta enviada'), findsNothing);
  // El aviso de "sigue activa" dura 6 segundos. Con texto grande ocupa
  // media pantalla y sube el botón SOS sobre la lista: se espera a que se
  // vaya para mirar la pantalla como queda.
  await tester.pump(const Duration(seconds: 7));
  await tester.pumpAndSettle();
}

/// a3 ("Intento de robo", de Pedro) es de las 11:00 y su aviso llegó a las
/// 11:30: es tardía.
final llegadasTardias = {'a3': DateTime(2026, 10, 1, 11, 30)};
const marcaDePrueba = 'Llegó con demora. Alerta de las 11:00';

const tituloSinConexion = 'Necesitás conexión a internet para usar la app';

/// La app sin conexión: la pantalla sin conexión tapa a todas las demás.
Future<void> abrirSinConexion(WidgetTester tester) async {
  await tester.pumpWidget(
    appDePrueba(conexion: ConexionServiceSimulado(conectado: false)),
  );
  await tester.pumpAndSettle();
  expect(find.text(tituloSinConexion), findsOneWidget);
}

/// El detalle de [alerta] solo, con [vecino] en la sesión (por defecto,
/// Clara como vecina común) y las alertas en [alertas].
Future<AlertasFalsas> abrirDetalleSuelto(
  WidgetTester tester, {
  Alerta? alerta,
  Vecino? vecino,
}) async {
  MapaBarrio.cargarCalles = false;
  final laAlerta = alerta ?? alertaDePrueba();
  final alertas = AlertasFalsas([laAlerta]);
  final vm = DetalleAlertaViewModel(
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
      home: DetalleAlertaScreen(
        viewModel: vm,
        capacidades: const CapacidadesFalsas(),
        telefono: TelefonoFalso(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return alertas;
}

Finder opcionDeEstado(String etiqueta) =>
    find.widgetWithText(RadioListTile<EstadoAlerta>, etiqueta);

/// Ingresa y abre el detalle de a1 ("Actividad sospechosa", de Clara).
Future<void> abrirDetalleDeAlertaPropia(WidgetTester tester) async {
  await ingresar(tester);
  await tocar(
    tester,
    find.widgetWithText(TarjetaAlerta, 'Actividad sospechosa'),
  );
  expect(find.text('Detalle de alerta'), findsOneWidget);
}

/// Abre el diálogo "¿Marcar la alerta como resuelta?" desde la app.
Future<void> abrirConfirmarResuelta(WidgetTester tester) async {
  await abrirDetalleDeAlertaPropia(tester);
  await tocar(tester, opcionDeEstado('Resuelta'));
  expect(find.text('¿Marcar la alerta como resuelta?'), findsOneWidget);
}

/// Abre el diálogo "¿Volver a abrir la alerta?" sobre una alerta resuelta.
Future<void> abrirConfirmarReabrir(WidgetTester tester) async {
  await abrirDetalleSuelto(
    tester,
    alerta: alertaDePrueba(estado: EstadoAlerta.resuelta),
  );
  await tocar(tester, opcionDeEstado('En atención'));
  expect(find.text('¿Volver a abrir la alerta?'), findsOneWidget);
}

const errorDeEstadoSinConexion =
    'No pudimos cambiar el estado. Probá de nuevo.';

/// El detalle con el error de cambio de estado a la vista.
Future<void> abrirDetalleConErrorDeEstado(WidgetTester tester) async {
  final alertas = await abrirDetalleSuelto(tester);
  alertas.falla = true;
  // Entre Activa y En atención no se pide confirmación.
  await tocar(tester, opcionDeEstado('En atención'));
  await mostrar(tester, find.text(errorDeEstadoSinConexion));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Guías de accesibilidad', () {
    for (final pantalla in pantallas) {
      testWidgets(pantalla.nombre, (tester) async {
        final handle = tester.ensureSemantics();
        configurarPantalla(tester);
        await pantalla.abrir(tester);
        await verificarGuias(tester);
        handle.dispose();
      });
    }
  });

  group('Texto del sistema al 200 %', () {
    for (final pantalla in pantallas) {
      testWidgets(pantalla.nombre, (tester) async {
        final handle = tester.ensureSemantics();
        configurarPantalla(tester, alto: 800, escalaTexto: 2.0);
        await pantalla.abrir(tester);
        // Un desborde (RenderFlex overflowed) ya hace fallar el test; esto
        // además confirma que no quedó ninguna otra excepción pendiente.
        expect(tester.takeException(), isNull);
        handle.dispose();
      });
    }
  });

  group('Colores', () {
    test('Los pares de la marca SOS están en AppColors', () {
      final pares = {
        for (final par in AppColors.paresDeContraste) par.descripcion: par,
      };
      final texto = pares['Texto sobre rojo suave (marca SOS)']!;
      expect(texto.frente, AppColors.texto);
      expect(texto.fondo, AppColors.emergenciaSuave);
      expect(texto.minimo, ParContraste.textoNormal);
      final icono = pares['Rojo de emergencia sobre rojo suave (marca SOS)']!;
      expect(icono.frente, AppColors.emergencia);
      expect(icono.fondo, AppColors.emergenciaSuave);
      expect(icono.minimo, ParContraste.componente);
    });

    test('Todos los pares de AppColors cumplen el contraste mínimo', () {
      for (final par in AppColors.paresDeContraste) {
        expect(
          par.ratio,
          greaterThanOrEqualTo(par.minimo),
          reason:
              '${par.descripcion}: ${par.ratio.toStringAsFixed(2)}:1, '
              'mínimo ${par.minimo}:1',
        );
      }
    });
  });

  group('Barrio', () {
    test('Todas las alertas de ejemplo están dentro del radio de alertas', () {
      final servidor = ServidorSimulado(reloj: relojDePrueba);
      for (final alerta in servidor.alertas().map(Alerta.fromJson)) {
        expect(
          Barrio.estaDentroDelRadio(alerta.ubicacion),
          isTrue,
          reason:
              '${alerta.tipo} está a '
              '${Barrio.distanciaAlCentro(alerta.ubicacion).round()} m del centro',
        );
      }
    });
  });

  group('Movimiento', () {
    testWidgets('Con "Quitar animaciones" la transición no anima', (
      tester,
    ) async {
      const pantallaNueva = SizedBox(key: Key('nueva'));
      late Widget resultado;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              resultado =
                  const TransicionAccesible(ZoomPageTransitionsBuilder())
                      .buildTransitions<void>(
                        MaterialPageRoute<void>(builder: (_) => pantallaNueva),
                        context,
                        kAlwaysCompleteAnimation,
                        kAlwaysDismissedAnimation,
                        pantallaNueva,
                      );
              return const SizedBox();
            },
          ),
        ),
      );

      expect(identical(resultado, pantallaNueva), isTrue);
    });
  });

  group('Botón SOS', () {
    testWidgets('Un toque pide confirmación y no envía la alerta', (
      tester,
    ) async {
      configurarPantalla(tester);
      await ingresar(tester);
      await tocar(tester, find.byType(BotonSos));

      expect(find.text('¿Enviar alerta SOS?'), findsOneWidget);
      expect(find.text('Alerta enviada'), findsNothing);

      await tocar(tester, find.text('No, cancelar'));
      expect(find.text('¿Enviar alerta SOS?'), findsNothing);
    });

    testWidgets('Se puede activar con lector de pantalla', (tester) async {
      final handle = tester.ensureSemantics();
      configurarPantalla(tester);
      await ingresar(tester);

      final nodo = tester.getSemantics(find.byType(BotonSos));
      expect(nodo.label, 'SOS. Pedir ayuda a los vecinos');
      expect(nodo.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      handle.dispose();
    });

    testWidgets(
      'al 200 % en 360 dp el SOS mide al menos 104 de alto y entra en la '
      'pantalla sin desbordes',
      (tester) async {
        configurarPantalla(tester, alto: 640, escalaTexto: 2.0);
        await ingresar(tester);

        expect(tester.takeException(), isNull);
        final sos = tester.getRect(find.byType(BotonSos));
        expect(sos.height, greaterThanOrEqualTo(104));
        expect(sos.left, greaterThanOrEqualTo(0));
        expect(sos.right, lessThanOrEqualTo(360));
      },
    );

    testWidgets(
      'al 200 % en 360 x 640 el mapa y la última alerta del inicio se pueden '
      'ver enteros por encima del SOS',
      (tester) async {
        configurarPantalla(tester, alto: 640, escalaTexto: 2.0);
        await ingresar(tester);

        final mapa = find.ancestor(
          of: find.text('Abrir el mapa de alertas', skipOffstage: false),
          matching: find.byType(TarjetaTocable, skipOffstage: false),
        );
        await mostrar(tester, find.text('Abrir el mapa de alertas'));
        await tester.ensureVisible(mapa);
        await tester.pumpAndSettle();
        expect(
          tester.getRect(mapa).bottom,
          lessThanOrEqualTo(tester.getRect(find.byType(BotonSos)).top),
        );

        // Hasta el final de la lista: la última tarjeta queda a la vista.
        final lista = find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        );
        final posicion = tester.state<ScrollableState>(lista).position;
        while (posicion.pixels < posicion.maxScrollExtent) {
          await tester.drag(lista, const Offset(0, -200));
          await tester.pumpAndSettle();
        }
        final tarjetas = find.byType(TarjetaAlerta);
        expect(tarjetas, findsWidgets);
        final ultimaAbajo = tarjetas
            .evaluate()
            .map((e) => tester.getRect(find.byElementPredicate((x) => x == e)))
            .map((r) => r.bottom)
            .reduce((a, b) => a > b ? a : b);
        expect(
          ultimaAbajo,
          lessThanOrEqualTo(tester.getRect(find.byType(BotonSos)).top),
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('SOS enviado', () {
    testWidgets(
      'el botón "Volver" y los botones de los diálogos se anuncian con su texto',
      (tester) async {
        final handle = tester.ensureSemantics();
        configurarPantalla(tester);
        await abrirSosEnviado(tester);

        void anunciaSuTexto(Finder boton, String texto) {
          final datos = tester.getSemantics(boton).getSemanticsData();
          expect(datos.label, texto);
          expect(datos.hasAction(SemanticsAction.tap), isTrue);
        }

        anunciaSuTexto(find.widgetWithText(OutlinedButton, 'Volver'), 'Volver');

        for (final (abrir, titulo, confirmar) in [
          ('Ya estoy a salvo', '¿Ya estás a salvo?', 'Sí, estoy a salvo'),
          (
            'Fue una falsa alarma',
            '¿Fue una falsa alarma?',
            'Sí, fue una falsa alarma',
          ),
        ]) {
          await tocar(tester, find.text(abrir));
          expect(tester.getSemantics(find.text(titulo)).label, titulo);
          anunciaSuTexto(
            find.widgetWithText(OutlinedButton, 'Seguir con la alerta'),
            'Seguir con la alerta',
          );
          anunciaSuTexto(
            find.widgetWithText(FilledButton, confirmar),
            confirmar,
          );
          await tocar(tester, find.text('Seguir con la alerta'));
        }
        handle.dispose();
      },
    );
  });

  group('Pantalla sin conexión', () {
    testWidgets('el título se anuncia como encabezado', (tester) async {
      final handle = tester.ensureSemantics();
      configurarPantalla(tester);
      await abrirSinConexion(tester);

      final datos = tester
          .getSemantics(find.text(tituloSinConexion))
          .getSemanticsData();
      expect(datos.label, tituloSinConexion);
      expect(datos.flagsCollection.isHeader, isTrue);
      expect(datos.flagsCollection.isLiveRegion, isTrue);
      handle.dispose();
    });

    testWidgets('"Llamar al 911" tiene etiqueta y mide al menos 48 x 48 dp', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      configurarPantalla(tester);
      await abrirSinConexion(tester);

      final boton = find.widgetWithText(FilledButton, 'Llamar al 911');
      final tamanio = tester.getSize(boton);
      expect(tamanio.width, greaterThanOrEqualTo(48));
      expect(tamanio.height, greaterThanOrEqualTo(48));
      final nodo = tester.getSemantics(boton);
      expect(nodo.label, contains('Llamar al 911'));
      expect(nodo.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      handle.dispose();
    });

    testWidgets(
      'al 200 % no desborda y "Llamar al 911" se alcanza desplazando',
      (tester) async {
        final telefono = TelefonoFalso();
        configurarPantalla(tester, alto: 600, escalaTexto: 2.0);
        await tester.pumpWidget(
          appDePrueba(
            conexion: ConexionServiceSimulado(conectado: false),
            telefono: telefono,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tocar(tester, find.text('Llamar al 911'));
        expect(find.text('¿Llamar al 911?'), findsOneWidget);
        await tocar(tester, find.text('Llamar'));

        expect(telefono.marcados, ['911']);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Alertas tardías', () {
    testWidgets('la etiqueta de la tarjeta y del pin incluyen la marca', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      configurarPantalla(tester);
      await ingresar(tester, llegadas: llegadasTardias);

      final tarjeta = find.bySemanticsLabel(RegExp('^Alerta de intento'));
      await mostrar(tester, tarjeta);
      expect(
        tester.getSemantics(tarjeta).label,
        'Alerta de intento de robo, hace 1 hora, activa. '
        '$marcaDePrueba. Calle Gran Cap. Sur. Ver detalle',
      );

      await tocar(
        tester,
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Mapa'),
        ),
      );
      expect(
        tester
            .getSemantics(find.bySemanticsLabel(RegExp('^Alerta: Intento')))
            .label,
        'Alerta: Intento de robo, activa, Calle Gran Cap. Sur. '
        '$marcaDePrueba. Ver resumen',
      );
      // Una alerta que no es tardía no la lleva.
      expect(
        tester
            .getSemantics(find.bySemanticsLabel(RegExp('^Alerta: Moto')))
            .label,
        isNot(contains('Llegó con demora')),
      );
      handle.dispose();
    });

    testWidgets(
      'el lector lee "Reportada por" y el nombre en una sola etiqueta',
      (tester) async {
        final handle = tester.ensureSemantics();
        configurarPantalla(tester);
        await ingresar(tester, llegadas: llegadasTardias);
        await tocar(
          tester,
          find.widgetWithText(TarjetaAlerta, 'Intento de robo'),
        );
        await mostrar(tester, find.text('Reportada por'));

        final titulo = tester.getSemantics(find.text('Reportada por'));
        final nombre = tester.getSemantics(find.text('Pedro'));
        expect(identical(titulo, nombre), isTrue);
        expect(titulo.label, contains('Reportada por'));
        expect(titulo.label, contains('Pedro'));
        handle.dispose();
      },
    );

    testWidgets('"Reportada por" con nombre al 200 % sin desbordes', (
      tester,
    ) async {
      configurarPantalla(tester, alto: 800, escalaTexto: 2.0);
      await ingresar(tester, llegadas: llegadasTardias);
      await tocar(
        tester,
        find.widgetWithText(TarjetaAlerta, 'Intento de robo'),
      );
      await mostrar(tester, find.text('Pedro'));

      expect(find.text('Reportada por').hitTestable(), findsOneWidget);
      expect(find.text('Pedro').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('los pares de contraste de la marca están registrados', () {
      final pares = {
        for (final par in AppColors.paresDeContraste) par.descripcion: par,
      };
      final texto = pares['Texto de la marca tardía']!;
      expect(texto.frente, AppColors.texto);
      expect(texto.fondo, AppColors.alertaSuave);
      expect(texto.minimo, ParContraste.textoNormal);
      expect(texto.cumple, isTrue);

      final icono = pares['Ícono de la marca tardía']!;
      expect(icono.frente, AppColors.alerta);
      expect(icono.fondo, AppColors.alertaSuave);
      expect(icono.minimo, ParContraste.componente);
      expect(icono.cumple, isTrue);
    });
  });

  group('Reportar alerta', () {
    testWidgets(
      'los tipos se anuncian con su nombre y si están elegidos y los campos '
      'con su nombre',
      (tester) async {
        final handle = tester.ensureSemantics();
        configurarPantalla(tester);
        await abrirReportarAlerta(tester);
        await tocar(tester, find.text('Robo'));

        SemanticsData datosDe(String tipo) => tester
            .getSemantics(
              find.widgetWithText(RadioListTile<CategoriaAlerta>, tipo),
            )
            .getSemanticsData();

        for (final tipo in [
          'Actividad sospechosa',
          'Vehículo sospechoso',
          'Robo',
          'Ruidos',
        ]) {
          final datos = datosDe(tipo);
          expect(datos.label, tipo);
          expect(datos.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
          expect(
            datos.flagsCollection.isChecked,
            tipo == 'Robo' ? CheckedState.isTrue : CheckedState.isFalse,
          );
        }

        for (final campo in [
          'Título',
          'Descripción (opcional)',
          'Dirección o referencia (opcional)',
        ]) {
          final datos = tester
              .getSemantics(find.widgetWithText(TextField, campo))
              .getSemanticsData();
          expect(datos.label, contains(campo));
          expect(datos.flagsCollection.isTextField, isTrue);
        }
        expect(tester.getSemantics(find.byTooltip('Cerrar')).tooltip, 'Cerrar');
        handle.dispose();
      },
    );

    testWidgets(
      'los errores de tipo y de envío son regiones en vivo con ícono',
      (tester) async {
        final handle = tester.ensureSemantics();
        configurarPantalla(tester);
        final vm = ReportarAlertaViewModel(
          alertas: AlertasFalsas([], true),
          sesion: SesionFalsa(vecinaDePrueba),
          bus: BusDeEventos(),
          ubicacion: UbicacionDeAlerta(
            capacidades: const CapacidadesFalsas(),
            preferencias: preferenciasEnMemoria(),
            ubicacion: UbicacionFalsa(),
          ),
        );
        addTearDown(vm.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: ReportarAlertaScreen(viewModel: vm),
          ),
        );
        await tester.pumpAndSettle();

        void esRegionEnVivoConIcono(String mensaje) {
          final region = find.ancestor(
            of: find.text(mensaje),
            matching: find.byWidgetPredicate(
              (w) => w is Semantics && (w.properties.liveRegion ?? false),
            ),
          );
          expect(region, findsOneWidget);
          expect(
            find.descendant(
              of: region,
              matching: find.byIcon(Icons.error_outline),
            ),
            findsOneWidget,
          );
          expect(
            tester
                .getSemantics(find.text(mensaje))
                .getSemanticsData()
                .flagsCollection
                .isLiveRegion,
            isTrue,
          );
        }

        await tocar(tester, find.text('Enviar alerta'));
        esRegionEnVivoConIcono('Elegí qué tipo de alerta es.');

        await tocar(tester, find.text('Robo'));
        await tocar(tester, find.text('Enviar alerta'));
        esRegionEnVivoConIcono(
          'No pudimos enviar la alerta. Revisá tu conexión y probá de nuevo.',
        );
        handle.dispose();
      },
    );

    testWidgets('el formulario se lee en orden', (tester) async {
      final handle = tester.ensureSemantics();
      configurarPantalla(tester);
      await abrirReportarAlerta(tester);

      // Etiquetas (y tooltips) en el orden en que las recorre el lector.
      final leidas = <String>[];
      void recorrer(SemanticsNode nodo) {
        final datos = nodo.getSemanticsData();
        leidas.add('${datos.tooltip} ${datos.label}'.trim());
        for (final hijo in nodo.debugListChildrenInOrder(
          DebugSemanticsDumpOrder.traversalOrder,
        )) {
          recorrer(hijo);
        }
      }

      recorrer(
        tester
            .binding
            .renderViews
            .first
            .owner!
            .semanticsOwner!
            .rootSemanticsNode!,
      );

      int posicion(String texto) {
        final i = leidas.indexWhere((l) => l.contains(texto));
        expect(i, isNot(-1), reason: '"$texto" no se lee: $leidas');
        return i;
      }

      final orden = [
        'Cerrar',
        'Reportar alerta',
        'Actividad sospechosa',
        'Vehículo sospechoso',
        'Robo',
        'Ruidos',
        'Título',
        'Descripción (opcional)',
        'Vamos a mandar',
        'Dirección o referencia (opcional)',
        'Enviar alerta',
        'Cancelar',
      ].map(posicion).toList();
      expect(orden, [...orden]..sort());
      expect(orden.toSet(), hasLength(orden.length));
      handle.dispose();
    });

    testWidgets(
      'con el teclado abierto y el texto al 200 % se llega a "Enviar alerta" '
      'y se puede tocar',
      (tester) async {
        configurarPantalla(tester, alto: 640, escalaTexto: 2.0);
        await abrirReportarAlerta(tester);
        await tocar(tester, find.text('Ruidos'));
        await tocar(tester, find.widgetWithText(TextField, 'Título'));

        tester.view.viewInsets = const FakeViewPadding(bottom: 300 * 3);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await mostrar(tester, find.text('Enviar alerta'));
        expect(find.text('Enviar alerta').hitTestable(), findsOneWidget);
        await tester.tap(find.text('Enviar alerta'));
        // Al cerrarse el formulario el campo pierde el foco y el teclado
        // se va.
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();

        expect(find.text('¿Qué pasó?'), findsNothing);
        expect(
          find.text('Reportaste la alerta. Ya aparece en la lista y el mapa.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Estado de la alerta', () {
    testWidgets(
      'el control de estado tiene encabezado y cada opción se anuncia con su '
      'nombre y si está elegida',
      (tester) async {
        final handle = tester.ensureSemantics();
        configurarPantalla(tester);
        await abrirDetalleDeAlertaPropia(tester);
        await mostrar(tester, find.text('Estado de la alerta'));

        expect(
          tester
              .getSemantics(find.text('Estado de la alerta'))
              .getSemanticsData()
              .flagsCollection
              .isHeader,
          isTrue,
        );
        for (final etiqueta in ['Activa', 'En atención', 'Resuelta']) {
          final datos = tester
              .getSemantics(opcionDeEstado(etiqueta))
              .getSemanticsData();
          expect(datos.label, etiqueta);
          expect(datos.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
          expect(
            datos.flagsCollection.isChecked,
            etiqueta == 'Activa' ? CheckedState.isTrue : CheckedState.isFalse,
          );
        }
        handle.dispose();
      },
    );

    testWidgets('cada opción muestra el ícono y el nombre del estado', (
      tester,
    ) async {
      configurarPantalla(tester);
      await abrirDetalleSuelto(tester);

      for (final estado in EstadoAlerta.values) {
        final opcion = opcionDeEstado(estado.etiqueta);
        expect(opcion, findsOneWidget);
        expect(
          find.descendant(of: opcion, matching: find.byIcon(estado.icono)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: opcion, matching: find.text(estado.etiqueta)),
          findsOneWidget,
        );
      }
    });

    testWidgets(
      'el error de cambio de estado es una región en vivo con ícono',
      (tester) async {
        final handle = tester.ensureSemantics();
        configurarPantalla(tester);
        await abrirDetalleConErrorDeEstado(tester);

        final region = find.ancestor(
          of: find.text(errorDeEstadoSinConexion),
          matching: find.byWidgetPredicate(
            (w) => w is Semantics && (w.properties.liveRegion ?? false),
          ),
        );
        expect(region, findsOneWidget);
        expect(
          find.descendant(
            of: region,
            matching: find.byIcon(Icons.error_outline),
          ),
          findsOneWidget,
        );
        expect(
          tester
              .getSemantics(find.text(errorDeEstadoSinConexion))
              .getSemanticsData()
              .flagsCollection
              .isLiveRegion,
          isTrue,
        );
        handle.dispose();
      },
    );

    testWidgets('el indicador se anuncia "Cambiando el estado"', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      configurarPantalla(tester);
      final alertas = await abrirDetalleSuelto(tester);
      alertas.demoraAlCambiar = Completer<void>();

      await mostrar(tester, opcionDeEstado('En atención'));
      await tester.tap(opcionDeEstado('En atención'));
      await tester.pump();

      expect(
        tester
            .getSemantics(find.byType(CircularProgressIndicator))
            .getSemanticsData()
            .label,
        'Cambiando el estado',
      );

      alertas.demoraAlCambiar!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      handle.dispose();
    });

    testWidgets('el detalle se lee en orden', (tester) async {
      final handle = tester.ensureSemantics();
      configurarPantalla(tester);
      await abrirDetalleDeAlertaPropia(tester);

      final leidas = <String>[];
      void recorrer(SemanticsNode nodo) {
        final datos = nodo.getSemanticsData();
        leidas.add('${datos.tooltip} ${datos.label}'.trim());
        for (final hijo in nodo.debugListChildrenInOrder(
          DebugSemanticsDumpOrder.traversalOrder,
        )) {
          recorrer(hijo);
        }
      }

      recorrer(
        tester
            .binding
            .renderViews
            .first
            .owner!
            .semanticsOwner!
            .rootSemanticsNode!,
      );

      // Cada etiqueta se busca después de la anterior: "Activa" está dos
      // veces (el estado actual y la opción).
      var desde = 0;
      for (final texto in [
        'Activa',
        'Actividad sospechosa',
        'Reportada por',
        'Llamar al 911',
        'Estado de la alerta',
        'Activa',
        'En atención',
        'Resuelta',
        'Fue una falsa alarma',
      ]) {
        final i = leidas.indexWhere((l) => l.contains(texto), desde);
        expect(
          i,
          isNot(-1),
          reason: '"$texto" no se lee después de $desde: $leidas',
        );
        desde = i + 1;
      }
      handle.dispose();
    });

    testWidgets(
      'los diálogos de confirmación anuncian el título y cada botón por su '
      'texto',
      (tester) async {
        final handle = tester.ensureSemantics();
        configurarPantalla(tester);

        Future<void> revisar(String titulo, List<String> botones) async {
          expect(find.bySemanticsLabel(titulo), findsWidgets);
          final ruta = find.byWidgetPredicate(
            (w) =>
                w is Semantics &&
                (w.properties.namesRoute ?? false) &&
                (w.properties.scopesRoute ?? false) &&
                w.properties.label == titulo,
          );
          expect(ruta, findsOneWidget);
          for (final boton in botones) {
            final datos = tester
                .getSemantics(find.text(boton))
                .getSemanticsData();
            expect(datos.label, boton);
            expect(datos.flagsCollection.isButton, isTrue);
          }
        }

        await abrirConfirmarResuelta(tester);
        await revisar('¿Marcar la alerta como resuelta?', [
          'No, dejarla como está',
          'Sí, está resuelta',
        ]);

        await abrirConfirmarReabrir(tester);
        await revisar('¿Volver a abrir la alerta?', [
          'No, dejarla resuelta',
          'Sí, volver a abrirla',
        ]);
        handle.dispose();
      },
    );

    testWidgets(
      'al 200 % los botones del diálogo se apilan y miden al menos 48 dp de '
      'alto',
      (tester) async {
        configurarPantalla(tester, alto: 800, escalaTexto: 2.0);

        void revisar(String no, String si) {
          final botonNo = find.widgetWithText(OutlinedButton, no);
          final botonSi = find.widgetWithText(FilledButton, si);
          expect(tester.getSize(botonNo).height, greaterThanOrEqualTo(48));
          expect(tester.getSize(botonSi).height, greaterThanOrEqualTo(48));
          // Apilados: uno debajo del otro, no en la misma fila.
          final arribaNo = tester.getTopLeft(botonNo).dy;
          final arribaSi = tester.getTopLeft(botonSi).dy;
          expect((arribaNo - arribaSi).abs(), greaterThanOrEqualTo(48));
          expect(tester.takeException(), isNull);
        }

        await abrirConfirmarResuelta(tester);
        await mostrar(tester, find.text('Sí, está resuelta'));
        await mostrar(tester, find.text('No, dejarla como está'));
        revisar('No, dejarla como está', 'Sí, está resuelta');

        await abrirConfirmarReabrir(tester);
        await mostrar(tester, find.text('Sí, volver a abrirla'));
        await mostrar(tester, find.text('No, dejarla resuelta'));
        revisar('No, dejarla resuelta', 'Sí, volver a abrirla');
      },
    );
  });
}
