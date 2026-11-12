// Test básico de arranque.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ayudas/app_de_prueba.dart';

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
}
