import 'package:flutter/material.dart';

/// Muestra un aviso breve abajo de la pantalla.
///
/// Dura 6 segundos (más que el valor por defecto, para dar tiempo a leerlo)
/// y tiene un botón para cerrarlo. Se usa solo para confirmar algo que ya
/// pasó; nada que la persona necesite hacer depende de este aviso.
void mostrarAviso(BuildContext context, String mensaje) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(mensaje),
        duration: const Duration(seconds: 6),
        showCloseIcon: true,
        closeIconColor: Theme.of(context).colorScheme.onInverseSurface,
      ),
    );
}
