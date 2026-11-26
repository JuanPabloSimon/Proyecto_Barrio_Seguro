import 'package:flutter/material.dart';

import '../../../data/services/telefono_service.dart';
import '../../../dependencias.dart';
import '../../../domain/models/alerta.dart';
import '../../../plataforma/capacidades.dart';
import '../../core/presentacion_alerta.dart';
import '../../core/tema/app_colors.dart';
import '../../core/widgets/aviso.dart';
import '../../core/widgets/chip_estado.dart';
import '../../core/widgets/con_view_model.dart';
import '../../core/widgets/dialogo_911.dart';
import '../../core/widgets/mapa_barrio.dart';
import '../../core/widgets/marca_sos.dart';
import '../../core/widgets/marca_tardia.dart';
import '../view_models/detalle_alerta_view_model.dart';
import 'confirmar_cambio_estado.dart';

class DetalleAlertaScreen extends StatelessWidget {
  const DetalleAlertaScreen({
    super.key,
    required this.viewModel,
    required this.capacidades,
    required this.telefono,
  });

  final DetalleAlertaViewModel viewModel;

  /// Para el botón "Llamar al 911".
  final Capacidades capacidades;
  final TelefonoService telefono;

  /// Abre el detalle de [alerta]. La alerta viaja como parámetro de la
  /// navegación y el ViewModel se crea una sola vez para esta pantalla.
  static void abrir(
    BuildContext context,
    Alerta alerta,
    Dependencias dependencias,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConViewModel(
          crear: () => DetalleAlertaViewModel(
            alerta: alerta,
            alertas: dependencias.alertas,
            sesion: dependencias.sesion,
            bus: dependencias.bus,
            reloj: dependencias.reloj,
            avisos: dependencias.avisos,
          )..cargarLlegada(),
          builder: (_, vm) => DetalleAlertaScreen(
            viewModel: vm,
            capacidades: dependencias.capacidades,
            telefono: dependencias.telefono,
          ),
        ),
      ),
    );
  }

  Future<void> _cerrarCon(
    BuildContext context,
    Future<bool> Function() accion,
    String mensaje,
  ) async {
    // Se obtienen antes del await: después, esta pantalla puede no existir.
    final navegador = Navigator.of(context);
    final mensajero = ScaffoldMessenger.of(context);
    final ok = await accion();
    if (!ok) return;
    // El aviso se muestra en la pantalla anterior, que es la que queda.
    navegador.pop();
    mostrarAvisoEn(mensajero, mensaje);
  }

  /// El vecino eligió [nuevo] en el control de estado. Pasar a Resuelta o
  /// reabrir piden confirmación antes (R33, R34); entre Activa y En
  /// atención, no (R7). El detalle queda abierto (R10).
  Future<void> _elegirEstado(BuildContext context, EstadoAlerta? nuevo) async {
    // Se obtiene antes de cualquier await.
    final mensajero = ScaffoldMessenger.of(context);
    final actual = viewModel.alerta.estado;
    if (nuevo == null || nuevo == actual || viewModel.cambiandoEstado) return;
    final confirmacion = confirmacionParaCambio(actual, nuevo);
    if (confirmacion != null) {
      final confirmo = await confirmarCambioDeEstado(
        context,
        confirmacion: confirmacion,
        nuevo: nuevo,
      );
      // R36, R37: sin confirmar no se pide nada ni se avisa nada.
      if (!confirmo || !context.mounted) return;
    }
    final ok = await viewModel.cambiarEstado(nuevo);
    if (ok) mostrarAvisoEn(mensajero, avisoCambioDeEstado(nuevo));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) => _CuerpoDetalleAlerta(
        viewModel: viewModel,
        capacidades: capacidades,
        telefono: telefono,
        onElegirEstado: (nuevo) => _elegirEstado(context, nuevo),
        onMarcarFalsaAlarma: () => _cerrarCon(
          context,
          viewModel.marcarFalsaAlarma,
          'Cancelaste la alerta: falsa alarma',
        ),
      ),
    );
  }
}

class _CuerpoDetalleAlerta extends StatelessWidget {
  const _CuerpoDetalleAlerta({
    required this.viewModel,
    required this.capacidades,
    required this.telefono,
    required this.onElegirEstado,
    required this.onMarcarFalsaAlarma,
  });

  final DetalleAlertaViewModel viewModel;
  final Capacidades capacidades;
  final TelefonoService telefono;
  final ValueChanged<EstadoAlerta?> onElegirEstado;
  final VoidCallback onMarcarFalsaAlarma;

