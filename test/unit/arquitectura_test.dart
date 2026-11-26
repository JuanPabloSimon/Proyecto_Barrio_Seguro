// Pruebas de la estructura del proyecto (feature estado_alerta, R56, R57 y
// R59): los ViewModels no dependen, ni siquiera de forma indirecta, de la
// capa visual de Flutter.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Directivas `import` y `export` de un archivo Dart. `\s+` admite el salto
/// de línea entre la palabra y la ruta.
final _directiva = RegExp(
  r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
  multiLine: true,
);

const _paqueteDelProyecto = 'package:barrio_seguro/';

/// Recorre [archivo] (ruta desde la raíz, p. ej. 'lib/ui/x.dart') y los
/// archivos de lib/ que importa o exporta (rutas relativas o
/// 'package:barrio_seguro/…'), sin entrar a paquetes externos ni repetir
/// archivos. Devuelve una entrada por cada import prohibido encontrado,
/// con la cadena desde [archivo]:
/// 'lib/ui/a/view_models/a_view_model.dart -> lib/ui/core/presentacion_alerta.dart -> package:flutter/material.dart'.
/// Prohibido: dart:ui y package:flutter/ salvo foundation.dart; con
/// [permitirFoundation] en false, también foundation.dart.
List<String> importsVisuales(String archivo, {bool permitirFoundation = true}) {
  final encontrados = <String>[];
  final visitados = <String>{};

  bool esProhibido(String ruta) {
    if (ruta == 'dart:ui' || ruta.startsWith('dart:ui_')) return true;
    if (!ruta.startsWith('package:flutter/')) return false;
    return !(permitirFoundation && ruta == 'package:flutter/foundation.dart');
  }

  void recorrer(String actual, List<String> cadena) {
    if (!visitados.add(actual)) return;
    final texto = File(actual).readAsStringSync();
    for (final coincidencia in _directiva.allMatches(texto)) {
      final ruta = coincidencia.group(1)!;
      if (esProhibido(ruta)) {
        encontrados.add([...cadena, ruta].join(' -> '));
        continue;
      }
      final String? delProyecto;
      if (ruta.startsWith(_paqueteDelProyecto)) {
        delProyecto = 'lib/${ruta.substring(_paqueteDelProyecto.length)}';
      } else if (!ruta.contains(':')) {
        delProyecto = Uri.parse(actual).resolve(ruta).path;
      } else {
        // dart:, package: de terceros: no se recorren.
        delProyecto = null;
      }
      if (delProyecto != null) {
        recorrer(delProyecto, [...cadena, delProyecto]);
      }
    }
  }

  recorrer(archivo, [archivo]);
  return encontrados;
}

/// Los `*.dart` de `lib/ui/*/view_models/`, con `/` como separador.
List<String> viewModels() {
  final archivos = <String>[];
  for (final entrada in Directory('lib/ui').listSync(recursive: true)) {
    final ruta = entrada.path.replaceAll(r'\', '/');
    final partes = ruta.split('/');
    if (entrada is File &&
        ruta.endsWith('.dart') &&
        partes.length == 5 &&
        partes[3] == 'view_models') {
      archivos.add(ruta);
    }
  }
  archivos.sort();
  return archivos;
}

void main() {
  group('MVVM: los ViewModels no dependen de la vista', () {
    test('ningún ViewModel llega a dart:ui ni a package:flutter fuera de '
        'foundation', () {
      final archivos = viewModels();
      expect(archivos, isNotEmpty);
      expect(
        archivos,
        contains(
          'lib/ui/alerta_detalle/view_models/detalle_alerta_view_model.dart',
        ),
      );
      final prohibidos = [for (final a in archivos) ...importsVisuales(a)];
      expect(
        prohibidos,
        isEmpty,
        reason:
            'Un ViewModel llega a una biblioteca visual de Flutter:\n'
            '${prohibidos.join('\n')}',
      );
    });

    test('textos_estado.dart no importa nada de Flutter', () {
      expect(
        importsVisuales(
          'lib/ui/core/textos_estado.dart',
          permitirFoundation: false,
        ),
        isEmpty,
      );
    });

    test('el chequeo encuentra material.dart en presentacion_alerta.dart', () {
      expect(
        importsVisuales('lib/ui/core/presentacion_alerta.dart'),
        contains(
          'lib/ui/core/presentacion_alerta.dart -> '
          'package:flutter/material.dart',
        ),
      );
    });

    test('el chequeo sigue los imports indirectos '
        '(chip_estado.dart -> presentacion_alerta.dart -> material.dart)', () {
      expect(
        importsVisuales('lib/ui/core/widgets/chip_estado.dart'),
        contains(
          'lib/ui/core/widgets/chip_estado.dart -> '
          'lib/ui/core/presentacion_alerta.dart -> '
          'package:flutter/material.dart',
        ),
      );
    });

    test('con foundation prohibido, el chequeo también la encuentra', () {
      expect(
        importsVisuales(
          'lib/ui/alerta_detalle/view_models/detalle_alerta_view_model.dart',
          permitirFoundation: false,
        ),
        contains(
          'lib/ui/alerta_detalle/view_models/detalle_alerta_view_model.dart '
          '-> package:flutter/foundation.dart',
        ),
      );
    });
  });
}
