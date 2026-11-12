import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../dependencias.dart';
import '../../../domain/reglas_turnos.dart';
import '../../core/estado_carga.dart';
import '../../core/tema/app_colors.dart';
import '../../principal/widgets/principal_screen.dart';
import '../view_models/registro_view_model.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({
    super.key,
    required this.viewModel,
    required this.dependencias,
  });

  final RegistroViewModel viewModel;
  final Dependencias dependencias;

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

/// Los TextEditingController son de la vista (son widgets de entrada); los
/// datos y las validaciones viven en el ViewModel.
class _RegistroScreenState extends State<RegistroScreen> {
  final _nombre = TextEditingController();
  final _nacimiento = TextEditingController();
  final _telefono = TextEditingController();
  final _calle = TextEditingController();
  final _cuadra = TextEditingController();
  final _codigo = TextEditingController();
  final _clave = TextEditingController();

  RegistroViewModel get _vm => widget.viewModel;

  @override
  void dispose() {
    _nombre.dispose();
    _nacimiento.dispose();
    _telefono.dispose();
    _calle.dispose();
    _cuadra.dispose();
    _codigo.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _crearCuenta() async {
    final ok = await _vm.registrar(
      telefono: _telefono.text,
      calle: _calle.text,
      cuadra: _cuadra.text,
      codigoComision: _codigo.text,
      clave: _clave.text,
    );
    if (!ok || !mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => PrincipalScreen(dependencias: widget.dependencias),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) => _formulario(),
      ),
    );
  }

  Widget _formulario() {
    final edad = _vm.edad;
    final cargando = _vm.estado == EstadoCarga.cargando;
    final errorDelServidor = _vm.errorDelServidor;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        const Text('Completá tus datos para sumarte a la red del barrio.'),
        const SizedBox(height: 24),
        TextField(
          controller: _nombre,
          textCapitalization: TextCapitalization.words,
          onChanged: _vm.cambiarNombre,
          decoration: InputDecoration(
            labelText: 'Nombre y apellido',
            prefixIcon: const Icon(Icons.badge_outlined),
            errorText: _vm.errorNombre,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _nacimiento,
          keyboardType: TextInputType.number,
          inputFormatters: [_FormatoFecha()],
          onChanged: _vm.cambiarFecha,
          decoration: InputDecoration(
            labelText: 'Fecha de nacimiento',
            hintText: 'dd/mm/aaaa',
            prefixIcon: const Icon(Icons.cake_outlined),
            errorText: _vm.errorFecha,
            errorMaxLines: 4,
          ),
        ),
        if (edad != null) ...[
          const SizedBox(height: 12),
          // Se anuncia al aparecer: el rol depende de la fecha ingresada.
          Semantics(
            container: true,
            liveRegion: true,
            child: _AvisoRol(edad: edad, esGuardia: _vm.seraGuardiaVentana),
          ),
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
        TextField(
          controller: _codigo,
          decoration: const InputDecoration(
            labelText: 'Código de la comisión vecinal',
            helperText:
                'Lo entrega la comisión para validar que vivís en el barrio.',
            helperMaxLines: 4,
            prefixIcon: Icon(Icons.verified_user_outlined),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _clave,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Contraseña',
            helperText:
                'Al menos ${RegistroViewModel.largoMinimoClave} caracteres. '
                'La vas a usar con tu teléfono para ingresar.',
            helperMaxLines: 4,
            errorText: _vm.errorClave,
            errorMaxLines: 4,
            prefixIcon: const Icon(Icons.lock_outline),
          ),
        ),
        const SizedBox(height: 32),
        if (errorDelServidor != null) ...[
          Semantics(
            liveRegion: true,
            child: Text(
              errorDelServidor,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.emergencia),
            ),
          ),
          const SizedBox(height: 12),
        ],
        FilledButton(
          onPressed: cargando ? null : _crearCuenta,
          child: cargando
              ? const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(
                    semanticsLabel: 'Creando la cuenta',
                  ),
                )
              : const Text('Crear cuenta'),
        ),
      ],
    );
  }
}

/// Explica qué rol va a tener el vecino en los turnos según su edad.
class _AvisoRol extends StatelessWidget {
  const _AvisoRol({required this.edad, required this.esGuardia});

  final int edad;
  final bool esGuardia;

  @override
  Widget build(BuildContext context) {
    final color = esGuardia ? AppColors.ventana : AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: esGuardia ? AppColors.ventanaSuave : AppColors.primarioSuave,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            esGuardia ? Icons.window_outlined : Icons.directions_walk,
            color: color,
          ),
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
                            '${ReglasTurnos.maxTurnosPorMes} turnos de patrullaje por mes.',
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
