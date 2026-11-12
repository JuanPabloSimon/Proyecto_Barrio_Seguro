import 'package:flutter/material.dart';

import '../../../dependencias.dart';
import '../../core/widgets/boton_sos.dart';
import '../../core/widgets/con_view_model.dart';
import '../../inicio/view_models/inicio_view_model.dart';
import '../../inicio/widgets/inicio_screen.dart';
import '../../mapa/view_models/mapa_view_model.dart';
import '../../mapa/widgets/mapa_screen.dart';
import '../../perfil/view_models/perfil_view_model.dart';
import '../../perfil/widgets/perfil_screen.dart';
import '../../sos/view_models/sos_view_model.dart';
import '../../sos/widgets/sos_screen.dart';
import '../../turnos/view_models/turnos_view_model.dart';
import '../../turnos/widgets/turnos_screen.dart';
import '../pestanias.dart';

/// Contenedor principal: barra de navegación inferior y botón SOS visible
/// en las cuatro secciones. El SOS abre una pantalla de confirmación antes
/// de enviar la alerta.
class PrincipalScreen extends StatefulWidget {
  const PrincipalScreen({super.key, required this.dependencias});

  final Dependencias dependencias;

  @override
  State<PrincipalScreen> createState() => _PrincipalScreenState();
}

class _PrincipalScreenState extends State<PrincipalScreen> {
  Pestania _actual = Pestania.inicio;

  // Un ViewModel por sección. Se crean una sola vez (no en build) y se
  // liberan en dispose.
  late final InicioViewModel _inicio;
  late final TurnosViewModel _turnos;
  late final MapaViewModel _mapa;
  late final PerfilViewModel _perfil;

  @override
  void initState() {
    super.initState();
    final d = widget.dependencias;
    _inicio = InicioViewModel(
      alertas: d.alertas,
      turnos: d.turnos,
      sesion: d.sesion,
      bus: d.bus,
      reloj: d.reloj,
      mesDeTurnos: d.mesDeTurnos,
    )..cargar();
    _turnos = TurnosViewModel(
      turnos: d.turnos,
      sesion: d.sesion,
      bus: d.bus,
      reloj: d.reloj,
      mes: d.mesDeTurnos,
    )..cargar();
    _mapa = MapaViewModel(alertas: d.alertas, bus: d.bus, reloj: d.reloj)
      ..cargar();
    _perfil = PerfilViewModel(sesion: d.sesion, bus: d.bus, reloj: d.reloj);
  }

  @override
  void dispose() {
    _inicio.dispose();
    _turnos.dispose();
    _mapa.dispose();
    _perfil.dispose();
    super.dispose();
  }

  void _irA(Pestania pestania) => setState(() => _actual = pestania);

  void _abrirSos() {
    final d = widget.dependencias;
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ConViewModel(
          crear: () =>
              SosViewModel(alertas: d.alertas, sesion: d.sesion, bus: d.bus),
          builder: (_, vm) => SosScreen(viewModel: vm),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.dependencias;
    return Scaffold(
      body: IndexedStack(
        index: _actual.index,
        children: [
          InicioScreen(viewModel: _inicio, dependencias: d, onIrA: _irA),
          TurnosScreen(viewModel: _turnos),
          MapaScreen(viewModel: _mapa, dependencias: d),
          PerfilScreen(viewModel: _perfil, dependencias: d, onIrA: _irA),
        ],
      ),
      floatingActionButton: BotonSos(onPressed: _abrirSos),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _actual.index,
        onDestinationSelected: (indice) => _irA(Pestania.values[indice]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Turnos',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Mapa',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
