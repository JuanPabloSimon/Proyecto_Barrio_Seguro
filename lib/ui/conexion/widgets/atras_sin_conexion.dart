import 'package:flutter/widgets.dart';

import '../view_models/conexion_view_model.dart';

/// Se queda con el botón Atrás del sistema mientras no hay conexión, para
/// que no cierre las rutas que tapa la pantalla sin conexión.
///
/// Va por ENCIMA de `MaterialApp`: como su `initState` corre antes que el
/// de `WidgetsApp`, queda primero en la lista de observadores y atiende el
/// botón Atrás antes que el `Navigator` de la app.
class AtrasSinConexion extends StatefulWidget {
  const AtrasSinConexion({
    super.key,
    required this.viewModel,
    required this.child,
  });

  final ConexionViewModel viewModel;

  /// El `MaterialApp`.
  final Widget child;

  @override
  State<AtrasSinConexion> createState() => _AtrasSinConexionState();
}

class _AtrasSinConexionState extends State<AtrasSinConexion>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Sin conexión se queda con el Atrás y no hace nada: las rutas tapadas
  /// quedan como estaban. Con conexión devuelve false y sigue el camino
  /// normal (`WidgetsApp` -> `maybePop` del `Navigator` de la app).
  @override
  Future<bool> didPopRoute() async => widget.viewModel.sinConexion;

  @override
  Widget build(BuildContext context) => widget.child;
}