  @override
  Widget build(BuildContext context) {
    final alerta = viewModel.alerta;
    final tardia = viewModel.tardia;
    final cambiando = viewModel.cambiandoEstado;

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de alerta')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Semantics(
              container: true,
              image: true,
              label:
                  'Mapa con la ubicación aproximada de la alerta: ${alerta.direccion}',
              child: ExcludeSemantics(
                child: SizedBox(
                  height: 200,
                  child: MapaBarrio(
                    alertas: [alerta],
                    encuadre: EncuadreMapa.alertas,
                    mostrarRadio: false,
                    mostrarUsuario: false,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (alerta.categoria == CategoriaAlerta.sos) const MarcaSos(),
              ChipEstado(estado: alerta.estado),
              Text(
                viewModel.hace,
                style: const TextStyle(color: AppColors.textoSecundario),
              ),
              // R24: la marca de tardía, con su hora real.
              if (tardia != null) MarcaTardia(texto: tardia),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            alerta.tipo,
            // El lector dice "SOS: Intento de robo" para un SOS.
            semanticsLabel: alerta.tituloConCategoria,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(alerta.descripcion, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.place_outlined),
            title: const Text('Ubicación aproximada'),
            subtitle: Text(alerta.direccion),
          ),
          // R35: el lector dice "Reportada por" y el nombre juntos.
          MergeSemantics(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline),
              title: const Text('Reportada por'),
              subtitle: Text(viewModel.reportadaPor),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => mostrarDialogo911(
              context,
              capacidades: capacidades,
              telefono: telefono,
            ),
            icon: const Icon(Icons.phone),
            label: const Text('Llamar al 911'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.emergencia,
              side: const BorderSide(color: AppColors.emergencia, width: 1.5),
            ),
          ),
          // R1, R2, R3: solo quien la reportó o la comisión.
          if (viewModel.puedeCambiarEstado) ...[
            const SizedBox(height: 24),
            _ControlDeEstado(
              estado: alerta.estado,
              cambiando: cambiando,
              error: viewModel.error,
              onElegir: onElegirEstado,
            ),
          ],
          // R20: "Fue una falsa alarma", como antes.
          if (viewModel.puedeMarcarFalsaAlarma) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: cambiando ? null : onMarcarFalsaAlarma,
              child: const Text('Fue una falsa alarma'),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Estado de la alerta": un [RadioListTile] por estado (Activa, En
/// atención, Resuelta), cada uno con ícono y nombre además del color (R29).
/// La opción elegida es siempre el estado actual de la alerta (R5): si un
/// cambio no se confirma o falla, vuelve sola a la anterior (R18, R37).
class _ControlDeEstado extends StatelessWidget {
  const _ControlDeEstado({
    required this.estado,
    required this.cambiando,
    required this.error,
    required this.onElegir,
  });

  final EstadoAlerta estado;
  final bool cambiando;
  final String? error;
  final ValueChanged<EstadoAlerta?> onElegir;

  @override
  Widget build(BuildContext context) {
    final error = this.error;
    // Todo el control es un solo elemento de la lista: cada parte lleva su
    // propio nodo (container) para que el encabezado, el indicador y el
    // error no se lean pegados.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          header: true,
          child: const Text(
            'Estado de la alerta',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        RadioGroup<EstadoAlerta>(
          groupValue: estado,
          onChanged: onElegir,
          child: Column(
            children: [
              for (final opcion in EstadoAlerta.values)
                RadioListTile<EstadoAlerta>(
                  value: opcion,
                  // R9: mientras se espera la respuesta, nada se toca.
                  enabled: !cambiando,
                  contentPadding: const EdgeInsets.only(right: 8),
                  title: Text(opcion.etiqueta),
                  // El nombre ya lo dice el título: el ícono no se anuncia.
                  secondary: ExcludeSemantics(
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: opcion.colorSuave,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(opcion.icono, color: opcion.color),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (cambiando) ...[
          const SizedBox(height: 8),
          Semantics(
            container: true,
            child: const Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    semanticsLabel: 'Cambiando el estado',
                  ),
                ),
                SizedBox(width: 12),
                // El indicador ya lo anuncia: el texto no se lee dos veces.
                Expanded(
                  child: ExcludeSemantics(child: Text('Cambiando el estado')),
                ),
              ],
            ),
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 8),
          _ErrorDeEstado(error),
        ],
      ],
    );
  }
}

/// Error al cambiar el estado: ícono y texto, anunciado al aparecer (R30).
class _ErrorDeEstado extends StatelessWidget {
  const _ErrorDeEstado(this.mensaje);

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.emergencia),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mensaje,
              style: const TextStyle(
                color: AppColors.emergencia,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
