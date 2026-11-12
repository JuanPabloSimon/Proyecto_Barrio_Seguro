import 'package:path/path.dart';

import 'package:sqflite/sqflite.dart';

export 'package:sqflite/sqflite.dart' show Database;

/// Nombre del archivo de la base dentro de la carpeta de bases del
/// dispositivo.
const nombreArchivoBase = 'barrio_seguro.db';

/// Versión del esquema (la "forma" de las tablas). Cada vez que cambia la
/// estructura de una tabla, este número sube y hay que agregar la
/// migración en `onUpgrade`.
const versionDelEsquema = 1;

/// Copia local de las alertas, para verlas sin conexión. Mismas columnas
/// que el JSON de la API. La fecha va en milisegundos (SQLite no tiene
/// fechas).
const sqlCrearAlertas = '''
CREATE TABLE alertas (
  id TEXT PRIMARY KEY,
  categoria TEXT NOT NULL,
  tipo TEXT NOT NULL,
  descripcion TEXT NOT NULL,
  direccion TEXT NOT NULL,
  creada_en INTEGER NOT NULL,
  estado TEXT NOT NULL,
  latitud REAL NOT NULL,
  longitud REAL NOT NULL,
  reportada_por TEXT NOT NULL
)
''';

/// Copia local de los turnos. Un turno es un día más una franja: esa es su
/// clave. Los vecinos van en JSON (ver `Turno.toMap`).
const sqlCrearTurnos = '''
CREATE TABLE turnos (
  fecha TEXT NOT NULL,
  franja TEXT NOT NULL,
  patrulleros TEXT NOT NULL,
  guardia_ventana TEXT,
  PRIMARY KEY (fecha, franja)
)
''';

/// Abre (o crea, si no existe) la base en [ruta].
///
/// Recibe la [fabrica] por parámetro: la app usa la del dispositivo y las
/// pruebas una base en memoria (`databaseFactoryFfi`), sin tocar nada más.
Future<Database> abrirBaseDeDatos(DatabaseFactory fabrica, String ruta) {
  return fabrica.openDatabase(
    ruta,
    options: OpenDatabaseOptions(
      version: versionDelEsquema,
      // onCreate corre UNA sola vez: cuando el archivo no existía.
      onCreate: (db, version) async {
        await db.execute(sqlCrearAlertas);
        await db.execute(sqlCrearTurnos);
      },
    ),
  );
}

/// La base del dispositivo, con el plugin de sqflite.
Future<Database> abrirBaseDelDispositivo() async {
  final ruta = join(
    await databaseFactory.getDatabasesPath(),
    nombreArchivoBase,
  );
  return abrirBaseDeDatos(databaseFactory, ruta);
}
