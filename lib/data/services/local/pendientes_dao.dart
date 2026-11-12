import 'dart:convert';

import 'package:sqflite/sqflite.dart';

/// Una alerta que espera señal para enviarse.
typedef AlertaPendiente = ({int id, Map<String, dynamic> datos});

/// Las alertas creadas sin conexión, en orden de creación.
class PendientesDao {
  PendientesDao(this._db);

  final Database _db;

  static const tabla = 'alertas_pendientes';

  /// Guarda [datos] y devuelve el id local que le dio la base.
  Future<int> agregar(Map<String, dynamic> datos) =>
      _db.insert(tabla, {'datos': jsonEncode(datos)});

  Future<List<AlertaPendiente>> listar() async {
    final filas = await _db.query(tabla, orderBy: 'id');
    return [
      for (final fila in filas)
        (
          id: fila['id'] as int,
          datos: jsonDecode(fila['datos'] as String) as Map<String, dynamic>,
        ),
    ];
  }

  Future<void> borrar(int id) =>
      _db.delete(tabla, where: 'id = ?', whereArgs: [id]);
}
