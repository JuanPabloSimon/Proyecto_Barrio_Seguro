import 'package:flutter/material.dart';

import '../data/datos_demo.dart';
import '../widgets/tarjeta_alerta.dart';
import 'detalle_alerta_screen.dart';

class MisAlertasScreen extends StatelessWidget {
  const MisAlertasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mias = alertasDemo.where((a) => a.reportadaPorMi).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Mis alertas reportadas')),
      body: mias.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Todavía no reportaste alertas. Si ves algo raro, usá el botón SOS.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: mias.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, i) => TarjetaAlerta(
                alerta: mias[i],
                onTap: () => DetalleAlertaScreen.abrir(context, mias[i]),
              ),
            ),
    );
  }
}
