import 'package:flutter/material.dart';

// pergunta antes de uma ação que a pessoa pode não querer (inativar, sair).
// devolve true se confirmou; false se cancelou ou fechou o diálogo
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String mensagem,
  String textoConfirmar = 'Confirmar',
  bool destrutivo = false,
}) async {
  final colors = Theme.of(context).colorScheme;
  final confirmou = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(titulo),
      content: Text(mensagem),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: destrutivo
              ? FilledButton.styleFrom(
                  backgroundColor: colors.error,
                  foregroundColor: colors.onError,
                )
              : null,
          child: Text(textoConfirmar),
        ),
      ],
    ),
  );
  return confirmou ?? false;
}
