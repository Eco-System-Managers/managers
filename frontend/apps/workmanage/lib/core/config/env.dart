// o que muda de máquina para máquina vem de fora do código, por
// --dart-define=API_BASE_URL=... . o padrão é a produção: sem define, o app
// fala com o servidor de verdade. para o backend local: celular por USB com
// `adb reverse tcp:8000 tcp:8000` e http://127.0.0.1:8000/api/v1/; emulador
// Android em http://10.0.2.2:8000/api/v1/
class Env {
  const Env._();

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.workmanage.com.br/api/v1/',
  );

  // a política de privacidade é uma página pública do mesmo servidor da API
  static String get linkPrivacidade =>
      Uri.parse(apiBaseUrl).replace(path: '/privacidade').toString();
}
