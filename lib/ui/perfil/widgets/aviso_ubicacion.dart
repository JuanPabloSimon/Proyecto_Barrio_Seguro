import 'package:flutter/material.dart';

/// Aviso que explica para qué se usa la ubicación antes de compartirla.
///
/// Sigue lo que pide Google Play para estos avisos: va dentro de la app,
/// dice qué dato se usa, para qué y con quién se comparte, usa palabras
/// simples y deja decir que no (después se puede activar desde el perfil).
///
/// Devuelve true si el vecino acepta.
Future<bool> mostrarAvisoDeUbicacion(BuildContext context) async {
  final acepta = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      scrollable: true,
      icon: const Icon(Icons.location_on_outlined, size: 32),
      title: const Text('¿Compartir tu ubicación exacta?'),
      content: const Text(
        'Cuando envíes una alerta o un SOS, Barrio Seguro les va a mandar a '
        'los vecinos de la red el punto exacto donde estás, para que sepan '
        'adónde ir.\n\n'
        'Tu ubicación se usa solo en ese momento. Después, tu teléfono te '
        'va a pedir permiso.\n\n'
        'Si elegís "Ahora no", se comparte solo la zona aproximada. Podés '
        'cambiarlo cuando quieras desde tu perfil.',
      ),
      actionsOverflowButtonSpacing: 8,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Ahora no'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          child: const Text('Compartir ubicación'),
        ),
      ],
    ),
  );
  return acepta ?? false;
}
