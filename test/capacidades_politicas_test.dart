// Técnica 1 del apunte: la app recibe capacidades y políticas falsas, y se
// prueban los dos caminos de cada pantalla sin tener el dispositivo a mano.

import 'package:BarrioSeguro/data/services/ubicacion_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ayudas/app_de_prueba.dart';
import 'ayudas/falsos.dart';

Future<void> abrir(WidgetTester tester, Widget app) async {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = const Size(360 * 3, 1600 * 3);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ingresar'));
  await tester.pumpAndSettle();
}

Future<void> tocar(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> irAlPerfil(WidgetTester tester, Widget app) async {
  await abrir(tester, app);
  await tocar(
    tester,
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Perfil'),
    ),
  );
}

final interruptorUbicacion = find.widgetWithText(
  SwitchListTile,
  'Compartir ubicación exacta en alertas',
);

bool encendido(WidgetTester tester, Finder interruptor) =>
    tester.widget<SwitchListTile>(interruptor).value;

void main() {
  group('Llamar al 911', () {
    testWidgets('si puede llamar, abre el teléfono con el 911', (tester) async {
      final telefono = TelefonoFalso();
      await abrir(tester, appDePrueba(telefono: telefono));

      await tocar(tester, find.text('Llamar al 911'));
      await tocar(tester, find.text('Llamar'));

      expect(telefono.marcados, ['911']);
    });

    testWidgets('si el teléfono no se abre, pide marcar a mano', (
      tester,
    ) async {
      await abrir(tester, appDePrueba(telefono: TelefonoFalso(abre: false)));

      await tocar(tester, find.text('Llamar al 911'));
      await tocar(tester, find.text('Llamar'));

      expect(
        find.text('No pudimos abrir el teléfono. Marcá 911 a mano.'),
        findsOneWidget,
      );
    });

    testWidgets('si no puede llamar, explica que use otro teléfono', (
      tester,
    ) async {
      final telefono = TelefonoFalso();
      await abrir(
        tester,
        appDePrueba(
          capacidades: const CapacidadesFalsas(puedeHacerLlamadas: false),
          telefono: telefono,
        ),
      );

      await tocar(tester, find.text('Llamar al 911'));

      expect(find.text('Llamá al 911 desde un teléfono'), findsOneWidget);
      expect(find.text('Llamar'), findsNothing);
      await tocar(tester, find.text('Entendido'));
      expect(telefono.marcados, isEmpty);
    });
  });

  group('Compartir ubicación', () {
    testWidgets(
      'con la política de aviso, primero explica y deja decir que no',
      (tester) async {
        await irAlPerfil(tester, appDePrueba());
        expect(encendido(tester, interruptorUbicacion), isFalse);

        await tocar(tester, interruptorUbicacion);
        expect(find.text('¿Compartir tu ubicación exacta?'), findsOneWidget);

        await tocar(tester, find.text('Ahora no'));
        expect(encendido(tester, interruptorUbicacion), isFalse);

        await tocar(tester, interruptorUbicacion);
        await tocar(tester, find.text('Compartir ubicación'));
        expect(encendido(tester, interruptorUbicacion), isTrue);
      },
    );

    testWidgets('sin la política de aviso, se activa directamente', (
      tester,
    ) async {
      await irAlPerfil(
        tester,
        appDePrueba(
          politicas: const PoliticasFalsas(exigeAvisoAntesDeUbicacion: false),
        ),
      );

      await tocar(tester, interruptorUbicacion);

      expect(find.text('¿Compartir tu ubicación exacta?'), findsNothing);
      expect(encendido(tester, interruptorUbicacion), isTrue);
    });

    testWidgets('para apagarla no hace falta el aviso', (tester) async {
      await irAlPerfil(tester, appDePrueba());
      await tocar(tester, interruptorUbicacion);
      await tocar(tester, find.text('Compartir ubicación'));

      await tocar(tester, interruptorUbicacion);

      expect(find.text('¿Compartir tu ubicación exacta?'), findsNothing);
      expect(encendido(tester, interruptorUbicacion), isFalse);
    });
  });

  group('Permiso de ubicación del sistema', () {
    testWidgets('si el vecino no da el permiso, queda apagada y se explica', (
      tester,
    ) async {
      await irAlPerfil(
        tester,
        appDePrueba(
          politicas: const PoliticasFalsas(exigeAvisoAntesDeUbicacion: false),
          ubicacion: UbicacionFalsa(permiso: PermisoUbicacion.denegado),
        ),
      );

      await tocar(tester, interruptorUbicacion);

      expect(encendido(tester, interruptorUbicacion), isFalse);
      expect(
        find.textContaining('Sin el permiso de ubicación'),
        findsOneWidget,
      );
    });

    testWidgets('con el permiso bloqueado aparece el botón de ajustes', (
      tester,
    ) async {
      final gps = UbicacionFalsa(permiso: PermisoUbicacion.denegadoParaSiempre);
      await irAlPerfil(
        tester,
        appDePrueba(
          politicas: const PoliticasFalsas(exigeAvisoAntesDeUbicacion: false),
          ubicacion: gps,
        ),
      );

      await tocar(tester, interruptorUbicacion);
      await tocar(tester, find.text('Abrir los ajustes del teléfono'));

      expect(gps.ajustesAbiertos, 1);
    });

    testWidgets('sin GPS, el interruptor se desactiva', (tester) async {
      await irAlPerfil(
        tester,
        appDePrueba(capacidades: const CapacidadesFalsas(tieneGps: false)),
      );

      final widget = tester.widget<SwitchListTile>(interruptorUbicacion);
      expect(widget.onChanged, isNull);
      expect(find.textContaining('no tiene GPS'), findsOneWidget);
    });
  });

  group('Notificaciones', () {
    final interruptor = find.widgetWithText(
      SwitchListTile,
      'Notificaciones push',
    );

    testWidgets(
      'si el dispositivo no las recibe, el interruptor se desactiva',
      (tester) async {
        await irAlPerfil(
          tester,
          appDePrueba(
            capacidades: const CapacidadesFalsas(
              recibeNotificacionesPush: false,
            ),
          ),
        );

        final widget = tester.widget<SwitchListTile>(interruptor);
        expect(widget.onChanged, isNull);
        expect(widget.value, isFalse);
        expect(
          find.textContaining('Este dispositivo no recibe notificaciones'),
          findsOneWidget,
        );
      },
    );

    testWidgets('si las recibe, se pueden apagar', (tester) async {
      await irAlPerfil(tester, appDePrueba());
      expect(encendido(tester, interruptor), isTrue);

      await tocar(tester, interruptor);

      expect(encendido(tester, interruptor), isFalse);
    });
  });
}
