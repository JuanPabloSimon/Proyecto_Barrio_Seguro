import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/fechas.dart';
import 'objetivo_tactil.dart';

enum MarcaDia { ninguna, conTurnos, mia }

/// Calendario del mes para elegir un día.
///
/// Una grilla de 7 columnas no deja celdas de 48 dp separadas 8 dp en un
/// teléfono de 360 dp, así que los días se muestran en una fila desplazable
/// con botones grandes, más los botones "Día anterior" y "Día siguiente"
/// para quien no quiera deslizar.
class SelectorDia extends StatefulWidget {
  const SelectorDia({
    super.key,
    required this.mes,
    required this.seleccionado,
    required this.onSeleccionar,
    required this.marcaDe,
    this.iconoPropio = Icons.directions_walk,
  });

  /// Cualquier fecha del mes a mostrar.
  final DateTime mes;
  final DateTime seleccionado;
  final ValueChanged<DateTime> onSeleccionar;
  final MarcaDia Function(DateTime dia) marcaDe;

  /// Ícono que marca los días en que el usuario tiene turno.
  final IconData iconoPropio;

  @override
  State<SelectorDia> createState() => _SelectorDiaState();
}

class _SelectorDiaState extends State<SelectorDia> {
  final _claveSeleccionado = GlobalKey();

  int get _diasDelMes => DateTime(widget.mes.year, widget.mes.month + 1, 0).day;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _mostrarSeleccionado());
  }

  @override
  void didUpdateWidget(SelectorDia anterior) {
    super.didUpdateWidget(anterior);
    if (!mismoDia(anterior.seleccionado, widget.seleccionado)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _mostrarSeleccionado());
    }
  }

  /// Desplaza solo la fila de días (no la pantalla) para que el día
  /// elegido quede a la vista.
  void _mostrarSeleccionado() {
    final contexto = _claveSeleccionado.currentContext;
    if (!mounted || contexto == null) return;
    final objeto = contexto.findRenderObject();
    final fila = Scrollable.maybeOf(contexto);
    if (objeto == null || !objeto.attached || fila == null) return;
    final sinAnimaciones = MediaQuery.disableAnimationsOf(context);
    fila.position.ensureVisible(
      objeto,
      alignment: 0.5,
      duration: sinAnimaciones ? Duration.zero : const Duration(milliseconds: 250),
    );
  }

  void _moverDias(int cantidad) {
    final nuevo = widget.seleccionado.add(Duration(days: cantidad));
    if (nuevo.month != widget.mes.month || nuevo.year != widget.mes.year) return;
    widget.onSeleccionar(DateTime(nuevo.year, nuevo.month, nuevo.day));
  }

  @override
  Widget build(BuildContext context) {
    final esPrimero = widget.seleccionado.day == 1;
    final esUltimo = widget.seleccionado.day == _diasDelMes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Día anterior',
              icon: const Icon(Icons.chevron_left),
              onPressed: esPrimero ? null : () => _moverDias(-1),
            ),
            const SizedBox(width: ObjetivoTactil.separacion),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  mesYAnio(widget.mes),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: ObjetivoTactil.separacion),
            IconButton(
              tooltip: 'Día siguiente',
              icon: const Icon(Icons.chevron_right),
              onPressed: esUltimo ? null : () => _moverDias(1),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var dia = 1; dia <= _diasDelMes; dia++) ...[
                if (dia > 1) const SizedBox(width: ObjetivoTactil.separacion),
                _botonDia(DateTime(widget.mes.year, widget.mes.month, dia)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _botonDia(DateTime fecha) {
    final seleccionado = mismoDia(fecha, widget.seleccionado);
    final marca = widget.marcaDe(fecha);

    final String detalle;
    switch (marca) {
      case MarcaDia.mia:
        detalle = 'tenés turno';
      case MarcaDia.conTurnos:
        detalle = 'hay turnos asignados';
      case MarcaDia.ninguna:
        detalle = 'sin turnos asignados';
    }

    return KeyedSubtree(
      key: seleccionado ? _claveSeleccionado : null,
      child: ObjetivoTactil(
        etiqueta: '${fechaLarga(fecha)}, $detalle',
        seleccionado: seleccionado,
        forma: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onTap: () => widget.onSeleccionar(fecha),
        child: _DiaVisual(
          fecha: fecha,
          seleccionado: seleccionado,
          marca: marca,
          iconoPropio: widget.iconoPropio,
        ),
      ),
    );
  }
}

class _DiaVisual extends StatelessWidget {
  const _DiaVisual({
    required this.fecha,
    required this.seleccionado,
    required this.marca,
    required this.iconoPropio,
  });

  final DateTime fecha;
  final bool seleccionado;
  final MarcaDia marca;
  final IconData iconoPropio;

  @override
  Widget build(BuildContext context) {
    final esMia = marca == MarcaDia.mia;

    final Color fondo;
    final Color colorTexto;
    if (seleccionado) {
      fondo = AppColors.primary;
      colorTexto = AppColors.sobreColor;
    } else if (esMia) {
      fondo = AppColors.primarioSuave;
      colorTexto = AppColors.texto;
    } else {
      fondo = AppColors.superficie;
      colorTexto = AppColors.texto;
    }

    // La marca se ve con forma, no solo con color: ícono si el turno es
    // tuyo, punto si hay turnos de otros vecinos.
    final Widget indicador;
    switch (marca) {
      case MarcaDia.mia:
        indicador = Icon(iconoPropio, size: 18, color: colorTexto);
      case MarcaDia.conTurnos:
        indicador = Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: colorTexto, shape: BoxShape.circle),
        );
      case MarcaDia.ninguna:
        indicador = const SizedBox.shrink();
    }

    return Container(
      constraints: const BoxConstraints(minWidth: 60, minHeight: 84),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: seleccionado || esMia ? AppColors.primary : AppColors.bordeCampo,
          width: seleccionado || esMia ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(nombreDiaCorto(fecha), style: TextStyle(color: colorTexto, fontSize: 14)),
          Text(
            '${fecha.day}',
            style: TextStyle(
              color: colorTexto,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 20, child: Center(child: indicador)),
        ],
      ),
    );
  }
}
