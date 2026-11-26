import 'dart:convert';

import 'package:barrio_seguro/data/services/conexion_service.dart';
import 'package:barrio_seguro/data/services/descarga_csv_service.dart';
import 'package:barrio_seguro/data/services/local/preferencias.dart';
import 'package:barrio_seguro/data/services/notificaciones_service.dart';
import 'package:barrio_seguro/data/services/push_service.dart';
import 'package:barrio_seguro/data/services/reloj.dart';
import 'package:barrio_seguro/data/services/telefono_service.dart';
import 'package:barrio_seguro/data/services/ubicacion_service.dart';
import 'package:barrio_seguro/dependencias.dart';
import 'package:barrio_seguro/main.dart';
import 'package:barrio_seguro/plataforma/capacidades.dart';
import 'package:barrio_seguro/plataforma/politicas.dart';
import 'package:barrio_seguro/ui/core/widgets/mapa_barrio.dart';

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
///
/// Con [conexion] la prueba decide si la app llega al servidor (por
/// defecto, siempre conectada).
///
/// Con [llegadas] (id de alerta → hora de llegada del aviso) el teléfono
/// arranca con esos avisos ya recibidos, para ver alertas tardías.
BarrioSeguroApp appDePrueba({
  Capacidades capacidades = const CapacidadesFalsas(),
  Politicas politicas = const PoliticasFalsas(),
  TelefonoService? telefono,
  UbicacionService? ubicacion,
  NotificacionesService? notificaciones,
  PushService? push,
  ConexionService? conexion,
  DescargaCsvService? descargaCsv,
  Map<String, DateTime> llegadas = const {},
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
      notificaciones: notificaciones ?? NotificacionesFalsas(),
      push: push ?? PushFalso(),
      conexion: conexion,
      descargaCsv: descargaCsv ?? DescargaCsvFalsa(),
      preferencias: preferenciasEnMemoria({
        if (llegadas.isNotEmpty)
          Preferencias.claveAvisosRecibidos: jsonEncode({
            for (final MapEntry(:key, :value) in llegadas.entries)
              key: value.millisecondsSinceEpoch,
          }),
      }),
      almacenSeguro: almacenSeguroEnMemoria(),
    ),
  );
}
