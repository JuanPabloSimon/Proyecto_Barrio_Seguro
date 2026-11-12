import 'dart:async';

import '../../domain/evento_de_app.dart';

/// Stream global de eventos de la app. Se crea una sola vez en main y se
/// inyecta donde haga falta.
class BusDeEventos {
  final _controlador = StreamController<EventoDeApp>.broadcast();

  Stream<EventoDeApp> get eventos => _controlador.stream;

  /// Solo los de un tipo: `bus.de<TurnosActualizados>()`.
  Stream<T> de<T extends EventoDeApp>() =>
      eventos.where((e) => e is T).cast<T>();

  void publicar(EventoDeApp evento) => _controlador.add(evento);

  /// Si alguien sigue escuchando. Sirve para probar que los ViewModels se
  /// dan de baja en `dispose`.
  bool get tieneOyentes => _controlador.hasListener;

  Future<void> cerrar() => _controlador.close();
}
