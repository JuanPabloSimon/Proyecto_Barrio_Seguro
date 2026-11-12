import 'data/repositories/alertas_repository.dart';
import 'data/repositories/sesion_repository.dart';
import 'data/repositories/turnos_repository.dart';
import 'data/services/bus_de_eventos.dart';
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
  });

  /// Los datos vienen del [ServidorSimulado], sin internet. Las
  /// capacidades, las políticas y el teléfono son los verdaderos, salvo que
  /// una prueba pase otros.
  factory Dependencias.simuladas({
    Reloj reloj = const RelojDelSistema(),
    Duration demora = const Duration(milliseconds: 400),
    double probabilidadDeFallo = 0,
    Capacidades capacidades = const Capacidades(),
    Politicas politicas = const Politicas(),
    TelefonoService telefono = const TelefonoServiceUrlLauncher(),
  }) {
    final servidor = ServidorSimulado(
      reloj: reloj,
      demora: demora,
      probabilidadDeFallo: probabilidadDeFallo,
    );
    return Dependencias(
      alertas: AlertasRepositoryRemoto(
        service: AlertasServiceSimulado(servidor),
      ),
      turnos: TurnosRepositoryRemoto(service: TurnosServiceSimulado(servidor)),
      sesion: SesionRepositoryRemoto(service: VecinosServiceSimulado(servidor)),
      bus: BusDeEventos(),
      reloj: reloj,
      // Mes que muestra el calendario de turnos en el prototipo.
      mesDeTurnos: DateTime(2026, 10),
      capacidades: capacidades,
      politicas: politicas,
      telefono: telefono,
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
}
