import 'package:BarrioSeguro/data/services/local/almacen_seguro.dart';
import 'package:BarrioSeguro/data/services/local/base_de_datos.dart';
import 'package:BarrioSeguro/data/services/local/preferencias.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Abre una base SQLite NUEVA en memoria con las tablas de la app.
///
/// Corre en la PC (FFI), sin emulador. Cada llamada devuelve una base
/// vacía e independiente: una prueba no ve los datos de otra.
Future<Database> baseEnMemoria() {
  sqfliteFfiInit();
  return databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: versionDelEsquema,
      singleInstance: false,
      onCreate: (db, version) async {
        await db.execute(sqlCrearAlertas);
        await db.execute(sqlCrearTurnos);
        await db.execute(sqlCrearPendientes);
      },
    ),
  );
}

/// Reemplaza el almacenamiento real de shared_preferences por uno en
/// memoria, vacío (o con [datos]). Devuelve las Preferencias de la app
/// sobre ese almacenamiento.
Preferencias preferenciasEnMemoria([Map<String, Object> datos = const {}]) {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.withData(datos);
  return Preferencias(SharedPreferencesAsync());
}

/// El almacenamiento seguro, en memoria. flutter_secure_storage trae esta
/// versión de prueba: no usa el llavero del sistema.
AlmacenSeguro almacenSeguroEnMemoria([Map<String, String> valores = const {}]) {
  FlutterSecureStorage.setMockInitialValues(Map.of(valores));
  return AlmacenSeguro(const FlutterSecureStorage());
}
