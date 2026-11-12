// Técnica 2 del apunte: simular la plataforma para probar que las reglas de
// Capacidades y Politicas estén bien escritas.
//
// La web no se puede simular así: kIsWeb es una constante que se fija al
// compilar. Para eso habría que correr `flutter test --platform chrome`.

import 'package:barrio_seguro/plataforma/capacidades.dart';
import 'package:barrio_seguro/plataforma/politicas.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hace que defaultTargetPlatform devuelva [plataforma] durante la prueba y
/// la deja como estaba al terminar, aunque la prueba falle.
void simularPlataforma(TargetPlatform plataforma) {
  debugDefaultTargetPlatformOverride = plataforma;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
}

void main() {
  const capacidades = Capacidades();
  const politicas = Politicas();

  group('Capacidades', () {
    for (final plataforma in [TargetPlatform.android, TargetPlatform.iOS]) {
      test(
        'en ${plataforma.name} se puede llamar y recibir notificaciones',
        () {
          simularPlataforma(plataforma);
          expect(capacidades.puedeHacerLlamadas, isTrue);
          expect(capacidades.muestraNotificaciones, isTrue);
        },
      );
    }

    for (final plataforma in [
      TargetPlatform.windows,
      TargetPlatform.linux,
      TargetPlatform.macOS,
    ]) {
      test(
        'en ${plataforma.name} no se puede llamar ni recibir notificaciones',
        () {
          simularPlataforma(plataforma);
          expect(capacidades.puedeHacerLlamadas, isFalse);
          expect(capacidades.muestraNotificaciones, isFalse);
        },
      );
    }
  });

  group('Base de datos local', () {
    for (final plataforma in [
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
    ]) {
      test('en ${plataforma.name} hay sqflite', () {
        simularPlataforma(plataforma);
        expect(capacidades.tieneBaseDeDatosLocal, isTrue);
      });
    }

    for (final plataforma in [TargetPlatform.windows, TargetPlatform.linux]) {
      test('en ${plataforma.name} no hay sqflite', () {
        simularPlataforma(plataforma);
        expect(capacidades.tieneBaseDeDatosLocal, isFalse);
      });
    }
  });

  group('Políticas', () {
    test('en Android hay que avisar antes de compartir la ubicación', () {
      simularPlataforma(TargetPlatform.android);
      expect(politicas.exigeAvisoAntesDeUbicacion, isTrue);
    });

    test('en iOS el aviso lo da el diálogo del sistema', () {
      simularPlataforma(TargetPlatform.iOS);
      expect(politicas.exigeAvisoAntesDeUbicacion, isFalse);
    });
  });
}
