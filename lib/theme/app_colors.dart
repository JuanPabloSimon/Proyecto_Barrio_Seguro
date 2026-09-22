import 'package:flutter/material.dart';

/// Paleta de la app. Cuando Carla pase los valores finales del Figma,
/// se cambian solo acá y se actualiza toda la app.
class AppColors {
  AppColors._();

  static const primary = Color(0xFF1F3A5F);
  static const alerta = Color(0xFFF28C28); // naranja: alertas activas
  static const emergencia = Color(0xFFD62828); // rojo: SOS y emergencias
  static const resuelta = Color(0xFF2E9E5B);
  static const radio = Color(0xFF2F80ED); // círculo azul del radio del usuario

  static const fondo = Color(0xFFF4F6F9);
  static const superficie = Colors.white;
  static const borde = Color(0xFFE1E6ED);
  static const texto = Color(0xFF1B2430);
  static const textoSecundario = Color(0xFF5C6778);
}
