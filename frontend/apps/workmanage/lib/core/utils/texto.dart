// pedaços de texto que a tela e os providers montam, sem Flutter

// "Ana Silva" -> "Ana"
String primeiroNome(String nome) {
  final partes = nome.trim().split(RegExp(r'\s+'));
  return partes.isEmpty ? '' : partes.first;
}
