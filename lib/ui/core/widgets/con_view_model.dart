import 'package:flutter/widgets.dart';

/// Crea el ViewModel de una pantalla una sola vez y lo libera al salir.
///
/// El ViewModel no se puede crear dentro de `build()`: `build` se ejecuta
/// muchas veces y cada vez se perdería el estado. Este widget lo crea en
/// `initState` y llama a `dispose` cuando la pantalla se cierra.
class ConViewModel<T extends ChangeNotifier> extends StatefulWidget {
  const ConViewModel({super.key, required this.crear, required this.builder});

  final T Function() crear;
  final Widget Function(BuildContext context, T viewModel) builder;

  @override
  State<ConViewModel<T>> createState() => _ConViewModelState<T>();
}

class _ConViewModelState<T extends ChangeNotifier>
    extends State<ConViewModel<T>> {
  late final T _viewModel = widget.crear();

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _viewModel);
}
