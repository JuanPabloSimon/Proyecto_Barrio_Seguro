import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Transición entre pantallas que respeta la opción del sistema "Quitar
/// animaciones" (MediaQuery.disableAnimations): si está activa, la pantalla
/// nueva aparece directamente; si no, usa la transición normal.
class TransicionAccesible extends PageTransitionsBuilder {
  const TransicionAccesible(this.normal);

  final PageTransitionsBuilder normal;

  @override
  Duration get transitionDuration => normal.transitionDuration;

  @override
  Duration get reverseTransitionDuration => normal.reverseTransitionDuration;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return normal.buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}

/// Transiciones de la app para cada plataforma.
const transicionesAccesibles = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: TransicionAccesible(
      PredictiveBackPageTransitionsBuilder(),
    ),
    TargetPlatform.iOS: TransicionAccesible(CupertinoPageTransitionsBuilder()),
    TargetPlatform.macOS: TransicionAccesible(
      CupertinoPageTransitionsBuilder(),
    ),
    TargetPlatform.windows: TransicionAccesible(ZoomPageTransitionsBuilder()),
    TargetPlatform.linux: TransicionAccesible(ZoomPageTransitionsBuilder()),
  },
);
