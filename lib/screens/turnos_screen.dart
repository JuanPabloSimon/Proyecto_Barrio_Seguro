import 'package:flutter/material.dart';

import '../data/datos_demo.dart';
import '../models/turno.dart';
import '../theme/app_colors.dart';
import 'disponibilidad_screen.dart';

class TurnosScreen extends StatefulWidget {
  const TurnosScreen({super.key});

  @override
  State<TurnosScreen> createState() => _TurnosScreenState();
}

class _TurnosScreenState extends State<TurnosScreen> {
  bool _soloMios = false;

  @override
  Widget build(BuildContext context) {
    final turnos = _soloMios ? turnosDemo.where((t) => t.esMio).toList() : turnosDemo;

    return Scaffold(
      appBar: AppBar(title: const Text('Turnos de patrullaje')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Todos')),
              ButtonSegment(value: true, label: Text('Mis turnos')),
            ],
            selected: {_soloMios},
            showSelectedIcon: false,
            onSelectionChanged: (seleccion) =>
                setState(() => _soloMios = seleccion.first),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DisponibilidadScreen()),
            ),
            icon: const Icon(Icons.edit_calendar_outlined),
            label: const Text('Modificar disponibilidad'),
          ),
          const SizedBox(height: 20),
          for (final turno in turnos)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TarjetaTurno(turno: turno),
            ),
        ],
      ),
    );
  }
}

class _TarjetaTurno extends StatelessWidget {
  const _TarjetaTurno({required this.turno});

  final Turno turno;

  @override
  Widget build(BuildContext context) {
    final esMio = turno.esMio;
    final colorFecha = esMio ? Colors.white : AppColors.texto;

    return Card(
      shape: esMio
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.primary, width: 2),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 58,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: esMio ? AppColors.primary : AppColors.fondo,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(turno.diaCorto, style: TextStyle(color: colorFecha)),
                  Text(
                    '${turno.diaNumero}',
                    style: TextStyle(
                      color: colorFecha,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(turno.mes, style: TextStyle(color: colorFecha)),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          turno.dia,
                          style: const TextStyle(color: AppColors.textoSecundario),
                        ),
                      ),
                      if (esMio)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Tu turno',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    turno.horario,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final vecino in turno.vecinos) _NombreVecino(nombre: vecino),
                    ],
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
          const Icon(Icons.person_outline, size: 14, color: AppColors.textoSecundario),
          const SizedBox(width: 4),
          Text(nombre, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}
