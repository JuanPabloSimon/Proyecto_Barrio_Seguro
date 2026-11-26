import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/alertas_repository.dart';
import '../../../data/services/bus_de_eventos.dart';
import '../../../data/services/descarga_csv_service.dart';
import '../../../data/services/reloj.dart';
import '../../../domain/evento_de_app.dart';
import '../../../domain/informe_alertas.dart';
import '../../../domain/models/alerta.dart';
import '../../core/estado_carga.dart';

class InformeAlertasViewModel extends ChangeNotifier {
  InformeAlertasViewModel({
    required this._alertas,
    required BusDeEventos bus,
    required Reloj reloj,
    this._descargaCsv = const DescargaCsvServiceLocal(),
    DateTime? mesInicial,
  }) : _mes = DateTime(
         (mesInicial ?? reloj.ahora()).year,
         (mesInicial ?? reloj.ahora()).month,
       ) {
    _informe = InformeAlertas.delMes(alertas: const [], mes: _mes);
    _suscripcion = bus.de<AlertasActualizadas>().listen((_) => cargar());
  }

  final AlertasRepository _alertas;
  final DescargaCsvService _descargaCsv;
  StreamSubscription<AlertasActualizadas>? _suscripcion;

  EstadoCarga _estado = EstadoCarga.inicial;
  EstadoCarga get estado => _estado;

  /// True si no hubo conexión y el informe se armó con la copia local.
  bool get sinConexion => _alertas.sinConexion;

  DateTime _mes;
  DateTime get mes => _mes;

  List<Alerta> _todas = const [];
  late InformeAlertas _informe;
  InformeAlertas get informe => _informe;

  Future<void> cargar() async {
    if (_estado != EstadoCarga.exito) {
      _estado = EstadoCarga.cargando;
      notifyListeners();
    }
    try {
      _todas = await _alertas.obtenerAlertas();
      _informe = InformeAlertas.delMes(alertas: _todas, mes: _mes);
      _estado = EstadoCarga.exito;
    } catch (_) {
      if (_estado != EstadoCarga.exito) _estado = EstadoCarga.error;
    } finally {
      notifyListeners();
    }
  }

  void elegirMes(DateTime nuevoMes) {
    final normalizado = DateTime(nuevoMes.year, nuevoMes.month);
    if (normalizado == _mes) return;
    _mes = normalizado;
    _informe = InformeAlertas.delMes(alertas: _todas, mes: _mes);
    notifyListeners();
  }

  void mesAnterior() => elegirMes(DateTime(_mes.year, _mes.month - 1));

  void mesSiguiente() => elegirMes(DateTime(_mes.year, _mes.month + 1));

  /// Genera y guarda el archivo CSV del mes actual y devuelve el mensaje
  /// para mostrarle al miembro de la comisión.
  Future<String> descargarCsv() async {
    try {
      final ruta = await _descargaCsv.guardarCsv(
        nombreArchivo: _informe.nombreArchivoCsv,
        contenido: _informe.toCsv(),
      );
      if (ruta == null) {
        return 'No pudimos descargar el informe. Probá de nuevo.';
      }
      return 'Informe descargado: ${_informe.nombreArchivoCsv}';
    } catch (_) {
      return 'No pudimos descargar el informe. Probá de nuevo.';
    }
  }

  @override
  void dispose() {
    _suscripcion?.cancel();
    super.dispose();
  }
}
