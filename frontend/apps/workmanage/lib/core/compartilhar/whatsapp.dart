import 'package:url_launcher/url_launcher.dart';

// o motor de conversa pelo WhatsApp, pelo link universal wa.me: abre o app
// (ou o WhatsApp Web) já com o texto e, quando se sabe para quem é, com o
// número. não sabe de convite nem de cliente: qualquer feature usa

// https://wa.me/5511999998888?text=... ou, sem número, https://wa.me/?text=...
// (o WhatsApp pede para escolher o contato)
Uri uriDoWhatsApp({String? telefone, String texto = ''}) {
  final numero = telefone == null || telefone.isEmpty
      ? ''
      : numeroParaWhatsApp(telefone);
  return Uri.https('wa.me', '/$numero', texto.isEmpty ? null : {'text': texto});
}

// só os dígitos, com o DDI do Brasil quando o número vem sem ele (DDD mais
// o número: 10 dígitos fixo, 11 celular). com DDI já na frente, fica como está
String numeroParaWhatsApp(String telefone) {
  final digitos = telefone.replaceAll(RegExp(r'\D'), '');
  if (digitos.length == 10 || digitos.length == 11) return '55$digitos';
  return digitos;
}

// false quando não há app nem navegador para abrir o link
Future<bool> abrirWhatsApp({String? telefone, String texto = ''}) {
  return launchUrl(
    uriDoWhatsApp(telefone: telefone, texto: texto),
    mode: LaunchMode.externalApplication,
  );
}
