import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// o link do convite chega por e-mail e o app ainda não abre por deep link:
// a pessoa cola o link (ou só o token) e a tela de aceite abre. o token é
// o último pedaço do caminho do link
Future<void> abrirConvitePorLink(BuildContext context) async {
  final controller = TextEditingController();
  final texto = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Convite da equipe'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Cole o link que você recebeu por e-mail.'),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Link do convite',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('Abrir'),
        ),
      ],
    ),
  );
  controller.dispose();

  final token = tokenDoConvite(texto ?? '');
  if (token == null || !context.mounted) return;
  context.push('/convite/$token');
}

// "https://.../convites/aceitar/abc-123/" -> "abc-123"; "abc-123" -> "abc-123"
String? tokenDoConvite(String texto) {
  final partes = texto
      .trim()
      .split('?')
      .first
      .split('/')
      .where((p) => p.isNotEmpty)
      .toList();
  if (partes.isEmpty) return null;
  final token = partes.last;
  return RegExp(r'^[\w-]+$').hasMatch(token) ? token : null;
}
