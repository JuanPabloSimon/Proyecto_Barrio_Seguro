import 'package:flutter/material.dart';

/// Paleta de la app. Todos los colores se definen acá y cada combinación
/// de texto o componente sobre un fondo queda registrada en
/// [AppColors.paresDeContraste], que verifica el test de accesibilidad.
///
/// Mínimos (WCAG 2.1 AA):
/// - Texto normal: 4.5:1.
/// - Texto grande (18 sp, o 14 sp en negrita): 3:1.
/// - Íconos, bordes de campos y otros componentes: 3:1.
class AppColors {
  AppColors._();

  // Marca
  static const primary = Color(0xFF1F3A5F);

  // Estados de alerta. Son lo bastante oscuros para llevar texto blanco
  // encima y para distinguirse sobre el mapa.
  static const emergencia = Color(0xFFC62828); // rojo: SOS, alertas activas
  static const alerta = Color(0xFFB54708); // naranja: banner, en atención
  static const resuelta = Color(0xFF1E7A46); // verde: resueltas

  static const radio = Color(0xFF1D6FD8); // posición y radio del usuario
  static const ventana = Color(0xFF6A4C93); // guardia de ventana (mayores de 70)

  // Fondos suaves opacos (en vez de transparencias) para poder verificar
  // el contraste del texto que va encima.
  static const primarioSuave = Color(0xFFE9EBEF);
  static const ventanaSuave = Color(0xFFF3F1F6);
  static const emergenciaSuave = Color(0xFFF8E5E5);
  static const alertaSuave = Color(0xFFF6E9E1);
  static const resueltaSuave = Color(0xFFE4EFE9);

  // Neutros
  static const fondo = Color(0xFFF4F6F9);
  static const superficie = Colors.white;
  static const texto = Color(0xFF1B2430);
  static const textoSecundario = Color(0xFF5C6778);
  static const sobreColor = Colors.white; // texto sobre colores sólidos

  /// Borde decorativo de tarjetas: no identifica un componente, no necesita 3:1.
  static const borde = Color(0xFFE1E6ED);

  /// Borde de campos de texto y contornos de componentes: necesita 3:1.
  static const bordeCampo = Color(0xFF7D8796);

  static const mapaFondo = Color(0xFFE9ECE6);

  /// Combinaciones usadas en la app con su contraste mínimo exigido.
  static const paresDeContraste = <ParContraste>[
    ParContraste('Texto sobre fondo', texto, fondo, ParContraste.textoNormal),
    ParContraste('Texto sobre superficie', texto, superficie, ParContraste.textoNormal),
    ParContraste('Texto secundario sobre fondo', textoSecundario, fondo, ParContraste.textoNormal),
    ParContraste('Texto secundario sobre superficie', textoSecundario, superficie, ParContraste.textoNormal),
    ParContraste('Texto sobre botón primario', sobreColor, primary, ParContraste.textoNormal),
    ParContraste('Texto sobre rojo de emergencia', sobreColor, emergencia, ParContraste.textoNormal),
    ParContraste('Texto sobre banner naranja', sobreColor, alerta, ParContraste.textoNormal),
    ParContraste('Texto sobre verde de resuelta', sobreColor, resuelta, ParContraste.textoNormal),
    ParContraste('Texto sobre violeta de guardia', sobreColor, ventana, ParContraste.textoNormal),
    ParContraste('Rojo de emergencia sobre superficie', emergencia, superficie, ParContraste.textoNormal),
    ParContraste('Rojo de emergencia sobre fondo', emergencia, fondo, ParContraste.textoNormal),
    ParContraste('Primario sobre fondo', primary, fondo, ParContraste.textoNormal),
    ParContraste('Primario sobre primario suave', primary, primarioSuave, ParContraste.textoNormal),
    ParContraste('Texto sobre primario suave', texto, primarioSuave, ParContraste.textoNormal),
    ParContraste('Texto secundario sobre primario suave', textoSecundario, primarioSuave, ParContraste.textoNormal),
    ParContraste('Violeta sobre violeta suave', ventana, ventanaSuave, ParContraste.textoNormal),
    ParContraste('Texto sobre violeta suave', texto, ventanaSuave, ParContraste.textoNormal),
    ParContraste('Ícono rojo sobre rojo suave', emergencia, emergenciaSuave, ParContraste.componente),
    ParContraste('Ícono naranja sobre naranja suave', alerta, alertaSuave, ParContraste.componente),
    ParContraste('Ícono verde sobre verde suave', resuelta, resueltaSuave, ParContraste.componente),
    ParContraste('Borde de campo sobre superficie', bordeCampo, superficie, ParContraste.componente),
    ParContraste('Borde de campo sobre fondo', bordeCampo, fondo, ParContraste.componente),
    ParContraste('Pin rojo sobre el mapa', emergencia, mapaFondo, ParContraste.componente),
    ParContraste('Pin naranja sobre el mapa', alerta, mapaFondo, ParContraste.componente),
    ParContraste('Pin verde sobre el mapa', resuelta, mapaFondo, ParContraste.componente),
    ParContraste('Posición del usuario sobre el mapa', radio, mapaFondo, ParContraste.componente),
  ];
}

/// Un color usado sobre otro, con el contraste mínimo que tiene que cumplir.
class ParContraste {
  const ParContraste(this.descripcion, this.frente, this.fondo, this.minimo);

  static const textoNormal = 4.5;
  static const textoGrande = 3.0;
  static const componente = 3.0;

  final String descripcion;
  final Color frente;
  final Color fondo;
  final double minimo;

  double get ratio => contraste(frente, fondo);

  bool get cumple => ratio >= minimo;
}

/// Relación de contraste WCAG entre dos colores opacos (de 1 a 21).
double contraste(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final claro = la > lb ? la : lb;
  final oscuro = la > lb ? lb : la;
  return (claro + 0.05) / (oscuro + 0.05);
}
