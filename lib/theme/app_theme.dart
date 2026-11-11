import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'transiciones.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    // Los colores que llevan texto se fijan explícitamente para que su
    // contraste sea el verificado en AppColors.paresDeContraste.
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      onPrimary: AppColors.sobreColor,
      error: AppColors.emergencia,
      onError: AppColors.sobreColor,
      surface: AppColors.superficie,
      onSurface: AppColors.texto,
      onSurfaceVariant: AppColors.textoSecundario,
      outline: AppColors.bordeCampo,
      outlineVariant: AppColors.borde,
    );

    final bordeCampo = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.bordeCampo),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.fondo,
      pageTransitionsTheme: transicionesAccesibles,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.fondo,
        foregroundColor: AppColors.texto,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        // 20 sp: con el texto del sistema agrandado, Flutter escala el título
        // hasta 1,34x; así los títulos siguen entrando en una línea.
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.texto,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.superficie,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borde),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: AppColors.superficie,
        border: bordeCampo,
        enabledBorder: bordeCampo,
        focusedBorder: bordeCampo.copyWith(
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.superficie,
        indicatorColor: AppColors.primary.withValues(alpha: 0.12),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
