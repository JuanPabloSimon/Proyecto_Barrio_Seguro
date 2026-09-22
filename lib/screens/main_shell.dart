import 'package:flutter/material.dart';

import '../widgets/boton_sos.dart';
import 'home_screen.dart';
import 'mapa_screen.dart';
import 'perfil_screen.dart';
import 'sos_screen.dart';
import 'turnos_screen.dart';

/// Contenedor principal: barra de navegación inferior + botón SOS
/// visible en las cuatro pantallas principales.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  static const inicio = 0;
  static const turnos = 1;
  static const mapa = 2;
  static const perfil = 3;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _indice = MainShell.inicio;

  void _irA(int indice) => setState(() => _indice = indice);

  void _abrirSos() {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const SosScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _indice,
        children: [
          HomeScreen(onIrA: _irA),
          const TurnosScreen(),
          const MapaScreen(),
          const PerfilScreen(),
        ],
      ),
      floatingActionButton: BotonSos(onPressed: _abrirSos),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: _irA,
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
