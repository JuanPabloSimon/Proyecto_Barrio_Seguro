import 'dart:io';

import 'package:path/path.dart' as p;

/// Guarda en el dispositivo un archivo CSV generado por la app.
abstract class DescargaCsvService {
  /// Guarda [contenido] bajo [nombreArchivo] y devuelve la ruta o nombre
  /// donde quedó guardado, o null si no se pudo guardar.
  Future<String?> guardarCsv({
    required String nombreArchivo,
    required String contenido,
  });
}

/// Guarda el archivo CSV en [carpetaDestino], en la carpeta de descargas de
/// Android (si existe y permite escritura) o en la carpeta temporal del
/// sistema.
///
/// Agrega la marca BOM UTF-8 (`\uFEFF`) al principio para que las planillas
/// de cálculo abran bien los acentos y la ñ.
class DescargaCsvServiceLocal implements DescargaCsvService {
  const DescargaCsvServiceLocal({this.carpetaDestino});

  final Directory? carpetaDestino;

  @override
  Future<String?> guardarCsv({
    required String nombreArchivo,
    required String contenido,
  }) async {
    final textoConBom = '\uFEFF$contenido';
    for (final carpeta in _candidatas()) {
      try {
        if (await carpeta.exists()) {
          final archivo = File(p.join(carpeta.path, nombreArchivo));
          await archivo.writeAsString(textoConBom, flush: true);
          return archivo.path;
        }
      } catch (_) {}
    }
    return null;
  }

  List<Directory> _candidatas() => [
    ?carpetaDestino,
    Directory('/storage/emulated/0/Download'),
    Directory.systemTemp,
  ];
}
