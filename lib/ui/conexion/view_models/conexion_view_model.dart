import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/conexion_repository.dart';
import '../../../data/services/bus_de_eventos.dart';
import '../../../domain/evento_de_app.dart';

/// Lo que sabe la app de su conexión con el servidor.
enum EstadoConexion {
  /// Todavía no terminó la primera comprobación.
  comprobando,
  conectado,
  sinConexion,
}

/// Decide cuándo comprobar la conexión y si hay que tapar la app.
///
/// - Comprueba al empezar y, mientras la app está en primer plano, cada
///   [revisarCada] con conexión o cada [reintentarCada] sin conexión.
/// - En segundo plano no comprueba; al volver, comprueba en el momento.
/// - También se entera de las comprobaciones que piden los repositorios
///   cuando un pedido falla por la red.
/// - Cuando vuelve la conexión avisa por el bus que las alertas y los
///   turnos pueden haber cambiado, así las pantallas se recargan solas.
class ConexionViewModel extends ChangeNotifier {
  ConexionViewModel({
    required this._conexion,
    required this._bus,
    this.revisarCada = const Duration(seconds: 30),
    this.reintentarCada = const Duration(seconds: 5),
  });

  final ConexionRepository _conexion;
  final BusDeEventos _bus;

  /// Cada cuánto se comprueba mientras hay conexión.
  final Duration revisarCada;

  /// Cada cuánto se vuelve a probar mientras no hay conexión.
  final Duration reintentarCada;

  EstadoConexion _estado = EstadoConexion.comprobando;
  EstadoConexion get estado => _estado;

  /// Si hay que mostrar la pantalla sin conexión.
  bool get sinConexion => _estado == EstadoConexion.sinConexion;

  Timer? _reloj;
  StreamSubscription<bool>? _cambios;
  bool _enPrimerPlano = true;
  bool _liberado = false;

  /// Primera comprobación y reloj periódico.
  void empezar() {
    _cambios ??= _conexion.cambios.listen(_aplicar);
    _enPrimerPlano = true;
    _comprobar();
    _programarReloj();
  }

  /// Corta las comprobaciones periódicas.
  void alPasarASegundoPlano() {
    _enPrimerPlano = false;
    _reloj?.cancel();
    _reloj = null;
  }

  /// Comprueba ya y vuelve a encender el reloj.
  void alVolverAPrimerPlano() {
    _enPrimerPlano = true;
    _comprobar();
    _programarReloj();
  }

  void _comprobar() {
    _conexion.comprobar().then(_aplicar);
  }

  void _aplicar(bool hayConexion) {
    if (_liberado) return;
    final nuevo = hayConexion
        ? EstadoConexion.conectado
        : EstadoConexion.sinConexion;
    if (nuevo == _estado) return;
    final volvio = _estado == EstadoConexion.sinConexion && hayConexion;
    _estado = nuevo;
    // Con otro estado cambia cada cuánto se comprueba.
    if (_enPrimerPlano) _programarReloj();
    if (volvio) {
      _bus.publicar(const AlertasActualizadas());
      _bus.publicar(const TurnosActualizados());
    }
    notifyListeners();
  }

  void _programarReloj() {
    _reloj?.cancel();
    final cada = sinConexion ? reintentarCada : revisarCada;
    _reloj = Timer.periodic(cada, (_) => _comprobar());
  }

  @override
  void dispose() {
    _liberado = true;
    _reloj?.cancel();
    _reloj = null;
    _cambios?.cancel();
    _cambios = null;
    super.dispose();
  }
}
