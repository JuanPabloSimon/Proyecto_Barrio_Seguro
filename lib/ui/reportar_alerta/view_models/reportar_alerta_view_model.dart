import 'package:flutter/foundation.dart';

import '../../../data/repositories/alertas_repository.dart';
import '../../../data/repositories/sesion_repository.dart';
import '../../../data/services/bus_de_eventos.dart';
import '../../../data/services/error_del_servidor.dart';
import '../../../domain/avisos_tardios.dart';
import '../../../domain/barrio.dart';
import '../../../domain/evento_de_app.dart';
import '../../../domain/models/alerta.dart';
import '../../../domain/reglas_alertas.dart';
import '../../core/ubicacion_de_alerta.dart';

/// Los elementos del formulario que pueden tener un error, en el orden en
/// que se leen (y en que se busca el primero con error).
enum CampoReporte { tipo, titulo, descripcion, direccion }

/// Aviso que se muestra en el inicio al crear la alerta.
const mensajeAlertaReportada =
    'Reportaste la alerta. Ya aparece en la lista y el mapa.';

/// Error de envío cuando falla la red.
const mensajeSinConexionAlReportar =
    'No pudimos enviar la alerta. Revisá tu conexión y probá de nuevo.';

/// ViewModel del formulario "Reportar alerta". Los textos viven en los
/// controladores de la pantalla y llegan como parámetros; acá queda el
/// tipo elegido, los errores y el envío.
class ReportarAlertaViewModel extends ChangeNotifier {
  ReportarAlertaViewModel({
    required AlertasRepository alertas,
    required this._sesion,
    required this._bus,
    required this._ubicacion,
  }) : _repositorio = alertas;

  final AlertasRepository _repositorio;
  final SesionRepository _sesion;
  final BusDeEventos _bus;
  final UbicacionDeAlerta _ubicacion;

  bool _liberado = false;

  List<CategoriaAlerta> get tipos => CategoriaAlerta.paraReportar;

  CategoriaAlerta? _tipo;
  CategoriaAlerta? get tipo => _tipo;

  /// Elige [nuevo] y devuelve el título que tiene que quedar en el campo:
  /// el nombre del tipo si [tituloActual] está vacío o es la sugerencia del
  /// tipo anterior; si no, [tituloActual] (R8, R9).
  String tituloAlElegir(CategoriaAlerta nuevo, {required String tituloActual}) {
    final sugerenciaAnterior = _tipo?.nombreCorto;
    final actual = tituloActual.trim();
    _tipo = nuevo;
    // Con un tipo elegido, el aviso "Elegí qué tipo de alerta es." ya no
    // es cierto.
    _errores.remove(CampoReporte.tipo);
    notifyListeners();
    if (actual.isEmpty || actual == sugerenciaAnterior) {
      return nuevo.nombreCorto ?? tituloActual;
    }
    return tituloActual;
  }

  bool _conUbicacionExacta = false;

  /// R11/R12. False hasta que [cargar] responde.
  bool get conUbicacionExacta => _conUbicacionExacta;

  /// Pregunta si la alerta va a llevar la posición del GPS, para decírselo
  /// al vecino antes de enviar.
  Future<void> cargar() async {
    final exacta = await _ubicacion.compartePosicionExacta();
    if (_liberado) return;
    _conUbicacionExacta = exacta;
    notifyListeners();
  }

  bool _enviando = false;
  bool get enviando => _enviando;

  final Map<CampoReporte, String> _errores = {};

  String? errorDe(CampoReporte campo) => _errores[campo];

  /// El primero con error, en el orden de [CampoReporte] (R29).
  CampoReporte? get primerError {
    for (final campo in CampoReporte.values) {
      if (_errores.containsKey(campo)) return campo;
    }
    return null;
  }

  String? _errorDeEnvio;

  /// R32/R33. null si no hubo error de envío.
  String? get errorDeEnvio => _errorDeEnvio;

  /// True si hay tipo elegido o algún texto (sin contar espacios) (R36,
  /// R37).
  bool hayDatos({
    required String titulo,
    required String descripcion,
    required String direccion,
  }) =>
      _tipo != null ||
      titulo.trim().isNotEmpty ||
      descripcion.trim().isNotEmpty ||
      direccion.trim().isNotEmpty;

  /// Valida; si todo está bien, crea la alerta y publica
  /// [AlertasActualizadas]. Devuelve true si se creó. Nunca borra el tipo.
  Future<bool> enviar({
    required String titulo,
    required String descripcion,
    required String direccion,
  }) async {
    if (_enviando) return false;
    _errorDeEnvio = null;
    _errores
      ..clear()
      ..addAll({
        if (_tipo == null) CampoReporte.tipo: ReglasAlertas.mensajeCategoria,
        CampoReporte.titulo: ?ReglasAlertas.errorTitulo(titulo),
        CampoReporte.descripcion: ?ReglasAlertas.errorDescripcion(descripcion),
        CampoReporte.direccion: ?ReglasAlertas.errorDireccion(direccion),
      });
    final tipo = _tipo;
    if (_errores.isNotEmpty || tipo == null) {
      notifyListeners();
      return false;
    }

    _enviando = true;
    notifyListeners();
    try {
      final exacta = await _ubicacion.posicionExacta();
      final escrita = direccion.trim();
      await _repositorio.crearAlerta(
        categoria: tipo,
        tipo: titulo.trim(),
        descripcion: descripcion.trim(),
        direccion: escrita.isNotEmpty
            ? escrita
            : (exacta == null ? direccionZona : direccionExacta),
        ubicacion: exacta ?? Barrio.centro,
        reportadaPor: _sesion.usuario?.id ?? '',
      );
      _bus.publicar(const AlertasActualizadas());
      return true;
    } on ErrorDelServidor catch (e) {
      _errorDeEnvio = e.mensaje;
      return false;
    } catch (_) {
      _errorDeEnvio = mensajeSinConexionAlReportar;
      return false;
    } finally {
      _enviando = false;
      if (!_liberado) notifyListeners();
    }
  }

  @override
  void dispose() {
    _liberado = true;
    super.dispose();
  }
}
