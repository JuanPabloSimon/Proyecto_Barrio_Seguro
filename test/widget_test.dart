// Test básico de arranque: reemplaza al test del contador de la plantilla.

import 'package:BarrioSeguro/data/sesion.dart';
import 'package:BarrioSeguro/data/turnos_repositorio.dart';
import 'package:BarrioSeguro/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    Sesion.reiniciar();
    turnosRepositorio.reiniciar();
  });

  testWidgets('La app abre en el login y entra al inicio', (tester) async {
    await tester.pumpWidget(const BarrioSeguroApp());
    await tester.pumpAndSettle();

    expect(find.text('Barrio Seguro'), findsOneWidget);

    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();

    expect(find.text('Hola, Clara'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
