import 'package:sqflite/sqflite.dart';

import '../../../domain/models/alerta.dart';

/// Todo el SQL de las alertas guardadas. Ninguna pantalla ni ViewModel
/// escribe SQL.
class AlertasDao {
  AlertasDao(this._db);

  final Database _db;

  static const tabla = 'alertas';

  /// Todas, de la más nueva a la más vieja.
  Future<List<Alerta>> listar() async {
    final filas = await _db.query(tabla, orderBy: 'creada_en DESC');
    return filas.map(Alerta.fromMap).toList();
  }

  /// Reemplaza la copia local por [alertas], la lista que mandó el
  /// servidor. En una transacción: si algo falla, queda la copia anterior.
  Future<void> reemplazarTodas(List<Alerta> alertas) {
    return _db.transaction((txn) async {
      await txn.delete(tabla);
      final lote = txn.batch();
      for (final alerta in alertas) {
        lote.insert(tabla, alerta.toMap());
      }
      await lote.commit(noResult: true);
    });
  }

  /// Agrega la alerta o, si ya estaba (mismo id), la actualiza.
  Future<void> guardar(Alerta alerta) {
    return _db.insert(
      tabla,
      alerta.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
