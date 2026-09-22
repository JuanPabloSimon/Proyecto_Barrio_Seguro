import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/dialogo_911.dart';

/// Pantalla que se abre al tocar SOS: cuenta regresiva para poder
/// cancelar un toque accidental y, después, confirmación de envío.
class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  static const _cuentaInicial = 5;

  int _restante = _cuentaInicial;
  bool _enviada = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_restante <= 1) {
        _enviar();
      } else {
        setState(() => _restante--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _enviar() {
    _timer?.cancel();
    setState(() {
      _restante = 0;
      _enviada = true;
    });
  }

  void _cerrar([String? mensaje]) {
    _timer?.cancel();
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    if (mensaje != null) {
      messenger.showSnackBar(SnackBar(content: Text(mensaje)));
    }
  }

  ButtonStyle get _botonBlanco => FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.emergencia,
      );

  ButtonStyle get _botonContorno => OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white, width: 2),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.emergencia,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _enviada ? _vistaEnviada() : _vistaCuenta(),
        ),
      ),
    );
  }

  Widget _vistaCuenta() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        const Text(
          'Enviando alerta en',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 24),
        Center(
          child: Container(
            width: 160,
            height: 160,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 6),
            ),
            child: Text(
              '$_restante',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 72,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Tus vecinos van a recibir tu ubicación y un aviso en el celular.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        const Spacer(),
        FilledButton(
          onPressed: _enviar,
          style: _botonBlanco,
          child: const Text('Enviar ahora'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => _cerrar(),
          style: _botonContorno,
          child: const Text('Cancelar'),
        ),
      ],
    );
  }

  Widget _vistaEnviada() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        const Icon(Icons.check_circle_outline, color: Colors.white, size: 96),
        const SizedBox(height: 16),
        const Text(
          'Alerta enviada',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'Avisamos a los vecinos de tu zona. Si estás en peligro, llamá al 911.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        const Spacer(),
        FilledButton.icon(
          onPressed: () => mostrarDialogo911(context),
          style: _botonBlanco,
          icon: const Icon(Icons.phone),
          label: const Text('Llamar al 911'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => _cerrar('Marcaste la alerta como resuelta'),
          style: _botonContorno,
          child: const Text('Ya estoy a salvo'),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: () => _cerrar('Cancelaste la alerta: falsa alarma'),
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          child: const Text('Fue una falsa alarma'),
        ),
      ],
    );
  }
}
