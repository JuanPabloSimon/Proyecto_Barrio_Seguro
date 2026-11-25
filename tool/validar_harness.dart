// Valida feature_list.json y la carpeta specs/. Lo ejecuta init.sh:
//
//     dart run tool/validar_harness.dart
//
// Está en Dart (y no en Python, como el proyecto de ejemplo) para que
// funcione en cualquier PC que tenga Flutter, sin instalar nada más.
//
// Sale con código 0 si todo está bien y con 1 si encuentra un problema.

import 'dart:convert';
import 'dart:io';

const estadosValidos = {
  'pending',
  'spec_ready',
  'in_progress',
  'done',
  'blocked',
};

/// Estados en los que una feature "sdd" ya tiene que tener su spec.
const estadosConSpec = {'spec_ready', 'in_progress', 'done'};

const archivosDelSpec = ['requirements.md', 'design.md', 'tasks.md'];

void main() {
  final errores = <String>[];

  final archivo = File('feature_list.json');
  if (!archivo.existsSync()) {
    _fallar(['No existe feature_list.json']);
  }

  final Map<String, dynamic> datos;
  try {
    datos = jsonDecode(archivo.readAsStringSync()) as Map<String, dynamic>;
  } catch (e) {
    _fallar(['feature_list.json no es un JSON válido: $e']);
  }

  final features = datos['features'];
  if (features is! List) {
    _fallar(['feature_list.json no tiene una lista "features"']);
  }

  final ids = <Object?>{};
  final nombres = <Object?>{};
  var enCurso = 0;

  for (final f in features) {
    if (f is! Map<String, dynamic>) {
      errores.add('Hay una feature que no es un objeto: $f');
      continue;
    }
    final id = f['id'];
    final nombre = f['name'];
    final estado = f['status'];
    final etiqueta = 'feature $id ($nombre)';

    if (id == null || nombre is! String || nombre.isEmpty) {
      errores.add('Toda feature necesita "id" y "name": $f');
      continue;
    }
    if (!ids.add(id)) errores.add('El id $id está repetido');
    if (!nombres.add(nombre)) errores.add('El name "$nombre" está repetido');

    if (!estadosValidos.contains(estado)) {
      errores.add('$etiqueta tiene un estado inválido: "$estado"');
      continue;
    }
    if (estado == 'in_progress') enCurso++;

    if (f['sdd'] == true && estadosConSpec.contains(estado)) {
      for (final nombreArchivo in archivosDelSpec) {
        final ruta = 'specs/$nombre/$nombreArchivo';
        if (!File(ruta).existsSync()) {
          errores.add('$etiqueta está en $estado y falta $ruta');
        }
      }
      if (estado == 'done') {
        final tasks = File('specs/$nombre/tasks.md');
        if (tasks.existsSync() &&
            RegExp(
              r'^\s*- \[ \]',
              multiLine: true,
            ).hasMatch(tasks.readAsStringSync())) {
          errores.add('$etiqueta está en done y tiene tasks sin marcar [x]');
        }
      }
    }
  }

  if (enCurso > 1) {
    errores.add('Hay $enCurso features en in_progress (el máximo es 1)');
  }

  if (errores.isNotEmpty) _fallar(errores);

  stdout.writeln(
    '[OK]    feature_list.json válido (${features.length} features)',
  );
  stdout.writeln(
    '[OK]    Specs presentes para las features sdd que ya no están en pending',
  );
}

Never _fallar(List<String> errores) {
  for (final e in errores) {
    stdout.writeln('[FAIL]  $e');
  }
  exit(1);
}
