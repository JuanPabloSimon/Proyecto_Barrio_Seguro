import 'package:flutter/material.dart';

import '../../../dependencias.dart';
import '../../core/tema/app_colors.dart';
import '../../core/widgets/aviso.dart';
import '../../core/widgets/con_view_model.dart';
import '../../editar_perfil/view_models/editar_perfil_view_model.dart';
import '../../editar_perfil/widgets/editar_perfil_screen.dart';
import '../../login/view_models/login_view_model.dart';
import '../../login/widgets/login_screen.dart';
import '../../mis_alertas/view_models/mis_alertas_view_model.dart';
import '../../mis_alertas/widgets/mis_alertas_screen.dart';
import '../../principal/pestanias.dart';
import '../view_models/perfil_view_model.dart';
import 'aviso_ubicacion.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({
    super.key,
    required this.viewModel,
    required this.dependencias,
    required this.onIrA,
  });

  final PerfilViewModel viewModel;
  final Dependencias dependencias;

  /// Permite abrir otra pestaña (por ejemplo, Turnos) desde el menú.
  final ValueChanged<Pestania> onIrA;

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  PerfilViewModel get _vm => widget.viewModel;

  /// Al activar la ubicación, primero se explica para qué se usa si la
  /// política de la plataforma lo exige.
  ///
  /// Después del aviso, el sistema pide el permiso. Si no lo dan, el
  /// interruptor queda apagado y se explica por qué.
  Future<void> _cambiarCompartirUbicacion(bool valor) async {
    if (!valor) {
      await _vm.cambiarCompartirUbicacion(false);
      return;
    }
    if (_vm.debeAvisarAntesDeCompartirUbicacion) {
      final acepta = await mostrarAvisoDeUbicacion(context);
      if (!acepta || !mounted) return;
    }
    final mensajero = ScaffoldMessenger.of(context);
    final problema = await _vm.activarUbicacion();
    if (problema != null) mostrarAvisoEn(mensajero, problema);
  }

  void _abrirMisAlertas() {
    final d = widget.dependencias;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConViewModel(
          crear: () => MisAlertasViewModel(
            alertas: d.alertas,
            sesion: d.sesion,
            bus: d.bus,
            reloj: d.reloj,
          )..cargar(),
          builder: (_, vm) => MisAlertasScreen(viewModel: vm, dependencias: d),
        ),
      ),
    );
  }

  void _abrirEditarDatos() {
    final d = widget.dependencias;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConViewModel(
          crear: () => EditarPerfilViewModel(sesion: d.sesion, bus: d.bus),
          builder: (_, vm) => EditarPerfilScreen(viewModel: vm),
        ),
      ),
    );
  }

  Future<void> _cerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: const Text('¿Cerrar sesión?'),
        content: const Text(
          'Vas a dejar de recibir alertas hasta que vuelvas a ingresar.',
        ),
        actionsOverflowButtonSpacing: 8,
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
    await _vm.cerrarSesion();
    if (!mounted) return;
    final d = widget.dependencias;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => ConViewModel(
          crear: () => LoginViewModel(sesion: d.sesion),
          builder: (_, vm) => LoginScreen(viewModel: vm, dependencias: d),
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => _pantalla(context),
    );
  }

  Widget _pantalla(BuildContext context) {
    final usuario = _vm.usuario;
    if (usuario == null) return const Scaffold();
    final esGuardia = _vm.esGuardiaVentana;
    final colorRol = esGuardia ? AppColors.ventana : AppColors.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
        children: [
          const SizedBox(height: 8),
          Center(
            // Las iniciales son decorativas: el nombre completo se lee debajo.
            child: ExcludeSemantics(
              child: CircleAvatar(
                radius: 44,
                backgroundColor: AppColors.primary,
                // Las iniciales se achican si no entran en el círculo.
                child: FittedBox(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      usuario.iniciales,
                      style: const TextStyle(
                        color: AppColors.sobreColor,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
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
          Text(_vm.direccion, textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(
            _vm.edadYAntiguedad,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textoSecundario),
          ),
          const SizedBox(height: 12),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: esGuardia
                    ? AppColors.ventanaSuave
                    : AppColors.primarioSuave,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    esGuardia ? Icons.window_outlined : Icons.directions_walk,
                    size: 16,
                    color: colorRol,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Turnos: ${_vm.rol}',
                      style: TextStyle(
                        color: colorRol,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          const _TituloSeccion('Privacidad y avisos'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Compartir ubicación exacta en alertas'),
                  subtitle: Text(
                    !_vm.tieneGps
                        ? 'Este dispositivo no tiene GPS. Se comparte la '
                              'zona aproximada.'
                        : _vm.compartirUbicacion
                        ? 'Tus vecinos ven el punto exacto'
                        : 'Solo se comparte la zona aproximada',
                  ),
                  value: _vm.tieneGps && _vm.compartirUbicacion,
                  // null deja el interruptor desactivado.
                  onChanged: _vm.tieneGps ? _cambiarCompartirUbicacion : null,
                ),
                if (_vm.permisoBloqueado)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _vm.abrirAjustes,
                        icon: const Icon(Icons.settings_outlined),
                        label: const Text('Abrir los ajustes del teléfono'),
                      ),
                    ),
                  ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Notificaciones push'),
                  subtitle: Text(
                    _vm.puedeRecibirNotificaciones
                        ? 'Avisos de alertas cerca tuyo'
                        : 'Este dispositivo no recibe notificaciones. '
                              'Activalas desde tu celular.',
                  ),
                  value: _vm.notificaciones,
                  // null deja el interruptor desactivado.
                  onChanged: _vm.puedeRecibirNotificaciones
                      ? _vm.cambiarNotificaciones
                      : null,
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
                  onTap: _abrirMisAlertas,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.event_available_outlined),
                  title: const Text('Mis turnos'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => widget.onIrA(Pestania.turnos),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Editar datos personales'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _abrirEditarDatos,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.logout,
                    color: AppColors.emergencia,
                  ),
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
      child: Semantics(
        header: true,
        child: Text(
          texto,
          style: const TextStyle(
            color: AppColors.textoSecundario,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
