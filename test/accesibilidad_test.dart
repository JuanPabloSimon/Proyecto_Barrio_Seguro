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

import 'package:BarrioSeguro/data/barrio.dart';
import 'package:BarrioSeguro/data/datos_demo.dart';
import 'package:BarrioSeguro/data/sesion.dart';
import 'package:BarrioSeguro/data/turnos_repositorio.dart';
import 'package:BarrioSeguro/main.dart';
import 'package:BarrioSeguro/theme/app_colors.dart';
import 'package:BarrioSeguro/theme/transiciones.dart';
import 'package:BarrioSeguro/widgets/boton_sos.dart';
import 'package:BarrioSeguro/widgets/mapa_barrio.dart';
import 'package:BarrioSeguro/widgets/tarjeta_alerta.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

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

/// Cada test arranca con el usuario y los turnos de ejemplo. El mapa se
/// dibuja sin descargar calles, para no depender de internet.
void reiniciarDatos() {
  MapaBarrio.cargarCalles = false;
  Sesion.reiniciar();
  turnosRepositorio.reiniciar();
}

Future<void> abrirApp(WidgetTester tester) async {
  await tester.pumpWidget(const BarrioSeguroApp());
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
          (widget) => widget is Scrollable && widget.axisDirection == AxisDirection.down,
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

Future<void> ingresar(WidgetTester tester) async {
  await abrirApp(tester);
  await tocar(tester, find.text('Ingresar'));
}

Future<void> irAPestania(WidgetTester tester, String pestania) async {
  await ingresar(tester);
  await tocar(
    tester,
    find.descendant(of: find.byType(NavigationBar), matching: find.text(pestania)),
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
    expect(find.text('Vas a participar como guardia de ventana'), findsOneWidget);
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
    await tocar(tester, find.bySemanticsLabel(RegExp('^Alerta: Arrebato')));
    expect(find.text('Ver detalle'), findsOneWidget);
  }),
  Pantalla('Perfil', (tester) => irAPestania(tester, 'Perfil')),
  Pantalla('Editar datos', (tester) async {
    await irAPestania(tester, 'Perfil');
    await tocar(tester, find.text('Editar datos personales'));
  }),
  Pantalla('Mis alertas', (tester) async {
    await irAPestania(tester, 'Perfil');
    await tocar(tester, find.text('Mis alertas reportadas'));
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
  }),
];

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUp(reiniciarDatos);

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
    test('Todos los pares de AppColors cumplen el contraste mínimo', () {
      for (final par in AppColors.paresDeContraste) {
        expect(
          par.ratio,
          greaterThanOrEqualTo(par.minimo),
          reason: '${par.descripcion}: ${par.ratio.toStringAsFixed(2)}:1, '
              'mínimo ${par.minimo}:1',
        );
      }
    });
  });

  group('Barrio', () {
    test('Todas las alertas de ejemplo están dentro del radio de alertas', () {
      for (final alerta in alertasDemo) {
        expect(
          Barrio.estaDentroDelRadio(alerta.ubicacion),
          isTrue,
          reason: '${alerta.tipo} está a '
              '${Barrio.distanciaAlCentro(alerta.ubicacion).round()} m del centro',
        );
      }
    });
  });

  group('Movimiento', () {
    testWidgets('Con "Quitar animaciones" la transición no anima', (tester) async {
      const pantallaNueva = SizedBox(key: Key('nueva'));
      late Widget resultado;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              resultado = const TransicionAccesible(ZoomPageTransitionsBuilder())
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
    testWidgets('Un toque pide confirmación y no envía la alerta', (tester) async {
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
  });
}
