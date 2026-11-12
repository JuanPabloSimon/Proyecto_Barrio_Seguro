import 'package:flutter/material.dart';

import '../../../domain/models/turno.dart';
import '../../../domain/models/vecino.dart';
import '../../../domain/reglas_turnos.dart';
import '../../core/estado_carga.dart';
import '../../core/formato.dart';
import '../../core/tema/app_colors.dart';
import '../../core/widgets/aviso.dart';
import '../../core/widgets/aviso_sin_conexion.dart';
import '../../core/widgets/estado_de_carga.dart';
import '../../core/widgets/selector_dia.dart';
import '../../core/widgets/tarjeta_tocable.dart';
import '../view_models/turnos_view_model.dart';

class TurnosScreen extends StatelessWidget {
  const TurnosScreen({super.key, required this.viewModel});

  final TurnosViewModel viewModel;

  Future<void> _anotar(BuildContext context, Turno turno) async {
    final mensaje = await viewModel.anotarse(turno);
    if (context.mounted) mostrarAviso(context, mensaje);
  }

  Future<void> _salir(BuildContext context, Turno turno) async {
    final mensaje = await viewModel.salir(turno);
    if (context.mounted) mostrarAviso(context, mensaje);
  }

  IconData get _iconoPropio => viewModel.esGuardiaVentana
      ? Icons.window_outlined
      : Icons.directions_walk;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Turnos de patrullaje')),
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          final usuario = viewModel.usuario;
          return switch (viewModel.estado) {
            EstadoCarga.inicial ||
            EstadoCarga.cargando => const IndicadorDeCarga(),
            EstadoCarga.error => MensajeDeError(onReintentar: viewModel.cargar),
            EstadoCarga.exito when usuario == null => const SizedBox.shrink(),
            EstadoCarga.exito => _contenido(context, usuario!),
          };
        },
      ),
    );
  }

  Widget _contenido(BuildContext context, Vecino usuario) {
    final mios = viewModel.misTurnos;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
      children: [
        if (viewModel.sinConexion)
          const AvisoSinConexion(margen: EdgeInsets.only(bottom: 12)),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Todos')),
            ButtonSegment(value: true, label: Text('Mis turnos')),
          ],
          selected: {viewModel.soloMios},
          // El ícono de check marca la opción elegida además del color.
          showSelectedIcon: true,
          onSelectionChanged: (seleccion) =>
              viewModel.mostrarSoloMios(seleccion.first),
        ),
        const SizedBox(height: 12),
        _ResumenCupo(
          esGuardia: viewModel.esGuardiaVentana,
          cantidad: mios.length,
          mes: viewModel.mes,
        ),
        const SizedBox(height: 16),
        if (viewModel.soloMios)
          ..._listaMisTurnos(mios)
        else
          ..._vistaCalendario(context, usuario),
      ],
    );
  }

  List<Widget> _vistaCalendario(BuildContext context, Vecino usuario) {
    final dia = viewModel.dia;
    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SelectorDia(
                mes: viewModel.mes,
                seleccionado: dia,
                onSeleccionar: viewModel.elegirDia,
                marcaDe: viewModel.marcaDe,
                iconoPropio: _iconoPropio,
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _LeyendaCalendario(iconoPropio: _iconoPropio),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      Semantics(
        header: true,
        child: Text(
          fechaLarga(dia),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      const SizedBox(height: 10),
      for (final franja in Franja.values)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _TarjetaFranja(
            turno: viewModel.turno(dia, franja),
            usuario: usuario,
            esGuardia: viewModel.esGuardiaVentana,
            motivoNoDisponible: viewModel.motivoNoDisponible(
              viewModel.turno(dia, franja),
            ),
            ocupado: viewModel.ocupado,
            onAnotar: (turno) => _anotar(context, turno),
            onSalir: (turno) => _salir(context, turno),
          ),
        ),
    ];
  }

  List<Widget> _listaMisTurnos(List<Turno> mios) {
    if (mios.isEmpty) {
      return [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Todavía no tenés turnos en ${nombreMes(viewModel.mes.month)}.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Center(
                  child: FilledButton(
                    onPressed: () => viewModel.mostrarSoloMios(false),
                    child: const Text('Elegir en el calendario'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    return [
      for (final turno in mios)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _MiTurno(
            turno: turno,
            lineas: viewModel.detalleDe(turno),
            onTap: () => viewModel.verEnCalendario(turno.fecha),
          ),
        ),
    ];
  }
}

class _ResumenCupo extends StatelessWidget {
  const _ResumenCupo({
    required this.esGuardia,
    required this.cantidad,
    required this.mes,
  });

  final bool esGuardia;
  final int cantidad;
  final DateTime mes;

  @override
  Widget build(BuildContext context) {
    final color = esGuardia ? AppColors.ventana : AppColors.primary;
    const maximo = ReglasTurnos.maxTurnosPorMes;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: esGuardia
                  ? AppColors.ventanaSuave
                  : AppColors.primarioSuave,
              foregroundColor: color,
              child: Icon(
                esGuardia ? Icons.window_outlined : Icons.directions_walk,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tus turnos de ${nombreMes(mes.month)}: $cantidad de $maximo',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    esGuardia
                        ? 'Participás como guardia de ventana: vigilás desde tu casa, sin salir a patrullar.'
                        : 'Participás en el patrullaje. Máximo $maximo turnos por mes.',
                    style: const TextStyle(
                      color: AppColors.textoSecundario,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeyendaCalendario extends StatelessWidget {
  const _LeyendaCalendario({required this.iconoPropio});

  final IconData iconoPropio;

  @override
  Widget build(BuildContext context) {
    Widget item(Widget muestra, String texto) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        muestra,
        const SizedBox(width: 6),
        Flexible(child: Text(texto, style: const TextStyle(fontSize: 14))),
      ],
    );

    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        item(
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.texto,
              shape: BoxShape.circle,
            ),
          ),
          'Días con turnos de otros vecinos',
        ),
        item(
          Icon(iconoPropio, size: 18, color: AppColors.texto),
          'Días con turno tuyo',
        ),
      ],
    );
  }
}

class _TarjetaFranja extends StatelessWidget {
  const _TarjetaFranja({
    required this.turno,
    required this.usuario,
    required this.esGuardia,
    required this.motivoNoDisponible,
    required this.ocupado,
    required this.onAnotar,
    required this.onSalir,
  });

  final Turno turno;
  final Vecino usuario;
  final bool esGuardia;
  final String? motivoNoDisponible;

  /// Mientras se guarda un cambio, los botones no se pueden tocar.
  final bool ocupado;
  final ValueChanged<Turno> onAnotar;
  final ValueChanged<Turno> onSalir;

  @override
  Widget build(BuildContext context) {
    final esMio = turno.incluye(usuario);
    final motivo = esMio ? null : motivoNoDisponible;
    final libres = ReglasTurnos.cupoPatrulla - turno.patrulleros.length;
    final guardia = turno.guardiaVentana;

    final String tituloPatrulla;
    if (libres <= 0) {
      tituloPatrulla = 'Patrulla (completa)';
    } else if (libres == 1) {
      tituloPatrulla = 'Patrulla (1 lugar libre)';
    } else {
      tituloPatrulla = 'Patrulla ($libres lugares libres)';
    }

    return Card(
      shape: esMio
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.primary, width: 2),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    turno.franja.horario,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (esMio)
                  const _Etiqueta(
                    texto: 'Tu turno',
                    color: AppColors.primary,
                    fondo: AppColors.primarioSuave,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _Subtitulo(tituloPatrulla),
            const SizedBox(height: 6),
            if (turno.patrulleros.isEmpty)
              const Text(
                'Nadie anotado todavía',
                style: TextStyle(color: AppColors.textoSecundario),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final vecino in turno.patrulleros)
                    _NombreVecino(
                      nombre: vecino.id == usuario.id
                          ? '${vecino.nombre} (vos)'
                          : vecino.nombre,
                    ),
                ],
              ),
            const SizedBox(height: 12),
            const _Subtitulo('Guardia de ventana'),
            const SizedBox(height: 6),
            if (guardia == null)
              const Text(
                'Sin guardia de ventana',
                style: TextStyle(color: AppColors.textoSecundario),
              )
            else
              _GuardiaVentana(
                vecino: guardia,
                esUsuario: guardia.id == usuario.id,
              ),
            const SizedBox(height: 14),
            // Los botones ocupan el ancho de su texto, no toda la tarjeta,
            // para que el SOS siga siendo el botón más grande de la pantalla.
            if (esMio)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  onPressed: ocupado ? null : () => onSalir(turno),
                  child: const Text('Salir del turno'),
                ),
              )
            else ...[
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  onPressed: motivo == null && !ocupado
                      ? () => onAnotar(turno)
                      : null,
                  child: Text(
                    esGuardia ? 'Anotarme como guardia de ventana' : 'Anotarme',
                  ),
                ),
              ),
              if (motivo != null) ...[
                const SizedBox(height: 8),
                Text(
                  motivo,
                  style: const TextStyle(
                    color: AppColors.textoSecundario,
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Turno propio en la vista "Mis turnos".
class _MiTurno extends StatelessWidget {
  const _MiTurno({
    required this.turno,
    required this.lineas,
    required this.onTap,
  });

  final Turno turno;

  /// Compañeros y guardia de ventana, ya armados por el ViewModel.
  final List<String> lineas;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final etiqueta =
        '${fechaLarga(turno.fecha)}, ${turno.franja.horario}. '
        '${lineas.join('. ')}. Ver en el calendario';

    return TarjetaTocable(
      etiqueta: etiqueta,
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // Ancho mínimo (no fijo) para que la fecha crezca con el texto.
          Container(
            constraints: const BoxConstraints(minWidth: 64),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  nombreDiaCorto(turno.fecha),
                  style: const TextStyle(color: AppColors.sobreColor),
                ),
                Text(
                  '${turno.fecha.day}',
                  style: const TextStyle(
                    color: AppColors.sobreColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  nombreMes(turno.fecha.month).substring(0, 3),
                  style: const TextStyle(color: AppColors.sobreColor),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  turno.franja.horario,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
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
    );
  }
}

class _GuardiaVentana extends StatelessWidget {
  const _GuardiaVentana({required this.vecino, required this.esUsuario});

  final Vecino vecino;
  final bool esUsuario;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.ventanaSuave,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.ventana),
      ),
      child: Row(
        children: [
          const Icon(Icons.window_outlined, color: AppColors.ventana),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  esUsuario ? '${vecino.nombre} (vos)' : vecino.nombre,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  'Guardia de ventana, mayor de ${ReglasTurnos.edadGuardiaVentana} años',
                  style: const TextStyle(
                    color: AppColors.ventana,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NombreVecino extends StatelessWidget {
  const _NombreVecino({required this.nombre});

  final String nombre;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.fondo,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.directions_walk,
            size: 14,
            color: AppColors.textoSecundario,
          ),
          const SizedBox(width: 4),
          Flexible(child: Text(nombre, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}

class _Subtitulo extends StatelessWidget {
  const _Subtitulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: const TextStyle(
        color: AppColors.textoSecundario,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta({
    required this.texto,
    required this.color,
    required this.fondo,
  });

  final String texto;
  final Color color;
  final Color fondo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
