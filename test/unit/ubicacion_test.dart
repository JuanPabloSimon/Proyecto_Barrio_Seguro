// Pruebas de la ubicación real: el SOS y el permiso del perfil, con un GPS
// falso que decide la prueba.

import 'package:barrio_seguro/data/services/bus_de_eventos.dart';
import 'package:barrio_seguro/data/services/local/preferencias.dart';
import 'package:barrio_seguro/data/services/ubicacion_service.dart';
import 'package:barrio_seguro/domain/barrio.dart';
import 'package:barrio_seguro/ui/perfil/view_models/perfil_view_model.dart';
import 'package:barrio_seguro/ui/sos/view_models/sos_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import '../ayudas/app_de_prueba.dart';
import '../ayudas/bases_de_prueba.dart';
import '../ayudas/falsos.dart';

void main() {
  late Preferencias preferencias;
  late UbicacionFalsa gps;
  late AlertasFalsas alertas;

  setUp(() {
    preferencias = preferenciasEnMemoria();
    gps = UbicacionFalsa(posicion: const LatLng(-32.8771, -68.8699));
    alertas = AlertasFalsas();
  });

  SosViewModel sos({
    CapacidadesFalsas capacidades = const CapacidadesFalsas(),
  }) => SosViewModel(
    alertas: alertas,
    sesion: SesionFalsa(vecinaDePrueba),
    bus: BusDeEventos(),
    preferencias: preferencias,
    ubicacion: gps,
    capacidades: capacidades,
  );

  group('SOS', () {
    test('si el vecino aceptó, manda la posición del GPS', () async {
      await preferencias.guardarCompartirUbicacion(true);
      final vm = sos();
      await vm.enviar();

      expect(vm.paso, PasoSos.enviada);
      expect(vm.conUbicacionExacta, isTrue);
      expect(
        alertas.ubicacionesEnviadas.single,
        const LatLng(-32.8771, -68.8699),
      );
    });

    test('si no aceptó, manda la zona del barrio y no toca el GPS', () async {
      final vm = sos();
      await vm.enviar();

      expect(vm.conUbicacionExacta, isFalse);
      expect(alertas.ubicacionesEnviadas.single, Barrio.centro);
      expect(gps.posicionesPedidas, 0);
    });

    test('si el GPS no responde a tiempo, igual se envía', () async {
      await preferencias.guardarCompartirUbicacion(true);
      gps.posicion = null;
      final vm = sos();
      await vm.enviar();

      expect(vm.paso, PasoSos.enviada);
      expect(alertas.ubicacionesEnviadas.single, Barrio.centro);
    });

    test('sin GPS en el dispositivo, manda la zona del barrio', () async {
      await preferencias.guardarCompartirUbicacion(true);
      final vm = sos(capacidades: const CapacidadesFalsas(tieneGps: false));
      await vm.enviar();

      expect(alertas.ubicacionesEnviadas.single, Barrio.centro);
      expect(gps.posicionesPedidas, 0);
    });
  });

  group('Permiso desde el perfil', () {
    PerfilViewModel perfil() => PerfilViewModel(
      sesion: SesionFalsa(vecinaDePrueba),
      bus: BusDeEventos(),
      reloj: relojDePrueba,
      capacidades: const CapacidadesFalsas(),
      politicas: const PoliticasFalsas(),
      preferencias: preferencias,
      ubicacion: gps,
      notificacionesService: NotificacionesFalsas(),
    );

    test('con permiso, la ubicación queda activada y guardada', () async {
      final vm = perfil();
      expect(await vm.activarUbicacion(), isNull);
      expect(vm.compartirUbicacion, isTrue);
      expect(await preferencias.compartirUbicacion(), isTrue);
    });

    test('sin permiso, queda apagada y explica qué pasa', () async {
      gps.permiso = PermisoUbicacion.denegado;
      final vm = perfil();
      expect(await vm.activarUbicacion(), contains('zona aproximada'));
      expect(vm.compartirUbicacion, isFalse);
      expect(vm.permisoBloqueado, isFalse);
    });

    test('con el permiso bloqueado, ofrece ir a los ajustes', () async {
      gps.permiso = PermisoUbicacion.denegadoParaSiempre;
      final vm = perfil();
      expect(await vm.activarUbicacion(), contains('ajustes'));
      expect(vm.permisoBloqueado, isTrue);

      await vm.abrirAjustes();
      expect(gps.ajustesAbiertos, 1);
    });

    test('con el GPS apagado, pide prenderlo', () async {
      gps.permiso = PermisoUbicacion.servicioApagado;
      expect(await perfil().activarUbicacion(), contains('apagada'));
    });
  });
}
