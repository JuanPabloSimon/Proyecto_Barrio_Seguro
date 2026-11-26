import '../services/local/preferencias.dart';
import '../services/reloj.dart';

/// Cuándo le llegó a este teléfono el aviso de cada alerta, en hora del
/// servidor. Lo usan el push (en su isolate), el vigilante y las pantallas.
abstract class AvisosRecibidosRepository {
  /// Guarda ahora + desfase si no había llegada para [alertaId]; si había,
  /// la deja. Devuelve la llegada que quedó (R5, R6).
  Future<DateTime> registrarLlegada(String alertaId);

  /// Todas las llegadas guardadas, por id de alerta.
  Future<Map<String, DateTime>> llegadas();

  /// Guarda la hora del servidor menos la del teléfono (R3).
  Future<void> guardarDesfase(Duration desfase);
}

/// Guarda las llegadas y el desfase en [Preferencias], que el isolate del
/// push también puede leer y escribir.
class AvisosRecibidosRepositoryLocal implements AvisosRecibidosRepository {
  AvisosRecibidosRepositoryLocal({
    required this._preferencias,
    required this._reloj,
  });

  /// Al registrar, borra las llegadas de más de 30 días para que la clave
  /// no crezca sin fin.
  static const conservarDurante = Duration(days: 30);

  final Preferencias _preferencias;
  final Reloj _reloj;

  @override
  Future<DateTime> registrarLlegada(String alertaId) async {
    final desfase = await _preferencias.desfaseReloj();
    // R4: la hora del teléfono corregida a la del servidor.
    final ahora = _reloj.ahora().millisecondsSinceEpoch + desfase;
    final guardadas = await _preferencias.avisosRecibidos();

    final limite = ahora - conservarDurante.inMilliseconds;
    guardadas.removeWhere((id, llegada) => llegada < limite);

    final llegada = guardadas.putIfAbsent(alertaId, () => ahora);
    await _preferencias.guardarAvisosRecibidos(guardadas);
    return DateTime.fromMillisecondsSinceEpoch(llegada);
  }

  @override
  Future<Map<String, DateTime>> llegadas() async {
    final guardadas = await _preferencias.avisosRecibidos();
    return {
      for (final MapEntry(:key, :value) in guardadas.entries)
        key: DateTime.fromMillisecondsSinceEpoch(value),
    };
  }

  @override
  Future<void> guardarDesfase(Duration desfase) =>
      _preferencias.guardarDesfaseReloj(desfase.inMilliseconds);
}
