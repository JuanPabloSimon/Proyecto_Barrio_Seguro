// Tests de arranque y del informe mensual de alertas para la comisión.

import 'package:barrio_seguro/ui/core/widgets/con_view_model.dart';
import 'package:barrio_seguro/ui/perfil/view_models/perfil_view_model.dart';
import 'package:barrio_seguro/ui/perfil/widgets/perfil_screen.dart';
import 'package:barrio_seguro/dependencias.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ayudas/app_de_prueba.dart';
import 'ayudas/bases_de_prueba.dart';
import 'ayudas/falsos.dart';

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
