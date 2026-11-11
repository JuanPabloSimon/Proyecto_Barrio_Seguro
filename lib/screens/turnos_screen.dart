import 'package:flutter/material.dart';

import '../data/datos_demo.dart';
import '../data/sesion.dart';
import '../data/turnos_repositorio.dart';
import '../models/turno.dart';
import '../models/vecino.dart';
import '../theme/app_colors.dart';
import '../utils/fechas.dart';
import '../widgets/selector_dia.dart';

class TurnosScreen extends StatefulWidget {
  const TurnosScreen({super.key});

  @override
  State<TurnosScreen> createState() => _TurnosScreenState();
}

class _TurnosScreenState extends State<TurnosScreen> {
  bool _soloMios = false;
  late DateTime _dia;

  @override
  void initState() {
    super.initState();
    final mios = turnosRepositorio.turnosDe(Sesion.usuario, mesDeTurnos);
    _dia = mios.isNotEmpty ? mios.first.fecha : mesDeTurnos;
  }

  void _avisar(String mensaje) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }

  void _anotar(Turno turno) {
    turnosRepositorio.anotar(Sesion.usuario, turno.fecha, turno.franja);
    _avisar('Te anotaste: ${fechaLarga(turno.fecha)}, ${turno.franja.horario}');
  }

  void _salir(Turno turno) {
    turnosRepositorio.salir(Sesion.usuario, turno.fecha, turno.franja);
    _avisar('Saliste del turno del ${fechaLarga(turno.fecha).toLowerCase()}');
  }

  void _verEnCalendario(DateTime dia) {
    setState(() {
      _soloMios = false;
      _dia = dia;
    });
  }

  MarcaDia _marcaDe(DateTime dia, Vecino usuario) {
    final turnos = Franja.values.map((f) => turnosRepositorio.turno(dia, f));
    if (turnos.any((t) => t.incluye(usuario))) return MarcaDia.mia;
    if (turnos.any((t) => !t.vacio)) return MarcaDia.conTurnos;
    return MarcaDia.ninguna;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Turnos de patrullaje')),
      body: ListenableBuilder(
        listenable: turnosRepositorio,
        builder: (context, _) {
          final usuario = Sesion.usuario;
          final mios = turnosRepositorio.turnosDe(usuario, mesDeTurnos);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Todos')),
                  ButtonSegment(value: true, label: Text('Mis turnos')),
                ],
                selected: {_soloMios},
                // El ícono de check marca la opción elegida además del color.
                showSelectedIcon: true,
                onSelectionChanged: (seleccion) =>
                    setState(() => _soloMios = seleccion.first),
              ),
              const SizedBox(height: 12),
              _ResumenCupo(usuario: usuario, cantidad: mios.length),
              const SizedBox(height: 16),
              if (_soloMios)
                ..._listaMisTurnos(mios, usuario)
              else
                ..._vistaCalendario(usuario),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _vistaCalendario(Vecino usuario) {
    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SelectorDia(
                mes: mesDeTurnos,
                seleccionado: _dia,
                onSeleccionar: (dia) => setState(() => _dia = dia),
                marcaDe: (dia) => _marcaDe(dia, usuario),
                iconoPropio: usuario.esGuardiaVentana
                    ? Icons.window_outlined
                    : Icons.directions_walk,
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _LeyendaCalendario(
                  iconoPropio: usuario.esGuardiaVentana
                      ? Icons.window_outlined
                      : Icons.directions_walk,
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      Text(
        fechaLarga(_dia),
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 10),
      for (final franja in Franja.values)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _TarjetaFranja(
            turno: turnosRepositorio.turno(_dia, franja),
            usuario: usuario,
            onAnotar: _anotar,
            onSalir: _salir,
          ),
        ),
    ];
  }

  List<Widget> _listaMisTurnos(List<Turno> mios, Vecino usuario) {
    if (mios.isEmpty) {
      return [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Todavía no tenés turnos en ${nombreMes(mesDeTurnos.month)}.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Center(
                  child: FilledButton(
                    onPressed: () => setState(() => _soloMios = false),
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
            usuario: usuario,
            onTap: () => _verEnCalendario(turno.fecha),
          ),
        ),
    ];
  }
}

class _ResumenCupo extends StatelessWidget {
  const _ResumenCupo({required this.usuario, required this.cantidad});

  final Vecino usuario;
  final int cantidad;

  @override
  Widget build(BuildContext context) {
    final esGuardia = usuario.esGuardiaVentana;
    final color = esGuardia ? AppColors.ventana : AppColors.primary;
    const maximo = TurnosRepositorio.maxTurnosPorMes;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: esGuardia ? AppColors.ventanaSuave : AppColors.primarioSuave,
              foregroundColor: color,
              child: Icon(esGuardia ? Icons.window_outlined : Icons.directions_walk),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tus turnos de ${nombreMes(mesDeTurnos.month)}: $cantidad de $maximo',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    esGuardia
                        ? 'Participás como guardia de ventana: vigilás desde tu casa, sin salir a patrullar.'
                        : 'Participás en el patrullaje. Máximo $maximo turnos por mes.',
                    style: const TextStyle(color: AppColors.textoSecundario, fontSize: 14),
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
    required this.onAnotar,
    required this.onSalir,
  });

  final Turno turno;
  final Vecino usuario;
  final ValueChanged<Turno> onAnotar;
  final ValueChanged<Turno> onSalir;

  @override
  Widget build(BuildContext context) {
    final esMio = turno.incluye(usuario);
    final motivo = esMio ? null : turnosRepositorio.motivoNoDisponible(usuario, turno);
    final libres = TurnosRepositorio.cupoPatrulla - turno.patrulleros.length;
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
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                if (esMio) const _Etiqueta(
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
                      nombre: vecino.id == usuario.id ? '${vecino.nombre} (vos)' : vecino.nombre,
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
              _GuardiaVentana(vecino: guardia, esUsuario: guardia.id == usuario.id),
            const SizedBox(height: 14),
            // Los botones ocupan el ancho de su texto, no toda la tarjeta,
            // para que el SOS siga siendo el botón más grande de la pantalla.
            if (esMio)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  onPressed: () => onSalir(turno),
                  child: const Text('Salir del turno'),
                ),
              )
            else ...[
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  onPressed: motivo == null ? () => onAnotar(turno) : null,
                  child: Text(
                    usuario.esGuardiaVentana ? 'Anotarme como guardia de ventana' : 'Anotarme',
                  ),
                ),
              ),
              if (motivo != null) ...[
                const SizedBox(height: 8),
                Text(
                  motivo,
                  style: const TextStyle(color: AppColors.textoSecundario, fontSize: 14),
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
  const _MiTurno({required this.turno, required this.usuario, required this.onTap});

  final Turno turno;
  final Vecino usuario;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final companieros = turno.companierosDe(usuario).map((v) => v.nombre).join(', ');
    final guardia = turno.guardiaVentana;
    final lineas = <String>[];

    if (usuario.esGuardiaVentana) {
      lineas.add('Guardia de ventana desde tu casa');
      lineas.add(companieros.isEmpty ? 'Sin patrulla anotada todavía' : 'Patrulla: $companieros');
    } else {
      lineas.add(companieros.isEmpty ? 'Sin compañero todavía' : 'Con $companieros');
      if (guardia != null) {
        lineas.add('Guardia de ventana: ${guardia.nombre} (mayor de ${Vecino.edadGuardiaVentana})');
      }
    }

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 58,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      nombreDiaCorto(turno.fecha),
                      style: const TextStyle(color: Colors.white),
                    ),
                    Text(
                      '${turno.fecha.day}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      nombreMes(turno.fecha.month).substring(0, 3),
                      style: const TextStyle(color: Colors.white),
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
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
                  'Guardia de ventana, mayor de ${Vecino.edadGuardiaVentana} años',
                  style: const TextStyle(color: AppColors.ventana, fontSize: 14),
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
          const Icon(Icons.directions_walk, size: 14, color: AppColors.textoSecundario),
          const SizedBox(width: 4),
          Text(nombre, style: const TextStyle(fontSize: 14)),
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
  const _Etiqueta({required this.texto, required this.color, required this.fondo});

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
        style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold),
      ),
    );
  }
}
