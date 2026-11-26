import 'models/alerta.dart';

/// Reglas para crear una alerta nueva. Son las mismas que aplica el
/// servidor (backend/lib/src/reglas.dart), con los mismos mensajes: el
/// servidor las vuelve a aplicar porque no puede confiar solo en la app.
/// Si cambia una regla, hay que cambiarla en los dos lados.
class ReglasAlertas {
  ReglasAlertas._();

  static const maxTitulo = 60;
  static const maxDescripcion = 500;
  static const maxDireccion = 120;

  static const mensajeCategoria = 'Elegí qué tipo de alerta es.';
  static const mensajeTituloVacio = 'Escribí un título para la alerta.';
  static const mensajeTituloLargo =
      'Acortá el título: puede tener hasta $maxTitulo letras.';
  static const mensajeDescripcionLarga =
      'Acortá la descripción: puede tener hasta $maxDescripcion letras.';
  static const mensajeDireccionLarga =
      'Acortá la dirección: puede tener hasta $maxDireccion letras.';

  /// Las que acepta el servidor: `sos` (botón SOS) y
  /// [CategoriaAlerta.paraReportar]. Arrebato queda afuera: solo se lee.
  static final Set<String> categoriasAceptadas = {
    CategoriaAlerta.sos.valorApi,
    for (final categoria in CategoriaAlerta.paraReportar) categoria.valorApi,
  };

  /// Letras sin los espacios de los extremos. Se cuentan runas, igual que
  /// el servidor (que corre con Dart puro).
  static int largo(String texto) => texto.trim().runes.length;

  static String? errorTitulo(String titulo) {
    if (titulo.trim().isEmpty) return mensajeTituloVacio;
    if (largo(titulo) > maxTitulo) return mensajeTituloLargo;
    return null;
  }

  static String? errorDescripcion(String descripcion) =>
      largo(descripcion) > maxDescripcion ? mensajeDescripcionLarga : null;

  static String? errorDireccion(String direccion) =>
      largo(direccion) > maxDireccion ? mensajeDireccionLarga : null;

  /// El primer motivo para rechazar una alerta nueva, o null si es válida.
  /// Orden: categoría, título, descripción, dirección. Lo usa el servidor
  /// simulado (y el backend tiene la copia).
  static String? motivoRechazo({
    required String categoria,
    required String tipo,
    required String descripcion,
    required String direccion,
  }) {
    if (!categoriasAceptadas.contains(categoria)) return mensajeCategoria;
    return errorTitulo(tipo) ??
        errorDescripcion(descripcion) ??
        errorDireccion(direccion);
  }
}
