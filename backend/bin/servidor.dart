import 'dart:io';

import 'package:barrio_seguro_backend/barrio_seguro_backend.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';

/// Arranca la API.
///
/// Variables de entorno (todas opcionales):
/// - PORT: puerto, 8080 por defecto.
/// - DATOS: archivo donde se guardan los datos, `datos/barrio.json`.
/// - CODIGO_COMISION: código para registrarse, `SOBERANIA` por defecto.
Future<void> main() async {
  final entorno = Platform.environment;
  final puerto = int.tryParse(entorno['PORT'] ?? '') ?? 8080;
  const reloj = RelojDelSistema();

  final api = Api(
    almacen: Almacen.abrir(
      archivo: File(entorno['DATOS'] ?? 'datos/barrio.json'),
      reloj: reloj,
    ),
    reloj: reloj,
    codigoComision: entorno['CODIGO_COMISION'] ?? 'SOBERANIA',
  );

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler(api.handler);

  // anyIPv4: así también lo encuentra un celular conectado a la misma red.
  final servidor = await serve(handler, InternetAddress.anyIPv4, puerto);
  stdout.writeln(
    'Barrio Seguro API escuchando en http://localhost:${servidor.port}',
  );
}
