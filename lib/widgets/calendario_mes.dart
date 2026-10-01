import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/fechas.dart';

enum MarcaDia { ninguna, conTurnos, mia }

/// Calendario mensual (lunes a domingo) para elegir un día.
class CalendarioMes extends StatelessWidget {
  const CalendarioMes({
    super.key,
    required this.mes,
    required this.seleccionado,
    required this.onSeleccionar,
    required this.marcaDe,
  });

  /// Cualquier fecha del mes a mostrar.
  final DateTime mes;
  final DateTime seleccionado;
  final ValueChanged<DateTime> onSeleccionar;
  final MarcaDia Function(DateTime dia) marcaDe;

  @override
  Widget build(BuildContext context) {
    final primerDia = DateTime(mes.year, mes.month, 1);
    final diasDelMes = DateTime(mes.year, mes.month + 1, 0).day;
    final espaciosIniciales = primerDia.weekday - 1;

    return Column(
      children: [
        Row(
          children: [
            for (final dia in diasCalendario)
              Expanded(
                child: Center(
                  child: Text(
                    dia,
                    style: const TextStyle(
                      color: AppColors.textoSecundario,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          primary: false,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          children: [
            for (var i = 0; i < espaciosIniciales; i++) const SizedBox.shrink(),
            for (var dia = 1; dia <= diasDelMes; dia++)
              _CeldaDia(
                fecha: DateTime(mes.year, mes.month, dia),
                seleccionada: mismoDia(seleccionado, DateTime(mes.year, mes.month, dia)),
                marca: marcaDe(DateTime(mes.year, mes.month, dia)),
                onTap: () => onSeleccionar(DateTime(mes.year, mes.month, dia)),
              ),
          ],
        ),
      ],
    );
  }
}

class _CeldaDia extends StatelessWidget {
  const _CeldaDia({
    required this.fecha,
    required this.seleccionada,
    required this.marca,
    required this.onTap,
  });

  final DateTime fecha;
  final bool seleccionada;
  final MarcaDia marca;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final esMia = marca == MarcaDia.mia;

    final Color fondo;
    if (seleccionada) {
      fondo = AppColors.primary;
    } else if (esMia) {
      fondo = AppColors.primary.withValues(alpha: 0.14);
    } else {
      fondo = Colors.transparent;
    }

    final Color punto;
    if (marca == MarcaDia.ninguna) {
      punto = Colors.transparent;
    } else if (seleccionada) {
      punto = Colors.white;
    } else {
      punto = esMia ? AppColors.primary : AppColors.textoSecundario;
    }

    return Material(
      color: fondo,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${fecha.day}',
              style: TextStyle(
                color: seleccionada ? Colors.white : AppColors.texto,
                fontWeight: esMia || seleccionada ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 3),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: punto, shape: BoxShape.circle),
            ),
          ],
        ),
      ),
    );
  }
}
