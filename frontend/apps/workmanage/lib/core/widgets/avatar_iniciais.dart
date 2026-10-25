import 'package:flutter/material.dart';

// o avatar de uma pessoa: a foto, quando existe, ou as iniciais do nome
class AvatarIniciais extends StatelessWidget {
  const AvatarIniciais({
    super.key,
    required this.nome,
    this.fotoUrl = '',
    this.raio = 20,
  });

  final String nome;
  final String fotoUrl;
  final double raio;

  // "Ana Silva" -> "AS"; "Ana" -> "A"; "" -> "?"
  static String iniciais(String nome) {
    final partes = nome.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (partes.isEmpty) return '?';
    final primeira = partes.first[0];
    final ultima = partes.length > 1 ? partes.last[0] : '';
    return '$primeira$ultima'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return CircleAvatar(
      radius: raio,
      backgroundColor: colors.primaryContainer,
      foregroundImage: fotoUrl.isNotEmpty ? NetworkImage(fotoUrl) : null,
      child: Text(
        iniciais(nome),
        style: TextStyle(
          color: colors.onPrimaryContainer,
          fontSize: raio * 0.8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
