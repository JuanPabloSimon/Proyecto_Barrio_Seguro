import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/sesion_repository.dart';
import '../../../data/repositories/turnos_repository.dart';
import '../../../data/services/bus_de_eventos.dart';
import '../../../data/services/local/preferencias.dart';
import '../../../data/services/reloj.dart';
import '../../../domain/evento_de_app.dart';
import '../../../domain/models/turno.dart';
import '../../../domain/models/vecino.dart';
import '../../../domain/turno_incompleto.dart';
import '../../core/formato.dart';

/// Aviso de un turno incompleto, listo para mostrar.
class AvisoTurnoIncompleto {
  const AvisoTurnoIncompleto({
    required this.clave,
    required this.fecha,
    required this.titulo,
    required this.texto,
  });

  /// Arma los textos para [turno] según el lugar que [vecino] ocupa en él
  /// (patrullero o guardia de ventana), no según su edad ni su preferencia.
  factory AvisoTurnoIncompleto.de(Turno turno, Vecino vecino) {
    final f = turno.fecha;
    final fecha =
        '${nombreDia(f).toLowerCase()} ${f.day} de ${nombreMes(f.month)}';
    final siguiente = DateTime(f.year, f.month, f.day + 1);
    final cuando = turno.franja.empiezaAlDiaSiguiente
        ? '${turno.franja.horario} (la noche del ${f.day} al ${siguiente.day})'
        : turno.franja.horario;
    final esGuardia = ReglasTurnoIncompleto.esGuardiaVentanaEn(turno, vecino);
    return AvisoTurnoIncompleto(
      clave: ReglasTurnoIncompleto.claveDeCierre(vecino, turno),
      fecha: f,
      titulo: esGuardia
          ? 'Tu guardia de ventana no se va a hacer'
          : 'Tu guardia no se va a hacer',
      texto: esGuardia
          ? 'Nadie se anotó para patrullar en el turno del $fecha, $cuando. '
                'Sin patrulla, la guardia no se hace: no hace falta que '
                'vigiles desde tu ventana.'
          : 'Sos la única persona anotada en el turno del $fecha, $cuando. '
                'Con una sola persona, la guardia no se hace: no salgas a '
                'patrullar.',
    );
  }

  /// `ReglasTurnoIncompleto.claveDeCierre`: para cerrarlo y para saber si
  /// cambió la lista.
  final String clave;

  /// Fecha del turno, para ir a ese día en Turnos.
  final DateTime fecha;
  final String titulo;
  final String texto;

  /// Para el lector de pantalla: "`<titulo>. <texto>`".
  String get etiqueta => '$titulo. $texto';
}

/// El aviso de turno incompleto, compartido por el inicio y la pestaña
/// Turnos: un solo temporizador, un solo pedido y una sola lista de
/// cierres, así las dos pestañas muestran siempre lo mismo.
class TurnoIncompletoViewModel extends ChangeNotifier {
  TurnoIncompletoViewModel({
    required TurnosRepository turnos,
    required this._sesion,
    required BusDeEventos bus,
    required this._reloj,
    required this._preferencias,
    this.cadaCuantoRevisar = const Duration(minutes: 1),
  }) : _repositorio = turnos {
    // Anotarse o salir desde Turnos, o volver la conexión.
    _suscripcion = bus.de<TurnosActualizados>().listen((_) => cargar());
  }

  final TurnosRepository _repositorio;
  final SesionRepository _sesion;
  final Reloj _reloj;
  final Preferencias _preferencias;
  StreamSubscription<TurnosActualizados>? _suscripcion;
  Timer? _temporizador;

  /// Cada cuánto se recalculan los avisos con la app en primer plano.
  final Duration cadaCuantoRevisar;

  /// Últimos turnos obtenidos de los meses del aviso; null hasta el primer
  /// pedido que sale bien.
  List<Turno>? _turnosDelAviso;

  /// Claves de los avisos cerrados con "Entendido".
  Set<String> _cerrados = {};
  bool _cierresLeidos = false;

  bool _revisando = false;
  bool _liberado = false;

  List<AvisoTurnoIncompleto> _avisos = const [];

  /// Avisos visibles (candidatos menos cerrados), ordenados por inicio.
  /// Vacía si no hay ninguno o no hay sesión.
  List<AvisoTurnoIncompleto> get avisos => _avisos;

  /// Lee los cierres (la primera vez), pide los turnos de
  /// `mesesParaAvisar` sin refrescar y recalcula.
  Future<void> cargar() => _actualizar(refrescar: (_) => false);

