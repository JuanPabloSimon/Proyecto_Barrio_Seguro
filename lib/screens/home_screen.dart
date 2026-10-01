import 'package:flutter/material.dart';

import '../data/datos_demo.dart';
import '../data/sesion.dart';
import '../data/turnos_repositorio.dart';
import '../models/alerta.dart';
import '../theme/app_colors.dart';
import '../utils/fechas.dart';
import '../widgets/dialogo_911.dart';
import '../widgets/mapa_simulado.dart';
import '../widgets/tarjeta_alerta.dart';
import 'detalle_alerta_screen.dart';
import 'main_shell.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onIrA});

  /// Permite cambiar de pestaña desde el inicio (por ejemplo, abrir el mapa).
  final ValueChanged<int> onIrA;

  @override
  Widget build(BuildContext context) {
    final cercanas =
        alertasDemo.where((a) => a.estado != EstadoAlerta.resuelta).toList();
    final activas =
        alertasDemo.where((a) => a.estado == EstadoAlerta.activa).length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Hola, ${Sesion.usuario.primerNombre}'),
        actions: [
          IconButton(
            tooltip: 'Ver alertas',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => onIrA(MainShell.mapa),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 130),
        children: [
          if (activas > 0) ...[
            _BannerAlertas(
              cantidad: activas,
              onTap: () => onIrA(MainShell.mapa),
            ),
            const SizedBox(height: 16),
          ],
          _ProximoTurno(onTap: () => onIrA(MainShell.turnos)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => onIrA(MainShell.mapa),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 170,
                child: Stack(
                  children: [
                    MapaSimulado(alertas: cercanas, tamanioPin: 28),
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Abrir mapa',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => mostrarDialogo911(context),
            icon: const Icon(Icons.phone),
            label: const Text('Llamar al 911'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.emergencia,
              side: const BorderSide(color: AppColors.emergencia, width: 1.5),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Alertas cerca tuyo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: () => onIrA(MainShell.mapa),
                child: const Text('Ver en el mapa'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final alerta in cercanas)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TarjetaAlerta(
                alerta: alerta,
                onTap: () => DetalleAlertaScreen.abrir(context, alerta),
              ),
            ),
        ],
      ),
    );
  }
}

class _BannerAlertas extends StatelessWidget {
  const _BannerAlertas({required this.cantidad, required this.onTap});

  final int cantidad;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final texto = cantidad == 1
        ? '1 alerta activa en tu zona'
        : '$cantidad alertas activas en tu zona';

    return Material(
      color: AppColors.alerta,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      texto,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Tocá para verlas en el mapa',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarjeta "Tu próximo turno". Se actualiza sola cuando el usuario se anota
/// o sale de un turno en la pestaña Turnos.
class _ProximoTurno extends StatelessWidget {
  const _ProximoTurno({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: turnosRepositorio,
      builder: (context, _) {
        final usuario = Sesion.usuario;
        final mios = turnosRepositorio.turnosDe(usuario, mesDeTurnos);

        final String titulo;
        final List<String> lineas = [];

        if (mios.isEmpty) {
          titulo = 'Todavía no tenés turnos en ${nombreMes(mesDeTurnos.month)}';
          lineas.add('Elegí un día y un horario en el calendario de turnos.');
        } else {
          final turno = mios.first;
          titulo = usuario.esGuardiaVentana
              ? 'Tu próxima guardia de ventana'
              : 'Tu próximo turno de patrullaje';
          lineas.add('${fechaLarga(turno.fecha)}, ${turno.franja.horario}');

          final patrulla = turno.companierosDe(usuario).map((v) => v.nombre).join(', ');
          if (usuario.esGuardiaVentana) {
            lineas.add(patrulla.isEmpty ? 'Sin patrulla anotada todavía' : 'Patrulla: $patrulla');
          } else {
            lineas.add(patrulla.isEmpty ? 'Sin compañero todavía' : 'Con $patrulla');
            final guardia = turno.guardiaVentana;
            if (guardia != null) lineas.add('Guardia de ventana: ${guardia.nombre}');
          }
        }

        return Card(
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor:
                        usuario.esGuardiaVentana ? AppColors.ventana : AppColors.primary,
                    foregroundColor: Colors.white,
                    child: Icon(
                      usuario.esGuardiaVentana ? Icons.window_outlined : Icons.directions_walk,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          lineas.join('\n'),
                          style: const TextStyle(color: AppColors.textoSecundario),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
