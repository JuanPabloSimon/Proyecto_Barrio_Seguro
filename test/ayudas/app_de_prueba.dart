import 'package:BarrioSeguro/data/services/reloj.dart';
import 'package:BarrioSeguro/data/services/telefono_service.dart';
import 'package:BarrioSeguro/data/services/ubicacion_service.dart';
import 'package:BarrioSeguro/dependencias.dart';
import 'package:BarrioSeguro/main.dart';
import 'package:BarrioSeguro/plataforma/capacidades.dart';
import 'package:BarrioSeguro/plataforma/politicas.dart';
import 'package:BarrioSeguro/ui/core/widgets/mapa_barrio.dart';

import 'bases_de_prueba.dart';
import 'falsos.dart';

/// Hora fija para todas las pruebas: así las edades y los "hace 5 minutos"
/// dan siempre lo mismo, sin importar cuándo se corran.
final relojDePrueba = RelojFijo(DateTime(2026, 10, 1, 12));

/// La app completa contra el servidor simulado, sin demoras ni internet.
/// Cada llamada arma dependencias nuevas: una prueba no ve los cambios de
/// otra.
///
/// Las capacidades y políticas son falsas: la prueba decide qué puede y
/// qué debe hacer la app, sin importar en qué computadora corre. El
/// teléfono también es falso, para que "Llamar" no intente abrir nada.
///
/// Las preferencias y el almacenamiento seguro arrancan vacíos y en
/// memoria: la app abre en el login, como la primera vez.
BarrioSeguroApp appDePrueba({
  Capacidades capacidades = const CapacidadesFalsas(),
  Politicas politicas = const PoliticasFalsas(),
  TelefonoService? telefono,
  UbicacionService? ubicacion,
}) {
  MapaBarrio.cargarCalles = false;
  return BarrioSeguroApp(
    dependencias: Dependencias.simuladas(
      reloj: relojDePrueba,
      demora: Duration.zero,
      capacidades: capacidades,
      politicas: politicas,
      telefono: telefono ?? TelefonoFalso(),
      ubicacion: ubicacion ?? UbicacionFalsa(),
      preferencias: preferenciasEnMemoria(),
      almacenSeguro: almacenSeguroEnMemoria(),
    ),
  );
}
