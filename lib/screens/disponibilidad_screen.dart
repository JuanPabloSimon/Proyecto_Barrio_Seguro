import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class DisponibilidadScreen extends StatefulWidget {
  const DisponibilidadScreen({super.key});

  @override
  State<DisponibilidadScreen> createState() => _DisponibilidadScreenState();
}

class _DisponibilidadScreenState extends State<DisponibilidadScreen> {
  static const _dias = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];
  static const _franjas = ['20:00 - 22:00', '22:00 - 00:00', '00:00 - 02:00'];

  final Set<String> _seleccion = {
    'Viernes|22:00 - 00:00',
    'Domingo|20:00 - 22:00',
  };

  void _alternar(String clave) {
    setState(() {
      if (!_seleccion.remove(clave)) _seleccion.add(clave);
    });
  }

  void _guardar() {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Disponibilidad guardada')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi disponibilidad')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const Text(
            'Marcá las franjas en las que podés patrullar. La comisión arma los turnos con esta información.',
            style: TextStyle(color: AppColors.textoSecundario),
          ),
          const SizedBox(height: 16),
          for (final dia in _dias) ...[
            Text(dia, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final franja in _franjas)
                  FilterChip(
                    label: Text(franja),
                    selected: _seleccion.contains('$dia|$franja'),
                    onSelected: (_) => _alternar('$dia|$franja'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton(
            onPressed: _guardar,
            child: const Text('Guardar disponibilidad'),
          ),
        ),
      ),
    );
  }
}
