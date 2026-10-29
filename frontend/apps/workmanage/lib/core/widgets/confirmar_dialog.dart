import 'package:flutter/material.dart';

// pergunta antes de uma ação que a pessoa pode não querer (inativar, sair).
// devolve true se confirmou; false se cancelou ou fechou o diálogo.
// textoCancelar troca o "Cancelar" do botão de fechar quando a própria ação
// se chama cancelar ("Cancelar agendamento": fechar vira "Voltar")
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String mensagem,
  String textoConfirmar = 'Confirmar',
  String textoCancelar = 'Cancelar',
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
          child: Text(textoCancelar),
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
