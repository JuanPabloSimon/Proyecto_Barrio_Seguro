import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'data/repositories/alertas_repository.dart';
import 'data/repositories/sesion_repository.dart';
import 'data/repositories/turnos_repository.dart';
import 'data/services/alertas_service.dart';
import 'data/services/bus_de_eventos.dart';
import 'data/services/http/alertas_service_http.dart';
import 'data/services/http/cliente_api.dart';
import 'data/services/http/turnos_service_http.dart';
import 'data/services/http/vecinos_service_http.dart';
import 'data/services/local/alertas_dao.dart';
import 'data/services/local/almacen_seguro.dart';
import 'data/services/local/pendientes_dao.dart';
import 'data/services/local/preferencias.dart';
import 'data/services/notificaciones_service.dart';
import 'data/services/local/turnos_dao.dart';
import 'data/services/reloj.dart';
import 'data/services/simulados/alertas_service_simulado.dart';
import 'data/services/simulados/servidor_simulado.dart';
import 'data/services/simulados/turnos_service_simulado.dart';
import 'data/services/simulados/vecinos_service_simulado.dart';
import 'data/services/tareas/tareas_service.dart';
import 'data/services/telefono_service.dart';
import 'data/services/turnos_service.dart';
import 'data/services/ubicacion_service.dart';
import 'data/services/vecinos_service.dart';
import 'plataforma/capacidades.dart';
import 'plataforma/politicas.dart';

/// Las piezas de la app, armadas una sola vez de abajo hacia arriba
/// (servicios → repositorios). Las pantallas las reciben por constructor
/// para crear sus ViewModels.
///
/// Hay dos formas de armarlas, y lo único que cambia son los servicios:
/// [Dependencias.simuladas] (sin internet) y [Dependencias.conApi] (el
/// backend de /backend). Ningún repositorio, ViewModel ni pantalla se
/// entera de cuál se usa.
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
    required this.ubicacion,
    required this.notificaciones,
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
    UbicacionService ubicacion = const UbicacionServiceGeolocator(),
    NotificacionesService notificaciones = const NotificacionesServiceNinguno(),
    TareasService tareas = const TareasNinguna(),
    Preferencias? preferencias,
    AlmacenSeguro? almacenSeguro,
    AlertasDao? alertasDao,
    TurnosDao? turnosDao,
    PendientesDao? pendientesDao,
  }) {
    final servidor = ServidorSimulado(
      reloj: reloj,
      demora: demora,
      probabilidadDeFallo: probabilidadDeFallo,
    );
    return Dependencias._armar(
      alertasService: AlertasServiceSimulado(servidor),
      turnosService: TurnosServiceSimulado(servidor),
      vecinosService: VecinosServiceSimulado(servidor),
      reloj: reloj,
      capacidades: capacidades,
      politicas: politicas,
      telefono: telefono,
      ubicacion: ubicacion,
      notificaciones: notificaciones,
      tareas: tareas,
      preferencias: preferencias,
      almacenSeguro: almacenSeguro,
      alertasDao: alertasDao,
      turnosDao: turnosDao,
      pendientesDao: pendientesDao,
    );
  }

  /// Los datos vienen de la API en [urlBase], por HTTP. Con [cliente] las
  /// pruebas pueden responder sin red.
  factory Dependencias.conApi({
    required Uri urlBase,
    http.Client? cliente,
    Reloj reloj = const RelojDelSistema(),
    Capacidades capacidades = const Capacidades(),
    Politicas politicas = const Politicas(),
    TelefonoService telefono = const TelefonoServiceUrlLauncher(),
    UbicacionService ubicacion = const UbicacionServiceGeolocator(),
    NotificacionesService notificaciones = const NotificacionesServiceNinguno(),
    TareasService tareas = const TareasNinguna(),
    Preferencias? preferencias,
    AlmacenSeguro? almacenSeguro,
    AlertasDao? alertasDao,
    TurnosDao? turnosDao,
    PendientesDao? pendientesDao,
  }) {
    final almacen =
        almacenSeguro ?? AlmacenSeguro(const FlutterSecureStorage());
    final api = ClienteApi(base: urlBase, almacen: almacen, cliente: cliente);
    return Dependencias._armar(
      alertasService: AlertasServiceHttp(api),
      turnosService: TurnosServiceHttp(api),
      vecinosService: VecinosServiceHttp(api),
      reloj: reloj,
      capacidades: capacidades,
      politicas: politicas,
      telefono: telefono,
      ubicacion: ubicacion,
      notificaciones: notificaciones,
      tareas: tareas,
      preferencias: preferencias,
      almacenSeguro: almacen,
      alertasDao: alertasDao,
      turnosDao: turnosDao,
      pendientesDao: pendientesDao,
    );
  }

  /// Arma los repositorios sobre los servicios que se elijan.
  factory Dependencias._armar({
    required AlertasService alertasService,
    required TurnosService turnosService,
    required VecinosService vecinosService,
    required Reloj reloj,
    required Capacidades capacidades,
    required Politicas politicas,
    required TelefonoService telefono,
    required UbicacionService ubicacion,
    required NotificacionesService notificaciones,
    required TareasService tareas,
    required Preferencias? preferencias,
    required AlmacenSeguro? almacenSeguro,
    required AlertasDao? alertasDao,
    required TurnosDao? turnosDao,
    required PendientesDao? pendientesDao,
  }) {
    final prefs = preferencias ?? Preferencias(SharedPreferencesAsync());
    return Dependencias(
      alertas: AlertasRepositoryRemoto(
        service: alertasService,
        dao: alertasDao,
        pendientes: pendientesDao,
        tareas: tareas,
        reloj: reloj,
      ),
      turnos: TurnosRepositoryRemoto(service: turnosService, dao: turnosDao),
      sesion: SesionRepositoryRemoto(
        service: vecinosService,
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
      ubicacion: ubicacion,
      notificaciones: notificaciones,
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

  /// El GPS del teléfono.
  final UbicacionService ubicacion;

  /// Avisos de alertas nuevas.
  final NotificacionesService notificaciones;
}
