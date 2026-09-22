import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class BotonSos extends StatelessWidget {
  const BotonSos({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 76,
      child: FloatingActionButton(
        heroTag: 'sos',
        onPressed: onPressed,
        tooltip: 'Enviar alerta SOS',
        backgroundColor: AppColors.emergencia,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: const CircleBorder(
          side: BorderSide(color: Colors.white, width: 4),
        ),
        child: const Text(
          'SOS',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}
