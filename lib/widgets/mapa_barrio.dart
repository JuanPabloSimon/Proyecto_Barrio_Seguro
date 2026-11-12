import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../data/barrio.dart';
import '../models/alerta.dart';
import '../theme/app_colors.dart';
import 'objetivo_tactil.dart';
import 'pin_alerta.dart';

/// Qué muestra el mapa al abrirse.
enum EncuadreMapa {
  /// Todo el círculo del radio de alertas.
  radio,

  /// Las alertas (y el vecino, si se muestra) lo más cerca posible.
  alertas,
}

/// Mapa real del barrio con calles de OpenStreetMap, los pines de las
/// alertas, la posición del vecino y el círculo del radio de alertas.
///
/// Si recibe [onAlertaTap], el mapa se puede mover y cada pin es un botón de
/// 48 dp con etiqueta para lectores de pantalla. Si no, es una vista previa
/// quieta: no recibe toques, así que los recibe la tarjeta que lo contiene.
class MapaBarrio extends StatelessWidget {
  const MapaBarrio({
    super.key,
    required this.alertas,
    this.onAlertaTap,
    this.controlador,
    this.encuadre = EncuadreMapa.radio,
    this.mostrarRadio = true,
    this.mostrarUsuario = true,
    this.tamanioPin = 32,
    this.margen = const EdgeInsets.all(16),
  });

  /// Los tests lo desactivan para no descargar calles de internet.
  static bool cargarCalles = true;

  /// Límites de acercamiento: de un barrio entero a una cuadra.
  static const zoomMinimo = 13.0;
  static const zoomMaximo = 19.0;

  final List<Alerta> alertas;
  final ValueChanged<Alerta>? onAlertaTap;
  final MapController? controlador;
  final EncuadreMapa encuadre;
  final bool mostrarRadio;
  final bool mostrarUsuario;
  final double tamanioPin;

  /// Espacio libre al encuadrar; por ejemplo, abajo para que el botón SOS no
  /// tape los pines.
  final EdgeInsets margen;

  /// Por ahora es el centro del barrio; con el GPS será la posición real.
  LatLng get ubicacionUsuario => Barrio.centro;

  /// Etiqueta que lee el lector de pantalla para cada pin.
  static String etiquetaDe(Alerta alerta) =>
      'Alerta: ${alerta.tipo}, ${alerta.estado.etiqueta.toLowerCase()}, '
      '${alerta.direccion}. Ver resumen';

  CameraFit get _encuadreInicial {
    if (encuadre == EncuadreMapa.alertas && alertas.isNotEmpty) {
      return CameraFit.coordinates(
        coordinates: [
          for (final alerta in alertas) alerta.ubicacion,
          if (mostrarUsuario) ubicacionUsuario,
        ],
        padding: margen,
        maxZoom: 16,
      );
    }
    return CameraFit.bounds(bounds: Barrio.limitesDelRadio, padding: margen);
  }

  @override
  Widget build(BuildContext context) {
    final interactivo = onAlertaTap != null;
    final sinAnimaciones = MediaQuery.disableAnimationsOf(context);

    final mapa = FlutterMap(
      mapController: controlador,
      options: MapOptions(
        initialCameraFit: _encuadreInicial,
        minZoom: zoomMinimo,
        maxZoom: zoomMaximo,
        backgroundColor: AppColors.mapaFondo,
        interactionOptions: InteractionOptions(
          // Sin rotación: un mapa girado confunde, sobre todo a personas mayores.
          flags: interactivo
              ? InteractiveFlag.all & ~InteractiveFlag.rotate
              : InteractiveFlag.none,
        ),
      ),
      children: [
        if (cargarCalles)
          TileLayer(
            urlTemplate: Barrio.urlCalles,
            userAgentPackageName: Barrio.identificadorApp,
            tileDisplay: sinAnimaciones
                ? const TileDisplay.instantaneous()
                : const TileDisplay.fadeIn(),
          ),
        if (mostrarRadio)
          CircleLayer(
            circles: [
              CircleMarker(
                point: Barrio.centro,
                radius: Barrio.radioAlertasMetros,
                useRadiusInMeter: true,
                color: AppColors.radio.withValues(alpha: 0.08),
                borderColor: AppColors.radio,
                borderStrokeWidth: 2,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            if (mostrarUsuario)
              Marker(
                point: ubicacionUsuario,
                width: 26,
                height: 26,
                child: const _MarcadorUsuario(),
              ),
            for (final alerta in alertas) _marcador(alerta),
          ],
        ),
        const _Atribucion(),
      ],
    );

    return interactivo ? mapa : IgnorePointer(child: mapa);
  }

  Marker _marcador(Alerta alerta) {
    final pin = PinAlerta(estado: alerta.estado, diametro: tamanioPin);
    final tocar = onAlertaTap;

    if (tocar == null) {
      return Marker(
        point: alerta.ubicacion,
        width: tamanioPin,
        height: tamanioPin,
        child: pin,
      );
    }

    // El pin se ve de [tamanioPin], pero se toca en un área de 48 dp.
    return Marker(
      point: alerta.ubicacion,
      width: ObjetivoTactil.tamanioMinimo,
      height: ObjetivoTactil.tamanioMinimo,
      child: ObjetivoTactil(
        etiqueta: etiquetaDe(alerta),
        onTap: () => tocar(alerta),
        child: pin,
      ),
    );
  }
}

/// Posición del vecino: círculo blanco con borde y ícono azules.
class _MarcadorUsuario extends StatelessWidget {
  const _MarcadorUsuario();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.superficie,
        border: Border.all(color: AppColors.radio, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: const Icon(Icons.my_location, size: 14, color: AppColors.radio),
    );
  }
}

/// Crédito que exige la licencia de OpenStreetMap.
class _Atribucion extends StatelessWidget {
  const _Atribucion();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.superficie,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          '© OpenStreetMap',
          style: TextStyle(fontSize: 14, color: AppColors.texto),
        ),
      ),
    );
  }
}
