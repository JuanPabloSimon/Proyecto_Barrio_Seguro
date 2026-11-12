import 'package:BarrioSeguro/data/services/reloj.dart';
import 'package:BarrioSeguro/dependencias.dart';
import 'package:BarrioSeguro/main.dart';
import 'package:BarrioSeguro/ui/core/widgets/mapa_barrio.dart';

/// Hora fija para todas las pruebas: así las edades y los "hace 5 minutos"
/// dan siempre lo mismo, sin importar cuándo se corran.
final relojDePrueba = RelojFijo(DateTime(2026, 10, 1, 12));

/// La app completa contra el servidor simulado, sin demoras ni internet.
/// Cada llamada arma dependencias nuevas: una prueba no ve los cambios de
/// otra.
BarrioSeguroApp appDePrueba() {
  MapaBarrio.cargarCalles = false;
  return BarrioSeguroApp(
    dependencias: Dependencias.simuladas(
      reloj: relojDePrueba,
      demora: Duration.zero,
    ),
  );
}
