import 'package:flutter/material.dart';

import '../../../data/services/telefono_service.dart';
import '../../../plataforma/capacidades.dart';
import '../../core/tema/app_colors.dart';
import '../../core/widgets/dialogo_911.dart';

/// Tapa a todas las pantallas mientras la app no llega a su servidor.
///
/// No muestra el botón SOS: sin conexión no se puede mandar una alerta y
/// mostrarlo sería prometer algo que la app no puede cumplir. En su lugar
/// queda "Llamar al 911", que usa la red de voz del celular, no internet.
class SinConexionScreen extends StatelessWidget {
  const SinConexionScreen({
    super.key,
    required this.capacidades,
    required this.telefono,
  });

  /// Para el botón "Llamar al 911".
  final Capacidades capacidades;
  final TelefonoService telefono;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: SafeArea(
        // Con el texto al 200 % el contenido puede no entrar: se desplaza
        // en vez de desbordar.
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight > 48
                    ? constraints.maxHeight - 48
                    : 0,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ExcludeSemantics(
                    child: Icon(
                      Icons.wifi_off,
                      color: AppColors.texto,
                      size: 80,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // liveRegion: el lector de pantalla lo anuncia apenas
                  // aparece la pantalla.
                  Semantics(
                    header: true,
                    liveRegion: true,
                    child: const Text(
                      'Necesitás conexión a internet para usar la app',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.texto,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Conectate a un wifi o activá los datos del celular. '
                    'La app sigue sola cuando vuelva la conexión. '
                    'Si estás en peligro, llamá al 911.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.texto, fontSize: 18),
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: () => mostrarDialogo911(
                      context,
                      capacidades: capacidades,
                      telefono: telefono,
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.emergencia,
                      foregroundColor: AppColors.sobreColor,
                      minimumSize: const Size(64, 64),
                      textStyle: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    icon: const Icon(Icons.phone, size: 28),
                    label: const Text(
                      'Llamar al 911',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
