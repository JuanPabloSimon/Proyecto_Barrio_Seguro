import 'package:flutter/material.dart';

import '../data/datos_demo.dart';
import '../theme/app_colors.dart';
import 'disponibilidad_screen.dart';
import 'editar_perfil_screen.dart';
import 'login_screen.dart';
import 'mis_alertas_screen.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  bool _compartirUbicacion = true;
  bool _notificaciones = true;

  void _abrir(Widget pantalla) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => pantalla));
  }

  Future<void> _cerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('Vas a dejar de recibir alertas hasta que vuelvas a ingresar.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.emergencia),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    const usuario = usuarioDemo;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
        children: [
          const SizedBox(height: 8),
          Center(
            child: CircleAvatar(
              radius: 44,
              backgroundColor: AppColors.primary,
              child: Text(
                usuario.iniciales,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            usuario.nombre,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${usuario.calle}, ${usuario.cuadra}',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            usuario.antiguedad,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textoSecundario),
          ),
          const SizedBox(height: 28),
          const _TituloSeccion('Privacidad y avisos'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Compartir ubicación exacta en alertas'),
                  subtitle: Text(
                    _compartirUbicacion
                        ? 'Tus vecinos ven el punto exacto'
                        : 'Solo se comparte la zona aproximada',
                  ),
                  value: _compartirUbicacion,
                  onChanged: (valor) => setState(() => _compartirUbicacion = valor),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Notificaciones push'),
                  subtitle: const Text('Avisos de alertas cerca tuyo'),
                  value: _notificaciones,
                  onChanged: (valor) => setState(() => _notificaciones = valor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _TituloSeccion('Cuenta'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.campaign_outlined),
                  title: const Text('Mis alertas reportadas'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _abrir(const MisAlertasScreen()),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.event_available_outlined),
                  title: const Text('Mi disponibilidad de turnos'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _abrir(const DisponibilidadScreen()),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Editar datos personales'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _abrir(const EditarPerfilScreen()),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout, color: AppColors.emergencia),
                  title: const Text(
                    'Cerrar sesión',
                    style: TextStyle(color: AppColors.emergencia),
                  ),
                  onTap: _cerrarSesion,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TituloSeccion extends StatelessWidget {
  const _TituloSeccion(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        texto,
        style: const TextStyle(
          color: AppColors.textoSecundario,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
