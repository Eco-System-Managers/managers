import 'package:flutter/material.dart';
import 'package:managers/core/widgets/estado_vazio.dart';

// a aba de uma fase que ainda não chegou: fica no lugar para a navegação
// já existir inteira
class EmBrevePage extends StatelessWidget {
  const EmBrevePage({
    super.key,
    required this.titulo,
    required this.icone,
    required this.mensagem,
  });

  final String titulo;
  final IconData icone;
  final String mensagem;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: EstadoVazio(icone: icone, titulo: 'Em breve', mensagem: mensagem),
    );
  }
}
