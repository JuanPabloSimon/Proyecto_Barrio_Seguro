import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/sesion.dart';
import '../data/turnos_repositorio.dart';
import '../models/vecino.dart';
import '../theme/app_colors.dart';
import '../utils/fechas.dart';
import 'main_shell.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _nombre = TextEditingController();
  final _telefono = TextEditingController();
  final _calle = TextEditingController();
  final _cuadra = TextEditingController();
  final _nacimiento = TextEditingController();

  DateTime? _fechaNacimiento;
  bool _mostrarErrores = false;

  @override
  void dispose() {
    _nombre.dispose();
    _telefono.dispose();
    _calle.dispose();
    _cuadra.dispose();
    _nacimiento.dispose();
    super.dispose();
  }

  void _crearCuenta() {
    if (_nombre.text.trim().isEmpty || _fechaNacimiento == null) {
      setState(() => _mostrarErrores = true);
      return;
    }

    final hoy = DateTime.now();
    final cuadra = _cuadra.text.trim();
    Sesion.usuario = Vecino(
      id: 'vecino-${hoy.millisecondsSinceEpoch}',
      nombre: _nombre.text.trim(),
      fechaNacimiento: _fechaNacimiento!,
      telefono: _telefono.text.trim(),
      calle: _calle.text.trim(),
      cuadra: cuadra.isEmpty ? '' : 'Cuadra $cuadra',
      antiguedad: 'Se sumó en ${nombreMes(hoy.month)} de ${hoy.year}',
    );

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textoFecha = _nacimiento.text;
    final fechaIncompleta = textoFecha.length < 10;
    String? errorFecha;
    if (!fechaIncompleta && _fechaNacimiento == null) {
      errorFecha = 'Revisá la fecha';
    } else if (_mostrarErrores && _fechaNacimiento == null) {
      errorFecha = 'Ingresá tu fecha de nacimiento';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          const Text('Completá tus datos para sumarte a la red del barrio.'),
          const SizedBox(height: 24),
          TextField(
            controller: _nombre,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Nombre y apellido',
              prefixIcon: const Icon(Icons.badge_outlined),
              errorText: _mostrarErrores && _nombre.text.trim().isEmpty
                  ? 'Ingresá tu nombre'
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nacimiento,
            keyboardType: TextInputType.number,
            inputFormatters: [_FormatoFecha()],
            onChanged: (texto) => setState(() => _fechaNacimiento = parsearFecha(texto)),
            decoration: InputDecoration(
              labelText: 'Fecha de nacimiento',
              hintText: 'dd/mm/aaaa',
              prefixIcon: const Icon(Icons.cake_outlined),
              errorText: errorFecha,
            ),
          ),
          if (_fechaNacimiento != null) ...[
            const SizedBox(height: 12),
            _AvisoRol(edad: calcularEdad(_fechaNacimiento!)),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _telefono,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Teléfono',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _calle,
            decoration: const InputDecoration(
              labelText: 'Calle y número',
              prefixIcon: Icon(Icons.home_outlined),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _cuadra,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Cuadra',
              prefixIcon: Icon(Icons.signpost_outlined),
            ),
          ),
          const SizedBox(height: 16),
          const TextField(
            decoration: InputDecoration(
              labelText: 'Código de la comisión vecinal',
              helperText: 'Lo entrega la comisión para validar que vivís en el barrio.',
              helperMaxLines: 2,
              prefixIcon: Icon(Icons.verified_user_outlined),
            ),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _crearCuenta,
            child: const Text('Crear cuenta'),
          ),
        ],
      ),
    );
  }
}

/// Explica qué rol va a tener el vecino en los turnos según su edad.
class _AvisoRol extends StatelessWidget {
  const _AvisoRol({required this.edad});

  final int edad;

  @override
  Widget build(BuildContext context) {
    final esGuardia = edad >= Vecino.edadGuardiaVentana;
    final color = esGuardia ? AppColors.ventana : AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(esGuardia ? Icons.window_outlined : Icons.directions_walk, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  esGuardia
                      ? 'Vas a participar como guardia de ventana'
                      : 'Vas a participar en el patrullaje',
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  esGuardia
                      ? 'Por tener $edad años no salís a patrullar: vigilás desde tu casa. '
                          'En el calendario, todos los vecinos van a ver que tu turno es de guardia de ventana.'
                      : 'Tenés $edad años. Podés anotarte hasta '
                          '${TurnosRepositorio.maxTurnosPorMes} turnos de patrullaje por mes.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Agrega las barras automáticamente: 14051950 → 14/05/1950.
class _FormatoFecha extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digitos = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digitos.length > 8) digitos = digitos.substring(0, 8);

    final texto = StringBuffer();
    for (var i = 0; i < digitos.length; i++) {
      if (i == 2 || i == 4) texto.write('/');
      texto.write(digitos[i]);
    }

    final resultado = texto.toString();
    return TextEditingValue(
      text: resultado,
      selection: TextSelection.collapsed(offset: resultado.length),
    );
  }
}