  /// Vuelve a pedir los turnos (refrescando si el vecino tiene un turno en
  /// ventana) y recalcula. Notifica solo si cambiaron los avisos.
  Future<void> revisar() async {
    if (_revisando) return;
    _revisando = true;
    try {
      await _actualizar(
        refrescar: (ahora) {
          final u = _sesion.usuario;
          final turnos = _turnosDelAviso;
          return u != null &&
              turnos != null &&
              ReglasTurnoIncompleto.tieneTurnoEnVentana(
                turnos: turnos,
                vecino: u,
                ahora: ahora,
              );
        },
      );
    } finally {
      _revisando = false;
    }
  }

  Future<void> _actualizar({
    required bool Function(DateTime ahora) refrescar,
  }) async {
    await _leerCierres();
    final ahora = _reloj.ahora();
    if (_sesion.usuario != null) {
      await _pedirTurnos(ahora, refrescar: refrescar(ahora));
    }
    if (_liberado) return;
    // La hora puede haber cambiado mientras se esperaba la respuesta.
    _recalcular(_reloj.ahora());
  }

  Future<void> _leerCierres() async {
    if (_cierresLeidos) return;
    _cierresLeidos = true;
    try {
      _cerrados = {..._cerrados, ...await _preferencias.avisosTurnoCerrados()};
    } catch (_) {
      // Sin cierres guardados: a lo sumo reaparece un aviso.
    }
  }

  /// Si algún mes falla, se sigue con los últimos turnos obtenidos.
  Future<void> _pedirTurnos(DateTime ahora, {required bool refrescar}) async {
    try {
      final turnos = <Turno>[];
      for (final mes in ReglasTurnoIncompleto.mesesParaAvisar(ahora)) {
        turnos.addAll(
          await _repositorio.obtenerTurnos(mes, refrescar: refrescar),
        );
      }
      _turnosDelAviso = List.unmodifiable(turnos);
    } catch (_) {}
  }

  void _recalcular(DateTime ahora) {
    final u = _sesion.usuario;
    final turnos = _turnosDelAviso;
    if (u == null || turnos == null) {
      // Sin datos no se sabe qué cierres siguen vigentes: no se tocan.
      _publicar(const []);
      return;
    }
    final candidatos = ReglasTurnoIncompleto.paraAvisar(
      turnos: turnos,
      vecino: u,
      ahora: ahora,
    );
    final claves = {
      for (final t in candidatos) ReglasTurnoIncompleto.claveDeCierre(u, t),
    };
    // Un cierre vale mientras el turno siga siendo un candidato: si alguien
    // se anotó, el vecino salió o terminó la franja, se olvida.
    if (_cerrados.any((c) => !claves.contains(c))) {
      _cerrados = _cerrados.intersection(claves);
      unawaited(_guardarCierres());
    }
    _publicar([
      for (final t in candidatos)
        if (!_cerrados.contains(ReglasTurnoIncompleto.claveDeCierre(u, t)))
          AvisoTurnoIncompleto.de(t, u),
    ]);
  }

  /// Reemplaza los avisos y notifica solo si cambiaron.
  void _publicar(List<AvisoTurnoIncompleto> nuevos) {
    String firma(List<AvisoTurnoIncompleto> avisos) =>
        avisos.map((a) => '${a.clave}\n${a.titulo}\n${a.texto}').join('\n\n');
    if (firma(nuevos) == firma(_avisos)) return;
    _avisos = List.unmodifiable(nuevos);
    if (!_liberado) notifyListeners();
  }

  /// Si guardar falla, el estado en memoria ya es el correcto y se vuelve a
  /// guardar en el próximo cambio.
  Future<void> _guardarCierres() async {
    try {
      await _preferencias.guardarAvisosTurnoCerrados(_cerrados);
    } catch (_) {}
  }

  /// "Entendido": oculta ese aviso en todas las pestañas y lo guarda.
  Future<void> cerrar(AvisoTurnoIncompleto aviso) async {
    _cerrados = {..._cerrados, aviso.clave};
    _recalcular(_reloj.ahora());
    await _guardarCierres();
  }

  /// Arranca el `Timer.periodic` (reemplaza uno anterior).
  void empezarRevision() {
    _temporizador?.cancel();
    _temporizador = Timer.periodic(cadaCuantoRevisar, (_) => revisar());
  }

  /// Lo detiene (segundo plano). También lo llama `dispose`.
  void detenerRevision() {
    _temporizador?.cancel();
    _temporizador = null;
  }

  @override
  void dispose() {
    _liberado = true;
    detenerRevision();
    _suscripcion?.cancel();
    super.dispose();
  }
}
