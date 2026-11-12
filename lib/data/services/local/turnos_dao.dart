import 'package:sqflite/sqflite.dart';

import '../../../domain/models/turno.dart';

/// Todo el SQL de los turnos guardados.
class TurnosDao {
  TurnosDao(this._db);

  final Database _db;

  static const tabla = 'turnos';

  /// "2026-10-%": las fechas se guardan como "2026-10-09", así que todas las
  /// del mes empiezan igual.
  String _patronDelMes(DateTime mes) =>
      '${mes.year}-${mes.month.toString().padLeft(2, '0')}-%';

  Future<List<Turno>> delMes(DateTime mes) async {
    final filas = await _db.query(
      tabla,
      // El dato va aparte, en whereArgs; nunca pegado dentro del SQL.
      where: 'fecha LIKE ?',
      whereArgs: [_patronDelMes(mes)],
      orderBy: 'fecha',
    );
    return filas.map(Turno.fromMap).toList();
  }

  /// Reemplaza los turnos guardados de ese mes por los del servidor.
  Future<void> reemplazarMes(DateTime mes, List<Turno> turnos) {
    return _db.transaction((txn) async {
      await txn.delete(
        tabla,
        where: 'fecha LIKE ?',
        whereArgs: [_patronDelMes(mes)],
      );
      final lote = txn.batch();
      for (final turno in turnos) {
        lote.insert(tabla, turno.toMap());
      }
      await lote.commit(noResult: true);
    });
  }

  /// Agrega el turno o lo actualiza si ya estaba (mismo día y franja).
  Future<void> guardar(Turno turno) {
    return _db.insert(
      tabla,
      turno.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
