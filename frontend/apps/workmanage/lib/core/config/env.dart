// o que muda de máquina para máquina vem de fora do código, por
// --dart-define=API_BASE_URL=... . o padrão atende o simulador iOS; o
// emulador Android usa http://10.0.2.2:8000/api/v1/ e o celular físico o IP
// da máquina (os dois já estão no ALLOWED_HOSTS do backend)
class Env {
  const Env._();

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.workmanage.com.br/api/v1/',
  );
}
