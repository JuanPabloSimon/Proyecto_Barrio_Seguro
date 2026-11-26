import 'package:flutter/material.dart';

import '../../../data/services/telefono_service.dart';
import '../../../plataforma/capacidades.dart';
import '../view_models/conexion_view_model.dart';
import 'sin_conexion_screen.dart';

/// Va en `MaterialApp.builder`, por encima del `Navigator` de la app: así
/// tapa cualquier ruta abierta (ingreso, principal, SOS, detalle,
/// diálogos) con [SinConexionScreen] mientras no hay conexión.
///
/// El [child] (el `Navigator` con todas sus rutas) no se desmonta: queda
/// fuera de la pintura, de los toques y del lector de pantalla con
/// [Offstage], y sin animaciones con [TickerMode]. Cuando vuelve la
/// conexión se ve de nuevo lo que estaba abierto, con su estado.
///
/// También le avisa al [viewModel] cuando la app pasa a segundo plano o
/// vuelve, para que deje de comprobar o compruebe en el momento.
class CompuertaDeConexion extends StatefulWidget {
  const CompuertaDeConexion({
    super.key,
    required this.viewModel,
    required this.capacidades,
    required this.telefono,
    required this.child,
  });

  final ConexionViewModel viewModel;

  /// Para el botón "Llamar al 911" de la pantalla sin conexión.
  final Capacidades capacidades;
  final TelefonoService telefono;

  final Widget child;

  @override
  State<CompuertaDeConexion> createState() => _CompuertaDeConexionState();
}

class _CompuertaDeConexionState extends State<CompuertaDeConexion> {
  late final AppLifecycleListener _ciclo;

  @override
  void initState() {
    super.initState();
    _ciclo = AppLifecycleListener(
      onPause: () => widget.viewModel.alPasarASegundoPlano(),
      onResume: () => widget.viewModel.alVolverAPrimerPlano(),
    );
  }

  @override
  void dispose() {
    _ciclo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, child) {
        final sinConexion = widget.viewModel.sinConexion;
        return Stack(
          fit: StackFit.expand,
          children: [
            Offstage(
              offstage: sinConexion,
              child: TickerMode(enabled: !sinConexion, child: child!),
            ),
            // Navigator propio: el de la app queda por debajo de
            // MaterialApp.builder, y el diálogo del 911 necesita uno. El
            // HeroController de MaterialApp no se puede compartir entre
            // dos Navigator: este no usa ninguno.
            if (sinConexion)
              HeroControllerScope.none(
                child: Navigator(
                  onGenerateRoute: (_) => MaterialPageRoute<void>(
                    builder: (_) => SinConexionScreen(
                      capacidades: widget.capacidades,
                      telefono: widget.telefono,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      child: widget.child,
    );
  }
}
