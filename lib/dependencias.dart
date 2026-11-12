import 'data/repositories/alertas_repository.dart';
import 'data/repositories/sesion_repository.dart';
import 'data/repositories/turnos_repository.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/services/bus_de_eventos.dart';
import 'data/services/local/alertas_dao.dart';
import 'data/services/local/almacen_seguro.dart';
import 'data/services/local/preferencias.dart';
import 'data/services/local/turnos_dao.dart';
import 'data/services/reloj.dart';
import 'data/services/simulados/alertas_service_simulado.dart';
import 'data/services/simulados/servidor_simulado.dart';
import 'data/services/simulados/turnos_service_simulado.dart';
import 'data/services/simulados/vecinos_service_simulado.dart';
import 'data/services/telefono_service.dart';
import 'plataforma/capacidades.dart';
import 'plataforma/politicas.dart';

/// Las piezas de la app, armadas una sola vez de abajo hacia arriba
/// (servicios → repositorios). Las pantallas las reciben por constructor
/// para crear sus ViewModels.
///
/// Para conectar la API real alcanza con armar otra `Dependencias` con los
/// servicios HTTP: ningún ViewModel ni pantalla cambia.
class Dependencias {
  Dependencias({
    required this.alertas,
    required this.turnos,
    required this.sesion,
    required this.bus,
    required this.reloj,
    required this.mesDeTurnos,
    required this.capacidades,
    required this.politicas,
    required this.telefono,
    required this.preferencias,
  });

  /// Los datos vienen del [ServidorSimulado], sin internet. Las
  /// capacidades, las políticas, el teléfono y el almacenamiento son los
  /// verdaderos, salvo que una prueba pase otros.
  ///
  /// Con [alertasDao] y [turnosDao] se guarda una copia en el teléfono para
  /// usar sin conexión; sin ellos (en la web o en pruebas), solo memoria.
  factory Dependencias.simuladas({
    Reloj reloj = const RelojDelSistema(),
    Duration demora = const Duration(milliseconds: 400),
    double probabilidadDeFallo = 0,
    Capacidades capacidades = const Capacidades(),
    Politicas politicas = const Politicas(),
    TelefonoService telefono = const TelefonoServiceUrlLauncher(),
    Preferencias? preferencias,
    AlmacenSeguro? almacenSeguro,
    AlertasDao? alertasDao,
    TurnosDao? turnosDao,
  }) {
    final prefs = preferencias ?? Preferencias(SharedPreferencesAsync());
    final servidor = ServidorSimulado(
      reloj: reloj,
      demora: demora,
      probabilidadDeFallo: probabilidadDeFallo,
    );
    return Dependencias(
      alertas: AlertasRepositoryRemoto(
        service: AlertasServiceSimulado(servidor),
        dao: alertasDao,
      ),
      turnos: TurnosRepositoryRemoto(
        service: TurnosServiceSimulado(servidor),
        dao: turnosDao,
      ),
      sesion: SesionRepositoryRemoto(
        service: VecinosServiceSimulado(servidor),
        preferencias: prefs,
        almacen: almacenSeguro ?? AlmacenSeguro(const FlutterSecureStorage()),
      ),
      bus: BusDeEventos(),
      reloj: reloj,
      // Mes que muestra el calendario de turnos en el prototipo.
      mesDeTurnos: DateTime(2026, 10),
      capacidades: capacidades,
      politicas: politicas,
      telefono: telefono,
      preferencias: prefs,
    );
  }

  final AlertasRepository alertas;
  final TurnosRepository turnos;
  final SesionRepository sesion;
  final BusDeEventos bus;
  final Reloj reloj;
  final DateTime mesDeTurnos;

  /// Lo que el dispositivo puede hacer.
  final Capacidades capacidades;

  /// Lo que la app debe hacer en cada plataforma.
  final Politicas politicas;

  final TelefonoService telefono;

  /// Ajustes del vecino que sobreviven al cierre de la app.
  final Preferencias preferencias;
}
