/// Dirección de la API, elegida al compilar:
///
///     flutter run --dart-define=API_URL=http://10.0.2.2:8080
///
/// Vacía: la app usa el servidor simulado. Es una constante de
/// compilación, así que también la ve la tarea de segundo plano, que corre
/// en otro isolate y no comparte memoria con la app.
const urlApi = String.fromEnvironment('API_URL');
