import 'package:flutter/material.dart';

/// Muestra un aviso breve abajo de la pantalla.
///
/// Dura 6 segundos (más que el valor por defecto, para dar tiempo a leerlo)
/// y tiene un botón para cerrarlo. Se usa solo para confirmar algo que ya
/// pasó; nada que la persona necesite hacer depende de este aviso.
void mostrarAviso(BuildContext context, String mensaje) =>
    mostrarAvisoEn(ScaffoldMessenger.of(context), mensaje);

/// Igual que [mostrarAviso], para cuando el aviso se muestra después de un
/// `await`: el [ScaffoldMessengerState] se obtiene antes de esperar, porque
/// después la pantalla puede ya no existir.
void mostrarAvisoEn(ScaffoldMessengerState mensajero, String mensaje) {
  final tema = Theme.of(mensajero.context);
  mensajero
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(mensaje),
        duration: const Duration(seconds: 6),
        showCloseIcon: true,
        closeIconColor: tema.colorScheme.onInverseSurface,
      ),
    );
}
