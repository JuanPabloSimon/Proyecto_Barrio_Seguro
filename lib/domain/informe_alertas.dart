import 'avisos_tardios.dart';
import 'fechas.dart';
import 'models/alerta.dart';

/// Nombre de la fila de "Por tipo" que cuenta todas las alertas SOS, sea
/// cual sea su título.
const filaSosInforme = 'SOS';

/// Franjas del día para clasificar a qué hora ocurren las alertas en el
/// informe mensual.
enum FranjaInforme {
  madrugada('Madrugada (00:00 - 06:00)'),
  maniana('Mañana (06:00 - 12:00)'),
  tarde('Tarde (12:00 - 20:00)'),
  noche('Noche (20:00 - 00:00)');

  const FranjaInforme(this.etiqueta);

  final String etiqueta;

  /// Clasifica una hora del día (0 a 23) en su franja correspondiente.
  static FranjaInforme deHora(int hora) {
    if (hora < 6) return FranjaInforme.madrugada;
    if (hora < 12) return FranjaInforme.maniana;
    if (hora < 20) return FranjaInforme.tarde;
    return FranjaInforme.noche;
  }
}

/// Un renglón de una tabla del informe (nombre de la calle, tipo o franja y
/// cuántas alertas tuvo en el mes).
class FilaInforme {
  const FilaInforme({required this.nombre, required this.cantidad});

  final String nombre;
  final int cantidad;
}

/// Resumen mensual de alertas por calle, por tipo y por franja horaria, para
/// que la comisión vecinal presente al municipio.
class InformeAlertas {
  const InformeAlertas({
    required this.mes,
    required this.total,
    required this.porCalle,
    required this.porTipo,
    required this.porFranja,
  });

  /// Calcula el informe para el año y mes de [mes] a partir de [alertas].
  factory InformeAlertas.delMes({
    required List<Alerta> alertas,
    required DateTime mes,
  }) {
    final mesNormalizado = DateTime(mes.year, mes.month);
    final delMes = [
      for (final a in alertas)
        if (mismoMes(a.creadaEn, mesNormalizado)) a,
    ];

    if (delMes.isEmpty) {
      return InformeAlertas(
        mes: mesNormalizado,
        total: 0,
        porCalle: const [],
        porTipo: const [],
        porFranja: const [],
      );
    }

    final calles = <String, int>{};
    final tipos = <String, int>{};
    final franjas = <String, int>{};
    // Los SOS se cuentan aparte: una alerta de otra categoría nunca suma
    // acá, aunque se titule "SOS".
    var sos = 0;

    for (final alerta in delMes) {
      final calle = alerta.direccion.trim().isEmpty
          ? 'Sin calle indicada'
          : alerta.direccion.trim();
      final franja = FranjaInforme.deHora(alerta.creadaEn.hour).etiqueta;

      calles[calle] = (calles[calle] ?? 0) + 1;
      if (alerta.categoria == CategoriaAlerta.sos) {
        sos++;
      } else {
        final tipo = _nombreDeTipo(alerta);
        tipos[tipo] = (tipos[tipo] ?? 0) + 1;
      }
      franjas[franja] = (franjas[franja] ?? 0) + 1;
    }
    if (sos > 0) tipos[filaSosInforme] = sos;

    return InformeAlertas(
      mes: mesNormalizado,
      total: delMes.length,
      porCalle: _ordenar(calles),
      porTipo: _ordenar(tipos),
      porFranja: _ordenar(franjas),
    );
  }

  final DateTime mes;
  final int total;
  final List<FilaInforme> porCalle;
  final List<FilaInforme> porTipo;
  final List<FilaInforme> porFranja;

  /// True cuando no hubo ninguna alerta registrada en [mes].
  bool get sinAlertas => total == 0;

  /// Nombre de archivo sugerido para guardar el informe en CSV.
  String get nombreArchivoCsv {
    final mesTexto = mes.month.toString().padLeft(2, '0');
    return 'informe_alertas_${mes.year}_$mesTexto.csv';
  }

  /// Convierte el informe a formato CSV (con encabezado
  /// `Sección,Detalle,Cantidad`).
  String toCsv() {
    final buffer = StringBuffer()
      ..writeln('Sección,Detalle,Cantidad')
      ..writeln('Resumen,Total del mes,$total');
    for (final fila in porCalle) {
      buffer.writeln('Por calle,${_celdaCsv(fila.nombre)},${fila.cantidad}');
    }
    for (final fila in porTipo) {
      buffer.writeln('Por tipo,${_celdaCsv(fila.nombre)},${fila.cantidad}');
    }
    for (final fila in porFranja) {
      buffer.writeln(
        'Por franja horaria,${_celdaCsv(fila.nombre)},${fila.cantidad}',
      );
    }
    return buffer.toString();
  }

  /// El título tal cual ("Sin tipo" si está vacío). Si una alerta que no es
  /// SOS se titula "SOS", se le suma la categoría para que su fila no se
  /// confunda con la de los SOS.
  static String _nombreDeTipo(Alerta alerta) {
    final titulo = alerta.tipo.trim();
    if (titulo.isEmpty) return 'Sin tipo';
    if (titulo.toLowerCase() == filaSosInforme.toLowerCase()) {
      return '$titulo (${alerta.categoria.nombreCorto ?? 'otra categoría'})';
    }
    return titulo;
  }

  static List<FilaInforme> _ordenar(Map<String, int> conteos) {
    final filas = [
      for (final MapEntry(:key, :value) in conteos.entries)
        FilaInforme(nombre: key, cantidad: value),
    ];
    filas.sort((a, b) {
      final porCantidad = b.cantidad.compareTo(a.cantidad);
      return porCantidad != 0 ? porCantidad : a.nombre.compareTo(b.nombre);
    });
    return List.unmodifiable(filas);
  }

  static String _celdaCsv(String texto) {
    if (texto.contains(',') || texto.contains('"') || texto.contains('\n')) {
      return '"${texto.replaceAll('"', '""')}"';
    }
    return texto;
  }
}
